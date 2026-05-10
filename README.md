# AgriSmart

**An end-to-end AI platform for precision agriculture**, combining computer vision, reinforcement learning, and an autonomous LLM agent into a single mobile-first product.

> Integrated Project — ESPRIT, MSc Data Science, class 4DS5.

**Branch `agrismart`:** this branch merges the historical root-level
Flutter tree (`android/`, `lib/` at repo root) with the course
monorepo under `agrismart_flutter_package/` and `modules/`. Prefer
`agrismart_flutter_package/flutter_app` for the latest on-device
detection and Arabic voice assistant.

---

## Overview

AgriSmart helps small and medium-scale farmers make better decisions on three tightly coupled problems:

1. **What is wrong with this plant?** &nbsp;— on-device leaf disease detection from a phone camera.
2. **How much water should I apply, and when?** &nbsp;— a hierarchical irrigation advisor combining regression and reinforcement learning, wrapped in an autonomous agent that reasons over real-time weather and FAO-56 agronomy literature.
3. **What yield can I expect this season?** &nbsp;— a crop yield prediction module on tabular agro-climatic data.

Everything is reproducible: data is versioned with **DVC**, training notebooks live in `modules/`, the mobile app lives in `agrismart_flutter_package/`, and a single conversion script (`reconvert_model.py`) takes a trained PyTorch checkpoint to a deployable TFLite asset.

---

## Key Features

- **Offline disease detection** — ResNet-50 (38 classes) running fully on-device via TFLite, no internet required.
- **Two-layer irrigation system** — Layer 1 estimates reference evapotranspiration (ET0) and root-zone soil moisture from sensor + weather features (scikit-learn). Layer 2 is a Double DQN agent in PyTorch that recommends the next irrigation action.
- **Autonomous AI agent** — A LangGraph orchestrator chains four tools (forecast, RL advisor, weather, FAO-56 RAG over ChromaDB) behind an open-source LLM, with every decision audited in MLflow.
- **Yield prediction** — Pipelines for tabular agronomic and climate data.
- **Cross-platform mobile app** — Flutter (Android and iOS), with a clean three-screen flow: home, live camera, result with top-3 predictions.
- **Reproducible model deployment** — `reconvert_model.py` exports `.pth → ONNX (fixed batch) → TFLite` and validates the round-trip against PyTorch outputs.

---

## High-level Architecture

```
                    +-------------------------------+
                    |   Mobile App (Flutter)        |
                    |   - Camera capture            |
                    |   - On-device TFLite ResNet50 |
                    |   - 38-class disease output   |
                    +---------------+---------------+
                                    |
                                    v (offline asset)
+--------------------+      +-------------------+      +-----------------------+
| Sensor + Weather   |      | best_model.pth    |      | Crop Yield notebooks  |
| (CSV / live feed)  |      | (ResNet-50 head)  |      | (tabular pipelines)   |
+---------+----------+      +---------+---------+      +-----------+-----------+
          |                           |                            |
          v                           v                            v
+--------------------+      +---------------------+      +-----------------------+
| Layer 1 regressors |      | reconvert_model.py  |      | Yield prediction      |
| ET0 + SoilMoisture |      | -> agrismart        |      | models                |
| (sklearn .pkl)     |      |    _disease.tflite  |      |                       |
+---------+----------+      +---------------------+      +-----------------------+
          |
          v
+--------------------+
| Layer 2 RL agent   |
| Double DQN PyTorch |
+---------+----------+
          |
          v
+----------------------------------------------------------+
| LangGraph Autonomous Agent                               |
|  Tools: weather forecast | RL advisor | weather API |    |
|         FAO-56 RAG (ChromaDB) | LLM | MLflow audit log   |
+----------------------------------------------------------+
```

---

## Repository Structure

