import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// Phase reported while the Whisper model is being prepared.
enum WhisperReadyPhase { checking, downloading, ready, error }

/// Streamed status while bootstrapping Whisper.
class WhisperReadyStatus {
  final WhisperReadyPhase phase;
  final int receivedBytes;
  final int totalBytes;
  final String? message;

  const WhisperReadyStatus({
    required this.phase,
    this.receivedBytes = 0,
    this.totalBytes = -1,
    this.message,
  });

  double? get progress {
    if (totalBytes <= 0 || receivedBytes < 0) return null;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }
}

/// 100% offline, language-pack-free, Arabic-capable speech-to-text using
/// whisper.cpp. Workflow:
///
/// 1. [bootstrap] — ensures the GGML weights are present (first launch
///    downloads ~150 MB from HuggingFace).
/// 2. [startRecording] — opens an audio recorder writing 16kHz mono AAC into
///    the app's temp dir; emits live mic amplitude on [soundLevel].
/// 3. [stopAndTranscribe] — stops the recorder, asks Whisper to transcribe
///    the file with `lang='ar'`, and returns the recognized text.
class WhisperSttService {
  WhisperSttService({
    this.model = WhisperModel.tiny,
    this.language = 'ar',
  });

  final WhisperModel model;
  final String language;

  final AudioRecorder _recorder = AudioRecorder();
  final WhisperController _whisper = WhisperController();

  bool _modelReady = false;
  bool _recording = false;
  bool _transcribing = false;

  String? _recordPath;
  StreamSubscription<Amplitude>? _ampSub;

  final StreamController<double> _soundLevelCtl =
      StreamController<double>.broadcast();
  Stream<double> get soundLevel => _soundLevelCtl.stream;

  bool get isReady => _modelReady;
  bool get isRecording => _recording;
  bool get isTranscribing => _transcribing;

  Future<bool> ensureMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Yields download / readiness status until the model is on disk.
  Stream<WhisperReadyStatus> bootstrap() async* {
    yield const WhisperReadyStatus(
      phase: WhisperReadyPhase.checking,
      message: 'Locating Whisper model...',
    );

    final modelPath = await _whisper.getPath(model);
    final file = File(modelPath);
    if (await file.exists() && await file.length() > 10 * 1024 * 1024) {
      _modelReady = true;
      final size = await file.length();
      yield WhisperReadyStatus(
        phase: WhisperReadyPhase.ready,
        receivedBytes: size,
        totalBytes: size,
        message: 'Whisper ready (cached).',
      );
      return;
    }

    final sideload = await _findSideloadSource();
    if (sideload != null) {
      yield WhisperReadyStatus(
        phase: WhisperReadyPhase.checking,
        message: 'Importing Whisper from ${sideload.path}',
      );
      try {
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await sideload.copy(file.path);
        if (await file.exists() && await file.length() > 10 * 1024 * 1024) {
          _modelReady = true;
          final size = await file.length();
          yield WhisperReadyStatus(
            phase: WhisperReadyPhase.ready,
            receivedBytes: size,
            totalBytes: size,
            message: 'Whisper ready (sideloaded).',
          );
          return;
        }
      } catch (e) {
        debugPrint('[Whisper] sideload copy failed: $e');
      }
    }

    yield WhisperReadyStatus(
      phase: WhisperReadyPhase.downloading,
      message: 'Downloading Whisper-${model.modelName}...',
    );

    try {
      await for (final s in _downloadWithProgress(model.modelUri, file)) {
        yield s;
      }
    } catch (e) {
      yield WhisperReadyStatus(
        phase: WhisperReadyPhase.error,
        message: 'Download failed: $e',
      );
      return;
    }

    if (await file.exists() && await file.length() > 10 * 1024 * 1024) {
      _modelReady = true;
      final size = await file.length();
      yield WhisperReadyStatus(
        phase: WhisperReadyPhase.ready,
        receivedBytes: size,
        totalBytes: size,
        message: 'Whisper ready.',
      );
    } else {
      yield const WhisperReadyStatus(
        phase: WhisperReadyPhase.error,
        message: 'Whisper file is invalid.',
      );
    }
  }

