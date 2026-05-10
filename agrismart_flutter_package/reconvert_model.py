"""
AgriSmart — clean PyTorch -> ONNX -> TFLite conversion.

Fixes the broken `.tflite` produced by the original `convert_model.py`
(which exported ONNX with `dynamic_axes={'image': {0: 'batch'}}`, causing
`onnx2tf` to emit an invalid Reshape node at the end of ResNet-50).

Pipeline:
  1. Build ResNet-50 with the same head as training: Sequential(Dropout, Linear).
  2. Load `best_model.pth` weights (handle DataParallel prefix).
  3. Export ONNX with fixed batch=1, opset=13, constant folding ON.
  4. Simplify ONNX (onnxsim).
  5. Convert ONNX -> TFLite (onnx2tf) into NHWC float32 layout.
  6. Sanity check: PyTorch logits vs TFLite logits on a random input.
"""

from __future__ import annotations
import os
import sys
import shutil
import argparse
import numpy as np

import torch
import torch.nn as nn
import torchvision.models as models


def build_model(num_classes: int = 38) -> nn.Module:
    model = models.resnet50(weights=None)
    in_features = model.fc.in_features
    model.fc = nn.Sequential(
        nn.Dropout(p=0.3),
        nn.Linear(in_features, num_classes),
    )
    return model


def load_state(model: nn.Module, pth_path: str) -> None:
    state = torch.load(pth_path, map_location="cpu", weights_only=True)
    if isinstance(state, dict) and any(k.startswith("module.") for k in state):
        state = {k.replace("module.", "", 1): v for k, v in state.items()}
    model.load_state_dict(state)
    model.eval()


def export_onnx(model: nn.Module, onnx_path: str, img_size: int = 224) -> None:
    print("[1/4] Exporting ONNX (batch=1, no dynamic axes)...")
    dummy = torch.randn(1, 3, img_size, img_size)
    torch.onnx.export(
        model,
        dummy,
        onnx_path,
        input_names=["image"],
        output_names=["logits"],
        opset_version=13,
        do_constant_folding=True,
    )
    print(f"      -> {onnx_path}")


def simplify_onnx(onnx_path: str) -> None:
    print("[2/4] Simplifying ONNX graph...")
    import onnx
    from onnxsim import simplify
    model = onnx.load(onnx_path)
    model_simp, ok = simplify(model)
    if not ok:
        print("      WARNING: simplification reported failure, keeping unsimplified model")
        return
    onnx.save(model_simp, onnx_path)
    print("      -> simplified")


def onnx_to_tflite(onnx_path: str, output_dir: str) -> str:
    print("[3/4] Converting ONNX -> TFLite via onnx2tf...")

    fake = lambda: np.random.rand(20, 224, 224, 3).astype(np.float32)
    import onnx2tf
    import onnx2tf.onnx2tf as _o2t_mod
    import onnx2tf.utils.common_functions as _cf
    _cf.download_test_image_data = fake
    _o2t_mod.download_test_image_data = fake

    if os.path.isdir(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir, exist_ok=True)
    onnx2tf.convert(
        input_onnx_file_path=onnx_path,
        output_folder_path=output_dir,
        copy_onnx_input_output_names_to_tflite=True,
        non_verbose=True,
    )
    candidates = [
        f for f in os.listdir(output_dir)
        if f.endswith(".tflite") and not any(
            tag in f for tag in ("dynamic_range", "integer", "int8", "float16")
        )
    ]
    if not candidates:
        candidates = [f for f in os.listdir(output_dir) if f.endswith(".tflite")]
    if not candidates:
        raise RuntimeError("onnx2tf did not produce any .tflite file")
    candidates.sort()
    src = os.path.join(output_dir, candidates[0])
    dst = os.path.join(output_dir, "agrismart_disease.tflite")
    if src != dst:
        shutil.copyfile(src, dst)
    print(f"      -> {dst}")
    return dst


def sanity_check(model: nn.Module, tflite_path: str, img_size: int = 224, tol: float = 1e-2) -> None:
    print("[4/4] Sanity check (PyTorch vs TFLite)...")
    rng = np.random.default_rng(0)
    np_input_nchw = rng.standard_normal((1, 3, img_size, img_size), dtype=np.float32)

    with torch.no_grad():
        torch_out = model(torch.from_numpy(np_input_nchw)).numpy()

    try:
        from ai_edge_litert.interpreter import Interpreter
    except ImportError:
        import tensorflow as tf
        Interpreter = tf.lite.Interpreter

    interp = Interpreter(model_path=tflite_path)
    interp.allocate_tensors()
    in_det = interp.get_input_details()[0]
    out_det = interp.get_output_details()[0]
    print("      input :", in_det["shape"], in_det["dtype"].__name__)
    print("      output:", out_det["shape"], out_det["dtype"].__name__)

    in_shape = list(in_det["shape"])
    nhwc = (len(in_shape) == 4 and in_shape[-1] == 3)
    np_input = np.transpose(np_input_nchw, (0, 2, 3, 1)) if nhwc else np_input_nchw
    interp.set_tensor(in_det["index"], np_input.astype(np.float32))
    interp.invoke()
    tflite_out = interp.get_tensor(out_det["index"])

    diff = float(np.max(np.abs(torch_out - tflite_out)))
    print(f"      max abs diff: {diff:.6f}")

    torch_top = int(np.argmax(torch_out))
    tflite_top = int(np.argmax(tflite_out))
    print(f"      argmax PyTorch={torch_top}  TFLite={tflite_top}")

    if diff > tol:
        print(f"      WARNING: diff exceeds tol={tol}")
    if torch_top != tflite_top:
        print("      WARNING: top-1 differs!")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pth", required=True)
    ap.add_argument("--out_dir", default="reconverted")
    ap.add_argument("--num_classes", type=int, default=38)
    args = ap.parse_args()

    out_dir = os.path.abspath(args.out_dir)
    os.makedirs(out_dir, exist_ok=True)
    onnx_path = os.path.join(out_dir, "agrismart_disease.onnx")
    tflite_dir = os.path.join(out_dir, "tflite")

    model = build_model(args.num_classes)
    load_state(model, args.pth)
    print(f"Loaded weights from {args.pth}")

    export_onnx(model, onnx_path)
    simplify_onnx(onnx_path)
    tflite_path = onnx_to_tflite(onnx_path, tflite_dir)
    sanity_check(model, tflite_path)

    final_path = os.path.join(out_dir, "agrismart_disease.tflite")
    shutil.copyfile(tflite_path, final_path)
    print(f"\nDONE. Final model: {final_path}  ({os.path.getsize(final_path)/1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
