plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.agrismart"
    compileSdk = flutter.compileSdkVersion
    // whisper_ggml ships native binaries built with NDK r29; everyone else is
    // happy with r27. NDK is backward-compatible so we pin to the highest.
    ndkVersion = "29.0.13113456"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.agrismart"
        // llama_flutter_android requires API 26+; camera + tflite_flutter only need 21.
        // We pin to 26 to satisfy the strictest dependency.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Restrict native ABIs to ARM64 + x86_64. armeabi-v7a is dropped because
        // tflite_flutter's full asset and llama.cpp prefer 64-bit, and 32-bit
        // builds on Android 16 are flaky for large mmap'd model files.
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    // The bundled .gguf and .tflite assets are already compressed and would only
    // grow if APK packaging tries to compress them again. Keep them flat so they
    // can be mmap'd directly from the APK.
    androidResources {
        noCompress += listOf("tflite", "gguf")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
