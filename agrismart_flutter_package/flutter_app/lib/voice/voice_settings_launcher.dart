import 'package:flutter/services.dart';

/// Bridge to MainActivity.kt that opens Android system pages for installing
/// the offline Arabic STT/TTS language packs.
class VoiceSettingsLauncher {
  static const _channel = MethodChannel('agrismart/voice_settings');

  /// Opens the "Install voice data" dialog of the active TTS engine.
  /// On most devices that's Google TTS; the user can then select Arabic
  /// and download the voice for offline use.
  static Future<void> openTtsInstall() =>
      _channel.invokeMethod<void>('openTtsInstall');

  /// Opens the system Text-to-Speech settings (engine, rate, language data).
  static Future<void> openTtsSettings() =>
      _channel.invokeMethod<void>('openTtsSettings');

  /// Opens the speech recognition / voice input settings (where Google App
  /// hosts "Offline speech recognition" → Add language → Arabic).
  static Future<void> openVoiceInputSettings() =>
      _channel.invokeMethod<void>('openVoiceInputSettings');

  /// Opens the Android language list (system locale).
  static Future<void> openLanguageSettings() =>
      _channel.invokeMethod<void>('openLanguageSettings');
}