  Future<File?> _findSideloadSource() async {
    final fileName = 'ggml-${model.modelName}.bin';
    final candidates = <String>[];
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) candidates.add('${ext.path}/$fileName');
    } catch (_) {}
    candidates.addAll([
      '/storage/emulated/0/Download/$fileName',
      '/sdcard/Download/$fileName',
    ]);

    for (final p in candidates) {
      final f = File(p);
      if (await f.exists() && await f.length() > 10 * 1024 * 1024) {
        return f;
      }
    }
    return null;
  }

  Stream<WhisperReadyStatus> _downloadWithProgress(Uri url, File dest) async* {
    final tmp = File('${dest.path}.part');
    if (await tmp.exists()) await tmp.delete();
    if (!await dest.parent.exists()) {
      await dest.parent.create(recursive: true);
    }

    final client = http.Client();
    try {
      final resp = await client.send(http.Request('GET', url));
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode} on $url');
      }
      final total = resp.contentLength ?? -1;
      final sink = tmp.openWrite();
      var received = 0;
      var lastEmit = 0;
      try {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (received - lastEmit > 1024 * 1024 || received == total) {
            lastEmit = received;
            yield WhisperReadyStatus(
              phase: WhisperReadyPhase.downloading,
              receivedBytes: received,
              totalBytes: total,
              message: '${_fmtMB(received)}'
                  '${total > 0 ? ' / ${_fmtMB(total)}' : ''}',
            );
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (await dest.exists()) await dest.delete();
      await tmp.rename(dest.path);
    } finally {
      client.close();
    }
  }

  /// Hard cap on recording length, to keep the offline transcription latency
  /// reasonable on mid-range Mali GPUs. Whisper.cpp processes audio in
  /// 30-second chunks; keeping below 10s also avoids ffmpeg PCM peaks.
  static const Duration maxRecordingDuration = Duration(seconds: 10);

  /// Optional callback invoked when [maxRecordingDuration] is hit and the
  /// recorder auto-stops.
  void Function()? onMaxDurationReached;

  Timer? _maxDurationTimer;

  Future<void> startRecording() async {
    if (_recording) return;
    if (!await ensureMicPermission()) {
      throw StateError('Microphone permission denied.');
    }
    if (!_modelReady) {
      throw StateError('Whisper model not ready yet.');
    }

    final tmp = Directory.systemTemp;
    _recordPath = '${tmp.path}/agrismart_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: _recordPath!,
    );

    await _ampSub?.cancel();
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 150))
        .listen((amp) {
      _soundLevelCtl.add(amp.current);
    });

    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(maxRecordingDuration, () {
      debugPrint('[Whisper] reached max duration, auto-stopping');
      onMaxDurationReached?.call();
    });

    _recording = true;
    debugPrint('[Whisper] recording -> $_recordPath');
  }

  /// Stops the recorder and runs Whisper on the captured audio.
  /// Returns the recognized text (may be empty for silent recordings).
  Future<String> stopAndTranscribe({Duration? minDuration}) async {
    if (!_recording) return '';
    _recording = false;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    final path = await _recorder.stop();
    await _ampSub?.cancel();
    _ampSub = null;

    if (path == null) {
      debugPrint('[Whisper] no recording produced');
      return '';
    }

    if (minDuration != null) {
      final f = File(path);
      if (await f.exists()) {
        final bytes = await f.length();
        if (bytes < 1024) {
          debugPrint('[Whisper] recording too short ($bytes bytes)');
          return '';
        }
      }
    }

    _transcribing = true;
    try {
      final stopwatch = Stopwatch()..start();
      final result = await _whisper.transcribe(
        model: model,
        audioPath: path,
        lang: language,
      );
      stopwatch.stop();
      final text = result?.transcription.text.trim() ?? '';
      debugPrint('[Whisper] transcribed in ${stopwatch.elapsedMilliseconds}ms: "$text"');
      return text;
    } finally {
      _transcribing = false;
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> cancel() async {
    if (_recording) {
      try {
        await _recorder.cancel();
      } catch (_) {}
      _recording = false;
    }
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    await _ampSub?.cancel();
    _ampSub = null;
  }

  Future<void> dispose() async {
    await cancel();
    await _soundLevelCtl.close();
    await _recorder.dispose();
  }

  static String _fmtMB(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
