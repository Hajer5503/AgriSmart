import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Native Android TTS wrapper that always speaks Arabic.
///
/// We pick the most appropriate Arabic language tag actually installed on
/// the device, set queue mode so consecutive calls don't get clipped,
/// and expose simple async [speak] / [stop] methods plus a "speaking" stream.
class TtsService {
  static const List<String> _preferredLanguages = [
    'ar-TN',
    'ar-EG',
    'ar-SA',
    'ar-MA',
    'ar',
  ];

  final FlutterTts _tts = FlutterTts();
  final StreamController<bool> _speakingCtl = StreamController<bool>.broadcast();

  bool _initialized = false;
  String? _selectedLanguage;
  String? get selectedLanguage => _selectedLanguage;

  Stream<bool> get speakingStream => _speakingCtl.stream;

  Future<bool> initialize() async {
    if (_initialized) return true;

    await _tts.awaitSpeakCompletion(true);
    await _tts.setQueueMode(1); // QUEUE_ADD: lines are queued, not flushed
    await _tts.setSpeechRate(0.55);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _selectedLanguage = await _pickArabicLanguage();
    if (_selectedLanguage != null) {
      await _tts.setLanguage(_selectedLanguage!);
      debugPrint('[TtsService] language set to $_selectedLanguage');
    } else {
      debugPrint('[TtsService] no Arabic voice installed; '
          'TTS may fall back to system default.');
    }

    _tts.setStartHandler(() => _speakingCtl.add(true));
    _tts.setCompletionHandler(() => _speakingCtl.add(false));
    _tts.setCancelHandler(() => _speakingCtl.add(false));
    _tts.setErrorHandler((msg) {
      debugPrint('[TtsService] error: $msg');
      _speakingCtl.add(false);
    });

    _initialized = true;
    return true;
  }

  Future<String?> _pickArabicLanguage() async {
    try {
      final available = await _tts.getLanguages;
      final list = (available is List)
          ? available.map((e) => e.toString()).toList()
          : const <String>[];
      debugPrint('[TtsService] languages (${list.length}): $list');

      for (final wanted in _preferredLanguages) {
        final hit = list.firstWhere(
          (l) => l.toLowerCase() == wanted.toLowerCase(),
          orElse: () => '',
        );
        if (hit.isNotEmpty) return hit;
      }
      final anyAr = list.firstWhere(
        (l) => l.toLowerCase().startsWith('ar'),
        orElse: () => '',
      );
      if (anyAr.isNotEmpty) return anyAr;
    } catch (e) {
      debugPrint('[TtsService] getLanguages failed: $e');
    }
    return null;
  }

  /// Speaks [text] and resolves when playback finishes (or fails).
  Future<void> speak(String text) async {
    if (!_initialized) await initialize();
    final clean = text.trim();
    if (clean.isEmpty) return;
    await _tts.speak(clean);
  }

  Future<void> stop() async {
    if (!_initialized) return;
    await _tts.stop();
    _speakingCtl.add(false);
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
    await _speakingCtl.close();
    _initialized = false;
  }
}
