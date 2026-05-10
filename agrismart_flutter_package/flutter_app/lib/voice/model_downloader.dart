import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Streamed status from [ModelDownloader].
class ModelDownloadStatus {
  /// Where in the download lifecycle we are.
  final ModelDownloadPhase phase;

  /// Bytes received so far. -1 when unknown (e.g. checking sideload).
  final int receivedBytes;

  /// Total expected bytes. -1 when the server didn't return Content-Length.
  final int totalBytes;

  /// On-disk path of the model when [phase] is [ModelDownloadPhase.ready].
  final String? modelPath;

  /// User-friendly message for the UI.
  final String? message;

  const ModelDownloadStatus({
    required this.phase,
    this.receivedBytes = 0,
    this.totalBytes = -1,
    this.modelPath,
    this.message,
  });

  double? get progress {
    if (totalBytes <= 0 || receivedBytes < 0) return null;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }
}

enum ModelDownloadPhase {
  checking,
  importingFromExternal,
  downloading,
  ready,
  error,
}

/// Resolves the GGUF model the voice assistant needs. Resolution order:
///
/// 1. Already in the app's external private dir (final destination). Use it.
/// 2. Sideloaded into the public Download/ directory or any other readable
///    fallback path. Copy it into the app dir, then use it.
/// 3. Download from [defaultDownloadUrl] (configurable) into the app dir.
///
/// Yields progress so the UI can show a bar.
class ModelDownloader {
  static const String fileName = 'qwen-agri.gguf';

  /// Set this to your hosted .gguf (Hugging Face / Drive / S3 / ...).
  /// Until that's done, sideload via:
  ///
  ///   adb push qwen-agri.gguf \
  ///     /storage/emulated/0/Android/data/com.example.agrismart/files/qwen-agri.gguf
  ///
  /// or drop the file into /sdcard/Download/ on the phone.
  static const String defaultDownloadUrl =
      'https://huggingface.co/REPLACE_ME/agrismart-qwen/resolve/main/qwen-agri.gguf';

  /// Minimum size we accept as a "real" GGUF (filters out HTML error pages).
  static const int _minValidBytes = 50 * 1024 * 1024;

  String? _resolvedPath;
  String? get resolvedPath => _resolvedPath;

  Stream<ModelDownloadStatus> resolve({String? overrideUrl}) async* {
    final url = overrideUrl ?? defaultDownloadUrl;

    yield const ModelDownloadStatus(
      phase: ModelDownloadPhase.checking,
      message: 'Locating Qwen model...',
    );

    final destFile = await _destinationFile();

    if (await _looksValid(destFile)) {
      _resolvedPath = destFile.path;
      yield ModelDownloadStatus(
        phase: ModelDownloadPhase.ready,
        modelPath: destFile.path,
        receivedBytes: await destFile.length(),
        totalBytes: await destFile.length(),
        message: 'Model ready (cached).',
      );
      return;
    }

    final sideloadSource = await _findSideloadSource();
    if (sideloadSource != null) {
      yield ModelDownloadStatus(
        phase: ModelDownloadPhase.importingFromExternal,
        message: 'Importing from ${sideloadSource.path}',
      );
      try {
        await sideloadSource.copy(destFile.path);
        if (await _looksValid(destFile)) {
          _resolvedPath = destFile.path;
          final size = await destFile.length();
          yield ModelDownloadStatus(
            phase: ModelDownloadPhase.ready,
            modelPath: destFile.path,
            receivedBytes: size,
            totalBytes: size,
            message: 'Model ready (sideloaded).',
          );
          return;
        }
      } catch (e) {
        debugPrint('[ModelDownloader] sideload copy failed: $e');
      }
    }

    yield ModelDownloadStatus(
      phase: ModelDownloadPhase.downloading,
      message: 'Downloading Qwen model...',
    );

    try {
      await for (final s in _download(url, destFile)) {
        yield s;
      }
    } catch (e) {
      yield ModelDownloadStatus(
        phase: ModelDownloadPhase.error,
        message: 'Download failed: $e',
      );
      return;
    }

    if (await _looksValid(destFile)) {
      _resolvedPath = destFile.path;
      final size = await destFile.length();
      yield ModelDownloadStatus(
        phase: ModelDownloadPhase.ready,
        modelPath: destFile.path,
        receivedBytes: size,
        totalBytes: size,
        message: 'Model ready (downloaded).',
      );
    } else {
      yield const ModelDownloadStatus(
        phase: ModelDownloadPhase.error,
        message: 'Downloaded file is too small or invalid.',
      );
    }
  }

  Future<File> _destinationFile() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/$fileName');
  }

  Future<File?> _findSideloadSource() async {
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
      if (await f.exists() && await f.length() >= _minValidBytes) {
        return f;
      }
    }
    return null;
  }

  Future<bool> _looksValid(File f) async {
    if (!await f.exists()) return false;
    if (await f.length() < _minValidBytes) return false;
    try {
      final raf = await f.open();
      try {
        final magic = await raf.read(4);
        return magic.length == 4 &&
            magic[0] == 0x47 && // G
            magic[1] == 0x47 && // G
            magic[2] == 0x55 && // U
            magic[3] == 0x46;   // F
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  Stream<ModelDownloadStatus> _download(String url, File dest) async* {
    final tmp = File('${dest.path}.part');
    if (await tmp.exists()) await tmp.delete();

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode}');
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
            yield ModelDownloadStatus(
              phase: ModelDownloadPhase.downloading,
              receivedBytes: received,
              totalBytes: total,
              message: 'Downloading ${_fmtMB(received)}'
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

  static String _fmtMB(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
