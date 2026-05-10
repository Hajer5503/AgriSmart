import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// What the UI sees while the user is speaking.
class SttUpdate {
  final String text;
  final bool isFinal;
  final double soundLevel;

  const SttUpdate({
    required this.text,
    required this.isFinal,
    this.soundLevel = 0.0,
  });
}

/// Native Android STT wrapper.
///
/// Picks the best available Arabic locale; if none of them is installed for
/// offline recognition (the common case on Tunisian Xiaomi devices that ship
/// with French / English packs only), it transparently falls back to online
/// Google STT with `ar-SA` which is virtually always supported.
class SttService {
  SttService({this.preferredLocaleIds = const ['ar-TN', 'ar-EG', 'ar-SA', 'ar']});

  /// Locales we try, in order, when picking an Arabic recognizer.
  final List<String> preferredLocaleIds;

  final stt.SpeechToText _stt = stt.SpeechToText();

  bool _initialized = false;
  String? _selectedLocaleId;
  String? get selectedLocaleId => _selectedLocaleId;

  /// True when we found an Arabic locale in the list reported by the on-device
  /// recognizer. False means we'll force online mode and use 'ar-SA'.
  bool _arabicAvailableOffline = false;
  bool get arabicAvailableOffline => _arabicAvailableOffline;

  /// Last picked listening mode, useful for the UI badge.
  bool _usedOnDevice = true;
  bool get lastUsedOnDevice => _usedOnDevice;

  StreamController<SttUpdate>? _updates;

  bool get isAvailable => _initialized;
  bool get isListening => _stt.isListening;

  Future<bool> ensureMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> initialize() async {
    if (_initialized) return true;
    if (!await ensureMicPermission()) {
      debugPrint('[SttService] microphone permission denied');
      return false;
    }

    _initialized = await _stt.initialize(
      onError: (e) => debugPrint('[SttService] error: ${e.errorMsg} (perm=${e.permanent})'),
      onStatus: (s) => debugPrint('[SttService] status: $s'),
      debugLogging: kDebugMode,
    );

    if (_initialized) {
      await _resolveLocale();
      debugPrint(
        '[SttService] selected=$_selectedLocaleId  arabicOffline=$_arabicAvailableOffline',
      );
    }
    return _initialized;
  }

  Future<void> _resolveLocale() async {
    final locales = await _stt.locales();
    final ids = locales.map((l) => l.localeId).toList(growable: false);
    debugPrint('[SttService] available locales (${ids.length}): $ids');

    for (final wanted in preferredLocaleIds) {
      final hit = locales.firstWhere(
        (l) => l.localeId.toLowerCase() == wanted.toLowerCase(),
        orElse: () => stt.LocaleName('', ''),
      );
      if (hit.localeId.isNotEmpty) {
        _selectedLocaleId = hit.localeId;
        _arabicAvailableOffline = true;
        return;
      }
    }
    final anyAr = locales.firstWhere(
      (l) => l.localeId.toLowerCase().startsWith('ar'),
      orElse: () => stt.LocaleName('', ''),
    );
    if (anyAr.localeId.isNotEmpty) {
      _selectedLocaleId = anyAr.localeId;
      _arabicAvailableOffline = true;
      return;
    }

    _selectedLocaleId = 'ar-SA';
    _arabicAvailableOffline = false;
  }

  /// Starts a single recognition session and yields partial + final results.
  Stream<SttUpdate> listen({
    Duration listenFor = const Duration(seconds: 20),
    Duration pauseFor = const Duration(milliseconds: 1500),
  }) async* {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        throw StateError('STT not available on this device.');
      }
    }
    await _updates?.close();
    _updates = StreamController<SttUpdate>();

    _usedOnDevice = _arabicAvailableOffline;

    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          _updates?.add(SttUpdate(
            text: r.recognizedWords,
            isFinal: r.finalResult,
          ));
          if (r.finalResult) _updates?.close();
        },
        onSoundLevelChange: (level) {
          _updates?.add(SttUpdate(
            text: _stt.lastRecognizedWords,
            isFinal: false,
            soundLevel: level,
          ));
        },
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: _selectedLocaleId,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
          onDevice: _usedOnDevice,
        ),
      );
    } catch (e) {
      debugPrint('[SttService] listen() failed in onDevice=$_usedOnDevice mode: $e');
      if (_usedOnDevice) {
        _usedOnDevice = false;
        await _stt.listen(
          onResult: (SpeechRecognitionResult r) {
            _updates?.add(SttUpdate(
              text: r.recognizedWords,
              isFinal: r.finalResult,
            ));
            if (r.finalResult) _updates?.close();
          },
          onSoundLevelChange: (level) {
            _updates?.add(SttUpdate(
              text: _stt.lastRecognizedWords,
              isFinal: false,
              soundLevel: level,
            ));
          },
          listenFor: listenFor,
          pauseFor: pauseFor,
          localeId: _selectedLocaleId,
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            cancelOnError: true,
            listenMode: stt.ListenMode.dictation,
            onDevice: false,
          ),
        );
      } else {
        rethrow;
      }
    }

    yield* _updates!.stream;
  }

  Future<void> stop() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
    await _updates?.close();
    _updates = null;
  }

  Future<void> cancel() async {
    if (_stt.isListening) {
      await _stt.cancel();
    }
    await _updates?.close();
    _updates = null;
  }
}
