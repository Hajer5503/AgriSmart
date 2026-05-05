"""
AgriSmart — Model Conversion Script
====================================
Converts ResNet-50 .pth → .onnx → .tflite

Usage:
    pip install torch torchvision onnx onnx2tf tensorflow
    python convert_model.py --pth best_model.pth --output ./output

Requirements:
    pip install torch torchvision onnx onnx2tf tensorflow numpy
"""

import argparse
import json
import sys
import os

def convert_pth_to_onnx(pth_path: str, output_dir: str) -> str:
    import torch
    import torch.nn as nn
    import torchvision.models as models

    print("Step 1/2 — Loading .pth and exporting to ONNX...")

    NUM_CLASSES = 38
    IMG_SIZE    = 224

    # Rebuild the exact same model architecture used in training
    model = models.resnet50(weights=None)
    in_features = model.fc.in_features
    model.fc = nn.Sequential(
        nn.Dropout(p=0.3),
        nn.Linear(in_features, NUM_CLASSES),
    )

    # Load weights — handle DataParallel prefix if present
    state = torch.load(pth_path, map_location='cpu')
    if any(k.startswith('module.') for k in state.keys()):
        state = {k.replace('module.', ''): v for k, v in state.items()}
    model.load_state_dict(state)
    model.eval()

    dummy  = torch.randn(1, 3, IMG_SIZE, IMG_SIZE)
    onnx_path = os.path.join(output_dir, 'agrismart_disease.onnx')

    torch.onnx.export(
        model,
        dummy,
        onnx_path,
        input_names=['image'],
        output_names=['logits'],
        dynamic_axes={'image': {0: 'batch'}, 'logits': {0: 'batch'}},
        opset_version=17,
    )
    print(f"  ✅ ONNX saved → {onnx_path}")
    return onnx_path


def convert_onnx_to_tflite(onnx_path: str, output_dir: str) -> str:
    print("Step 2/2 — Converting ONNX → TFLite (this takes ~2 min)...")
    try:
        import onnx2tf
        tflite_dir = os.path.join(output_dir, 'tflite_model')
        onnx2tf.convert(
            input_onnx_file_path=onnx_path,
            output_folder_path=tflite_dir,
            non_verbose=True,
        )
        # Find the .tflite file
        for f in os.listdir(tflite_dir):
            if f.endswith('.tflite'):
                src  = os.path.join(tflite_dir, f)
                dest = os.path.join(output_dir, 'agrismart_disease.tflite')
                os.rename(src, dest)
                print(f"  ✅ TFLite saved → {dest}")
                return dest
    except ImportError:
        print("  onnx2tf not installed. Install with: pip install onnx2tf tensorflow")
        print("  Alternatively use https://convertmodel.com to convert the .onnx file online")
        sys.exit(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--pth',    required=True, help='Path to best_model.pth')
    parser.add_argument('--output', default='./agrismart_output', help='Output directory')
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)

    onnx_path   = convert_pth_to_onnx(args.pth, args.output)
    tflite_path = convert_onnx_to_tflite(onnx_path, args.output)

    print("\n✅ Done! Give your Flutter friend these files:")
    print(f"   1. {tflite_path}")
    print(f"   2. {args.output}/class_names.json  (if not already in output)")
