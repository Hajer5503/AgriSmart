import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

/// One turn in the chat history sent back to Qwen.
class ChatTurn {
  final String role; // 'system' | 'user' | 'assistant'
  final String content;
  const ChatTurn(this.role, this.content);
}

/// Lightweight wrapper around [LlamaController] tuned for the AgriSmart
/// Arabic agriculture assistant.
///
/// - Loads the GGUF once and keeps the context alive.
/// - Exposes a [chat] coroutine that streams Qwen's tokens back token-by-token.
/// - Maintains a rolling history (system + last N turns) on the Dart side and
///   reformats it via the ChatML template that ships with the plugin.
class LlmService {
  LlmService({
    String? systemPrompt,
    int contextSize = 512,
    int threads = 4,
    int maxHistoryTurns = 2,
  })  : _systemPrompt = systemPrompt ?? _defaultSystemPrompt,
        _contextSize = contextSize,
        _threads = threads,
        _maxHistoryTurns = maxHistoryTurns;

  static const String _defaultSystemPrompt =
      'أنت مساعد زراعي ذكي للمزارعين التونسيين. '
      'أجب بجملة أو جملتين فقط، بالعربية أو باللهجة التونسية. '
      'كن مباشراً وعملياً.';

  final LlamaController _controller = LlamaController();
  final String _systemPrompt;
  final int _contextSize;
  final int _threads;
  final int _maxHistoryTurns;

  final List<ChatTurn> _history = <ChatTurn>[];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  StreamSubscription<String>? _activeGen;

  String get systemPrompt => _systemPrompt;
  List<ChatTurn> get history => List.unmodifiable(_history);

  Future<void> load(String modelPath) async {
    if (_loaded) return;

    // EMPIRICAL on Mali-G52 MC2 (Xiaomi mid-range): Vulkan offload of any
    // number of layers is *slower* than CPU for Qwen2 0.5B Q8 (memory
    // transfer overhead dominates). The plugin's auto-detection rightly
    // returns recommendedGpuLayers=0 — we now respect that strictly.
    final gpuLayers = 0;

    try {
      final gpu = await _controller.detectGpu();
      debugPrint('[LlmService] GPU: ${gpu.gpuName}  '
          'vulkan=${gpu.vulkanSupported}  '
          'recommended=${gpu.recommendedGpuLayers}  '
          'using=$gpuLayers (CPU)');
    } catch (e) {
      debugPrint('[LlmService] detectGpu failed: $e');
    }

    await _controller.loadModel(
      modelPath: modelPath,
      threads: _threads,
      contextSize: _contextSize,
      gpuLayers: gpuLayers,
    );
    _loaded = true;
    debugPrint('[LlmService] model loaded ($modelPath) ctx=$_contextSize threads=$_threads');

    // Warmup — first inference includes prompt processing + KV cache fill which
    // can take a few seconds. Burning that cost at load time means the first
    // user-visible response is much faster.
    unawaited(_warmup());
  }

  Future<void> _warmup() async {
    _warmupCompleter = Completer<void>();
    try {
      final sw = Stopwatch()..start();
      final stream = _controller.generateChat(
        messages: [
          ChatMessage(role: 'system', content: _systemPrompt),
          ChatMessage(role: 'user', content: 'مرحبا'),
        ],
        template: 'chatml',
        temperature: 0.0,
        maxTokens: 1,
      );
      await for (final _ in stream) {}
      debugPrint('[LlmService] warmup done in ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('[LlmService] warmup failed: $e');
    } finally {
      _warmupCompleter?.complete();
    }
  }

  Completer<void>? _warmupCompleter;

  /// Sends [userMessage] to Qwen with the running history and yields each
  /// generated token (already detokenized to a string fragment).
  /// The full reply is appended to [_history] when the stream completes.
  Stream<String> chat(String userMessage) async* {
    if (!_loaded) {
      throw StateError('LlmService.chat called before load()');
    }
    if (_warmupCompleter != null && !_warmupCompleter!.isCompleted) {
      debugPrint('[LlmService] waiting for warmup to finish before chat...');
      await _warmupCompleter!.future;
    }
    _history.add(ChatTurn('user', userMessage));

    final messages = <ChatMessage>[
      ChatMessage(role: 'system', content: _systemPrompt),
      for (final t in _trimmedHistory()) ChatMessage(role: t.role, content: t.content),
    ];

    final buffer = StringBuffer();
    final controller = StreamController<String>();

    await _activeGen?.cancel();
    final stopwatch = Stopwatch()..start();
    var firstTokenLogged = false;
    var tokenCount = 0;
    _activeGen = _controller
        .generateChat(
          messages: messages,
          template: 'chatml',
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.15,
          maxTokens: 120,
        )
        .listen(
          (token) {
            tokenCount++;
            if (!firstTokenLogged) {
              firstTokenLogged = true;
              debugPrint('[LlmService] TTFT ${stopwatch.elapsedMilliseconds}ms');
            }
            buffer.write(token);
            if (!controller.isClosed) controller.add(token);
          },
          onError: (Object e, StackTrace st) {
            debugPrint('[LlmService] generation error: $e');
            if (!controller.isClosed) {
              controller.addError(e, st);
              controller.close();
            }
          },
          onDone: () {
            stopwatch.stop();
            final ms = stopwatch.elapsedMilliseconds;
            final tps = tokenCount > 0 && ms > 0
                ? (tokenCount * 1000 / ms).toStringAsFixed(1)
                : '0';
            debugPrint('[LlmService] done: $tokenCount tokens in ${ms}ms ($tps tok/s)');
            _history.add(ChatTurn('assistant', buffer.toString().trim()));
            if (!controller.isClosed) controller.close();
          },
          cancelOnError: true,
        );

    yield* controller.stream;
  }

  /// Cancel the currently streaming reply, if any. Safe to call any time.
  Future<void> stop() async {
    try {
      await _controller.stop();
    } catch (_) {}
    await _activeGen?.cancel();
    _activeGen = null;
  }

  void clearHistory() {
    _history.clear();
  }

  List<ChatTurn> _trimmedHistory() {
    if (_history.length <= _maxHistoryTurns * 2) return _history;
    return _history.sublist(_history.length - _maxHistoryTurns * 2);
  }

  Future<void> dispose() async {
    await stop();
    try {
      await _controller.dispose();
    } catch (_) {}
    _loaded = false;
  }
}