```
.
├── agrismart_flutter_package/
│   ├── flutter_app/                   # Flutter mobile application
│   │   ├── android/  ios/  ...        # Platform scaffolding
│   │   ├── assets/
│   │   │   ├── agrismart_disease.tflite   # 90 MB, tracked via Git LFS
│   │   │   └── class_names.json
│   │   ├── lib/main.dart              # Single-file Dart app (3 screens)
│   │   └── pubspec.yaml
│   ├── convert_model.py               # Original conversion (kept for reference)
│   └── reconvert_model.py             # Working conversion pipeline
├── modules/
│   ├── crop_disease_detection/
│   │   ├── notebooks/                 # Data exploration, preprocessing, training, evaluation
│   │   ├── models/
│   │   └── src/
│   ├── crop_yield_prediction/
│   │   ├── notebooks/01_data_preparation/
│   │   ├── data_processing/
│   │   └── models/
│   └── irrigation_rl/
│       ├── notebooks/
│       │   ├── 01_problem_definition.ipynb
│       │   ├── 02_data_preparation.ipynb
│       │   ├── RLlayer1_modeling.ipynb
│       │   ├── Layer2_RL.ipynb
│       │   ├── Layer2_RL_pytorch.ipynb
│       │   └── agrismart_langgraph_final.ipynb
│       └── models/                    # layer1_*.pkl, layer2_dqn_*.pt
├── data/                              # DVC-tracked datasets
├── docs/
├── .dvc/                              # DVC configuration
├── best_model.pth                     # ResNet-50 weights (not committed)
└── README.md
```

---

## Modules

### 1. Crop Disease Detection

| | |
|---|---|
| Architecture | ResNet-50 (`torchvision.models.resnet50`) with `Sequential(Dropout(0.3), Linear(2048, 38))` head |
| Dataset | New Plant Diseases Dataset (Augmented), 38 classes covering 14 crops |
| Input | 224 x 224 RGB, ImageNet mean/std normalization |
| Output | 38-way softmax (top-3 surfaced in the app) |
| Deployment | TFLite, NHWC float32, on-device inference (~200-500 ms) |

Supported crops include apple, blueberry, cherry, corn, grape, orange, peach, pepper, potato, raspberry, soybean, squash, strawberry, and tomato — see `agrismart_flutter_package/flutter_app/README.md` for the full disease list.

Notebooks in `modules/crop_disease_detection/notebooks/` cover data exploration, preprocessing, training, and evaluation.

### 2. Crop Yield Prediction

Tabular pipeline for predicting crop yield from agronomic and climate features. Notebooks live under `modules/crop_yield_prediction/notebooks/01_data_preparation/`.

### 3. Irrigation RL

A two-layer decision system, plus an LLM agent on top.

- **Layer 1 — physical estimators** (`modules/irrigation_rl/models/layer1_*.pkl`)
  - `layer1_model_et0.pkl` &mdash; reference evapotranspiration regressor
  - `layer1_model_sm_root.pkl` &mdash; root-zone soil moisture regressor
  - Companion JSON files (`layer1_*_feature_cols.json`) document the expected feature schema.
- **Layer 2 — Reinforcement Learning** (`layer2_dqn_*.pt`, `.pkl`)
  - PyTorch **Double DQN** agent (`layer2_dqn_pytorch_best.pt`, `layer2_dqn_agent_augmented.pt`).
  - Earlier scikit-learn DQN baseline (`layer2_dqn_agent.pkl`) kept for comparison.
- **Autonomous Agent** &mdash; `notebooks/agrismart_langgraph_final.ipynb`
  - **LangGraph** state machine wiring four tools: weather forecast, the RL advisor, a weather API, and a **FAO-56 RAG** knowledge base in **ChromaDB**.
  - **MLflow** logs every decision (input state, tool calls, final action) for full auditability.

### 4. Mobile App (Flutter)

A focused, single-purpose mobile app:

```
HomeScreen  --[Open Camera]-->  CameraScreen  --[Capture]-->  ResultScreen
   ^                                                                |
   |                                  [Scan Another Leaf]           |
   +----------------------------------------------------------------+
```

Detailed setup, permissions, and the full disease list live in `agrismart_flutter_package/flutter_app/README.md`.

---

## Tech Stack

**Machine Learning**
- PyTorch, torchvision (ResNet-50)
- scikit-learn (Layer 1 regressors)
- DQN / Double DQN in PyTorch (Layer 2 RL)
- ONNX, onnx-simplifier, onnx2tf (model conversion)
- TensorFlow Lite / `ai-edge-litert` (mobile inference)

