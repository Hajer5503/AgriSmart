# AgriSmart Flutter Integration Guide
## For the Flutter Developer

---

## 📦 What's in this package

```
agrismart_flutter/
├── lib/
│   └── main.dart                  ← Complete Flutter app (3 screens)
├── pubspec.yaml                   ← All dependencies
├── android_permissions.xml        ← Paste these into AndroidManifest.xml
├── class_names.json               ← 38 disease class labels
└── README.md                      ← This file

From the ML engineer (separate):
├── agrismart_disease.tflite       ← The AI model (put in assets/)
├── convert_model.py               ← Used to generate the .tflite from .pth
```

---

## 🚀 Setup Steps (do these in order)

### Step 1 — Create Flutter project
```bash
flutter create agrismart
cd agrismart
```

### Step 2 — Replace files
- Replace `lib/main.dart` with the provided `main.dart`
- Replace `pubspec.yaml` with the provided `pubspec.yaml`

### Step 3 — Add model assets
Create the assets folder and copy files:
```bash
mkdir -p assets
cp agrismart_disease.tflite assets/
cp class_names.json assets/
```

### Step 4 — Android permissions
Open `android/app/src/main/AndroidManifest.xml` and add:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

Also add `android:requestLegacyExternalStorage="true"` inside `<application>`.

### Step 5 — Set minimum Android SDK
In `android/app/build.gradle`, set:
```gradle
android {
    defaultConfig {
        minSdkVersion 21       // Required for camera package
        targetSdkVersion 34
    }
}
```

### Step 6 — Install dependencies & run
```bash
flutter pub get
flutter run
```

---

## 📱 App Flow

```
Home Screen
    ↓ (tap "Open Camera")
Camera Screen  ← live camera preview with leaf guide overlay
    ↓ (tap capture button)
Result Screen  ← shows disease name, crop, confidence + top 3 predictions
    ↓ (tap "Scan Another Leaf")
Camera Screen  ← back to camera
```

---

## 🧠 How Inference Works

1. Image captured at full resolution
2. Resized to **224×224** pixels
3. Normalized with ImageNet mean/std:
   - Mean: [0.485, 0.456, 0.406]
   - Std:  [0.229, 0.224, 0.225]
4. Fed into TFLite model (ResNet-50, 38 classes)
5. Softmax applied → top 3 predictions shown

---

## 🌿 Supported Plants & Diseases (38 classes)

| Crop | Conditions |
|------|-----------|
| Apple | Apple scab, Black rot, Cedar rust, Healthy |
| Blueberry | Healthy |
| Cherry | Powdery mildew, Healthy |
| Corn | Cercospora leaf spot, Common rust, Northern blight, Healthy |
| Grape | Black rot, Esca, Leaf blight, Healthy |
| Orange | Citrus greening |
| Peach | Bacterial spot, Healthy |
| Pepper | Bacterial spot, Healthy |
| Potato | Early blight, Late blight, Healthy |
| Raspberry | Healthy |
| Soybean | Healthy |
| Squash | Powdery mildew |
| Strawberry | Leaf scorch, Healthy |
| Tomato | Bacterial spot, Early blight, Late blight, Leaf mold, Septoria, Spider mites, Target spot, Yellow curl virus, Mosaic virus, Healthy |

---

## ⚠️ Important Notes

- The `.tflite` model file must be placed in `assets/` — Flutter embeds it in the app
- No internet connection required — 100% on-device inference
- Model size: ~90MB (ResNet-50)
- Inference time: ~200-500ms on modern Android phones
- Minimum Android SDK: 21 (Android 5.0)
- iOS also supported — no extra config needed for iOS camera

---

## 🔧 Troubleshooting

**Camera not working?**
→ Make sure permissions are added to AndroidManifest.xml

**Model not found?**
→ Check that `agrismart_disease.tflite` is in `assets/` and listed in `pubspec.yaml`

**Wrong predictions?**
→ Make sure the image is well-lit and the leaf fills most of the frame

**Build fails?**
→ Run `flutter clean && flutter pub get` then try again