**Agent & MLOps**
- LangGraph, LangChain (agent orchestration)
- ChromaDB (vector store for FAO-56 RAG)
- HuggingFace Transformers (LLM)
- MLflow (experiment + decision tracking)

**Mobile**
- Flutter 3.41.x, Dart 3.11
- `tflite_flutter` 0.12.1, `camera`, `image`, `path_provider`

**Data & Versioning**
- DVC (data version control)
- Git LFS (large model assets)

---

## Getting Started

### 1. Clone with LFS

```bash
git clone https://github.com/Hajer5503/Esprit-PI-4DS5-AgriSmart.git
cd Esprit-PI-4DS5-AgriSmart
git lfs install
git lfs pull
```

### 2. Pull DVC-tracked data (optional but recommended)

```bash
pip install dvc
dvc pull
```

### 3. Python environment

The project targets **Python 3.11**. Install module-specific dependencies as needed:

```bash
# Crop disease detection / model conversion
pip install torch==2.4.1 torchvision==0.19.1 --index-url https://download.pytorch.org/whl/cpu
pip install onnx onnx2tf onnxruntime onnxsim onnx_graphsurgeon
pip install tensorflow-cpu tf_keras ai_edge_litert sng4onnx

# Irrigation RL + LangGraph agent (run inside the notebook, see install cell)
# Yield prediction
pip install pandas scikit-learn matplotlib seaborn jupyter
```

### 4. Run a notebook

```bash
jupyter notebook modules/crop_disease_detection/notebooks/01_data_exploration.ipynb
```

The autonomous agent notebook (`modules/irrigation_rl/notebooks/agrismart_langgraph_final.ipynb`) is self-contained and prints a step-by-step pipeline with sensor data, RL recommendations, weather, RAG citations, LLM rationale, and MLflow run IDs.

### 5. Run the mobile app

Detailed instructions in `agrismart_flutter_package/flutter_app/README.md`. Quick version (Android device, USB debugging on):

```bash
cd agrismart_flutter_package/flutter_app
flutter pub get
flutter run
```

---

## Model Conversion Pipeline

The original `convert_model.py` produced a `.tflite` whose internal graph crashed at runtime (`tflite/kernels/reshape.cc:94 num_input_elements != num_output_elements`) because ONNX was exported with `dynamic_axes={'image': {0: 'batch'}}`, which onnx2tf could not resolve into a static reshape after global average pooling.

`reconvert_model.py` provides a clean, reproducible alternative:

1. Rebuild the ResNet-50 head exactly as trained.
2. Load `best_model.pth` (handles `DataParallel` prefixes).
3. Export ONNX with **fixed batch = 1**, opset 13, constant folding on.
4. Simplify the ONNX graph (`onnxsim`).
5. Convert to TFLite with `onnx2tf`, asking it to keep ONNX I/O names.
6. Sanity-check: feed the same random input through PyTorch and TFLite. The current artifact matches PyTorch logits to ~3e-6 (max abs difference) and produces the same argmax.

Run it with:

```bash
cd agrismart_flutter_package
python reconvert_model.py --pth ../best_model.pth --out_dir reconverted
```

The resulting `reconverted/agrismart_disease.tflite` can be copied straight into `flutter_app/assets/`.

---

## Branching Model

| Branch | Purpose |
|---|---|
| `main` | Stable, presentation-ready code |
| `agrismart` | Merged monorepo + legacy root Flutter app |
| `integration_branch` | Cross-module integration |
| `feature/*`, `*-branch` | Per-contributor or per-module feature branches |

---

## Contributors

| Member | Focus |
|---|---|
| Hajer | Project lead, integration |
| Nadhir Maamar | Mobile app, model conversion pipeline |
| Yessine | Crop yield prediction |
| Kacem Trabelsi | Irrigation RL & autonomous agent |

---

## Acknowledgements

- **FAO-56** — *Crop evapotranspiration: guidelines for computing crop water requirements*, used as the agronomy knowledge base for the RAG component.
- **New Plant Diseases Dataset (Augmented)** &mdash; Kaggle, used to train the disease classifier.
- **PINTO0309/onnx2tf** &mdash; the converter used in the working pipeline.

---

## License

This project is academic work produced at ESPRIT. See the school's policy for redistribution. Third-party datasets, model weights, and libraries remain under their respective licenses.
