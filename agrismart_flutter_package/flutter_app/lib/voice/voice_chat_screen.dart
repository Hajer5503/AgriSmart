import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'llm_service.dart';
import 'model_downloader.dart';
import 'tts_service.dart';
import 'whisper_stt_service.dart';

/// Phases of the voice loop.
enum VoiceState { loading, idle, listening, thinking, speaking, error }

/// One bubble in the conversation list.
class _Message {
  final String role; // 'user' or 'assistant'
  String text;
  bool streaming;
  _Message({required this.role, required this.text, this.streaming = false});
}

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with SingleTickerProviderStateMixin {
  final ModelDownloader _qwenDownloader = ModelDownloader();
  final LlmService _llm = LlmService();
  final WhisperSttService _stt = WhisperSttService();
  final TtsService _tts = TtsService();

  VoiceState _state = VoiceState.loading;
  String _status = 'جاري التحضير...';
  double? _loadProgress;

  final List<_Message> _messages = <_Message>[];
  final ScrollController _scroll = ScrollController();

  StreamSubscription<double>? _ampSub;
  StreamSubscription<String>? _llmSub;
  StreamSubscription<bool>? _ttsSub;

  double _soundLevel = 0;

  final TextEditingController _typedCtl = TextEditingController();
  final FocusNode _typedFocus = FocusNode();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // 1) Locate / download Qwen
      String? qwenPath;
      await for (final s in _qwenDownloader.resolve()) {
        if (!mounted) return;
        setState(() {
          _status = '[1/3] ${s.message ?? ''}';
          _loadProgress = s.progress;
        });
        if (s.phase == ModelDownloadPhase.error) {
          _setState(VoiceState.error, 'فشل تحميل نموذج Qwen: ${s.message}');
          return;
        }
        if (s.phase == ModelDownloadPhase.ready && s.modelPath != null) {
          qwenPath = s.modelPath;
          break;
        }
      }
      if (qwenPath == null) {
        _setState(VoiceState.error, 'تعذّر العثور على Qwen.');
        return;
      }

      // 2) Load Qwen into llama.cpp
      if (!mounted) return;
      setState(() {
        _status = '[2/3] جاري تحميل Qwen في الذاكرة...';
        _loadProgress = null;
      });
      await _llm.load(qwenPath);

      // 3) Locate / download Whisper-base
      await for (final s in _stt.bootstrap()) {
        if (!mounted) return;
        setState(() {
          _status = '[3/3] ${s.message ?? ''}';
          _loadProgress = s.progress;
        });
        if (s.phase == WhisperReadyPhase.error) {
          _setState(VoiceState.error, 'فشل تحميل Whisper: ${s.message}');
          return;
        }
      }

      // 4) Init TTS and amplitude stream
      await _tts.initialize();
      _ttsSub = _tts.speakingStream.listen(_onTtsSpeakingChanged);
      _ampSub = _stt.soundLevel.listen((db) {
        if (!mounted) return;
        setState(() => _soundLevel = db);
      });

      if (!mounted) return;
      _setState(VoiceState.idle, 'اضغط على الميكروفون وتكلّم');
    } catch (e) {
      _setState(VoiceState.error, 'خطأ غير متوقع: $e');
    }
  }

  void _setState(VoiceState s, String msg) {
    if (!mounted) return;
    setState(() {
      _state = s;
      _status = msg;
      _loadProgress = null;
    });
  }

  void _onTtsSpeakingChanged(bool speaking) {
    if (!mounted) return;
    if (speaking) {
      setState(() {
        _state = VoiceState.speaking;
        _status = 'يتكلّم...';
      });
    } else if (_state == VoiceState.speaking) {
      _setState(VoiceState.idle, 'اضغط على الميكروفون وتكلّم');
    }
  }

  Future<void> _onMicPressed() async {
    switch (_state) {
      case VoiceState.idle:
        await _startListening();
        break;
      case VoiceState.listening:
        await _stopAndTranscribe();
        break;
      case VoiceState.thinking:
        await _llm.stop();
        await _llmSub?.cancel();
        _setState(VoiceState.idle, 'تمّ الإلغاء');
        break;
      case VoiceState.speaking:
        await _tts.stop();
        _setState(VoiceState.idle, 'اضغط على الميكروفون وتكلّم');
        break;
      case VoiceState.loading:
      case VoiceState.error:
        break;
    }
  }

  Future<void> _startListening() async {
    _soundLevel = 0;
    _stt.onMaxDurationReached = () {
      if (mounted && _state == VoiceState.listening) {
        _stopAndTranscribe();
      }
    };
    try {
      await _stt.startRecording();
      _setState(
        VoiceState.listening,
        'استمع... تكلّم بالعربية (الحد الأقصى 10 ثوانٍ)',
      );
    } catch (e) {
      _setState(VoiceState.idle, 'تعذّر تشغيل الميكروفون: $e');
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (!mounted) return;
    setState(() {
      _state = VoiceState.thinking;
      _status = 'يحوّل صوتك إلى نص...';
      _loadProgress = null;
    });
    try {
      final text = await _stt.stopAndTranscribe();
      final clean = text.trim();
      if (clean.isEmpty) {
        _setState(VoiceState.idle, 'لم أتمكن من فهم ما قلت، حاول مجدداً');
        return;
      }
      await _onUserUtterance(clean);
    } catch (e) {
      _setState(VoiceState.idle, 'خطأ في التحويل: $e');
    }
  }

  Future<void> _onUserUtterance(String text) async {
    setState(() {
      _messages.add(_Message(role: 'user', text: text));
    });
    _scrollToBottom();
    await _runLlm(text);
  }

  Future<void> _runLlm(String userText) async {
    _setState(VoiceState.thinking, 'يفكّر...');
    final assistantMsg = _Message(role: 'assistant', text: '', streaming: true);
    setState(() => _messages.add(assistantMsg));

    final buffer = StringBuffer();
    var spokenUpTo = 0;
    await _llmSub?.cancel();
    final completer = Completer<void>();

    void flushSentenceIfReady({bool force = false}) {
      final full = buffer.toString();
      while (spokenUpTo < full.length) {
        final remaining = full.substring(spokenUpTo);
        final m = RegExp(r'[.؟?!\n،,]').firstMatch(remaining);
        if (m == null) break;
        final end = spokenUpTo + m.end;
        final sentence = full.substring(spokenUpTo, end).trim();
        spokenUpTo = end;
        if (sentence.isNotEmpty && sentence.length >= 2) {
          _tts.speak(sentence);
        }
      }
      if (force && spokenUpTo < full.length) {
        final tail = full.substring(spokenUpTo).trim();
        if (tail.isNotEmpty) _tts.speak(tail);
        spokenUpTo = full.length;
      }
    }

    _llmSub = _llm.chat(userText).listen(
      (token) {
        buffer.write(token);
        if (!mounted) return;
        setState(() => assistantMsg.text = buffer.toString());
        _scrollToBottom();
        flushSentenceIfReady();
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          assistantMsg.streaming = false;
          assistantMsg.text = '⚠️ خطأ: $e';
        });
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        if (!mounted) return;
        setState(() => assistantMsg.streaming = false);
        flushSentenceIfReady(force: true);
        if (!completer.isCompleted) completer.complete();
      },
    );

    await completer.future;
    if (buffer.isEmpty) {
      _setState(VoiceState.idle, 'لا توجد إجابة');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearChat() async {
    await _stt.cancel();
    await _llm.stop();
    await _tts.stop();
    _llm.clearHistory();
    setState(() => _messages.clear());
    _setState(VoiceState.idle, 'اضغط على الميكروفون وتكلّم');
  }

  Future<void> _sendTyped() async {
    final t = _typedCtl.text.trim();
    if (t.isEmpty || _state == VoiceState.thinking || _state == VoiceState.loading) return;
    _typedFocus.unfocus();
    _typedCtl.clear();
    if (_state == VoiceState.speaking) await _tts.stop();
    if (_state == VoiceState.listening) await _stt.cancel();
    await _onUserUtterance(t);
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _llmSub?.cancel();
    _ttsSub?.cancel();
    _pulse.dispose();
    _stt.dispose();
    _tts.dispose();
    _llm.dispose();
    _scroll.dispose();
    _typedCtl.dispose();
    _typedFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          title: const Text('المساعد الصوتي'),
          actions: [
            if (_messages.isNotEmpty && _state != VoiceState.loading)
              IconButton(
                onPressed: _clearChat,
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'مسح المحادثة',
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_state == VoiceState.loading) _buildLoading(),
              if (_state == VoiceState.error) _buildError(),
              if (_state != VoiceState.loading && _state != VoiceState.error)
                Expanded(child: _buildConversation()),
              if (_state != VoiceState.loading && _state != VoiceState.error)
                _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.smart_toy_outlined, size: 64, color: Color(0xFF2E7D32)),
              const SizedBox(height: 24),
              if (_loadProgress != null)
                LinearProgressIndicator(value: _loadProgress)
              else
                const LinearProgressIndicator(),
              const SizedBox(height: 16),
              Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _setState(VoiceState.loading, 'إعادة المحاولة...');
                  _bootstrap();
                },
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversation() {
    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'مرحباً! أنا أَغريسمارت، مساعدُك الزراعي.\n'
            'اضغط على الميكروفون أسفل الشاشة وتكلّم بالعربية، '
            'ثم اضغط مجدداً عند الانتهاء.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        return _bubble(role: m.role, text: m.text, streaming: m.streaming);
      },
    );
  }

  Widget _bubble({
    required String role,
    required String text,
    bool streaming = false,
    bool ghost = false,
  }) {
    final isUser = role == 'user';
    final align = isUser ? Alignment.centerLeft : Alignment.centerRight;
    final color = isUser ? const Color(0xFFE3F2FD) : Colors.white;
    final border = isUser ? const Color(0xFF90CAF9) : const Color(0xFFC8E6C9);

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: ghost ? color.withValues(alpha: 0.5) : color,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUser ? 'أنت' : 'المساعد',
              style: TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text + (streaming ? ' ▍' : ''),
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final canType = _state != VoiceState.loading && _state != VoiceState.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _typedCtl,
                  focusNode: _typedFocus,
                  enabled: canType,
                  textDirection: TextDirection.rtl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendTyped(),
                  decoration: InputDecoration(
                    hintText: 'اكتب سؤالك هنا...',
                    hintStyle: const TextStyle(color: Colors.black38),
                    filled: true,
                    fillColor: const Color(0xFFF1F8E9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: canType ? _sendTyped : null,
                icon: const Icon(Icons.send_rounded, color: Color(0xFF2E7D32)),
                tooltip: 'إرسال',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_status, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          _buildMicButton(),
          const SizedBox(height: 4),
          _localeHint(),
        ],
      ),
    );
  }

  Widget _localeHint() {
    final tts = _tts.selectedLanguage ?? '...';
    return Text(
      'STT: Whisper-base (offline, ar)   ·   TTS: $tts',
      style: const TextStyle(fontSize: 11, color: Colors.black38),
    );
  }

  Widget _buildMicButton() {
    final color = _stateColor();
    final icon = _stateIcon();
    final isListening = _state == VoiceState.listening;
    final isThinking = _state == VoiceState.thinking;
    final isSpeaking = _state == VoiceState.speaking;
    final isActive = isListening || isThinking || isSpeaking;

    // record's onAmplitudeChanged returns dBFS (0 dB = max, ~-60 dB = silence).
    // Normalize to a 0..1 visual amplitude for the pulsing rings.
    final amp = isListening
        ? ((_soundLevel + 50) / 50).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isListening) ..._buildListeningRings(color, amp),
          if (isThinking) _buildSpinningRing(color),
          if (isSpeaking) ..._buildSpeakingWaves(color),
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final breath = isActive
                  ? 1.0 + 0.06 * _pulse.value
                  : 1.0 + 0.03 * _pulse.value;
              final volScale = isListening ? 1.0 + 0.18 * amp : 1.0;
              return Transform.scale(
                scale: breath * volScale,
                child: GestureDetector(
                  onTap: _onMicPressed,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Color.lerp(Colors.white, color, 0.65)!,
                          color,
                        ],
                        radius: 0.9,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.55),
                          blurRadius: 22,
                          spreadRadius: isActive ? 4 : 1,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                        width: 3,
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 44),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Concentric pulsing rings while STT is listening. Outer ring fade-out is
  /// driven by [_pulse]; their reach is amplified by the live mic sound level.
  List<Widget> _buildListeningRings(Color color, double amp) {
    return List.generate(3, (i) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final phase = (_pulse.value + i / 3) % 1.0;
          final size = 96 + phase * (60 + 40 * amp);
          final opacity = (1.0 - phase).clamp(0.0, 1.0) * 0.55;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: opacity),
                width: 2.5,
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildSpinningRing(Color color) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Transform.rotate(
          angle: _pulse.value * 2 * math.pi,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  color.withValues(alpha: 0.0),
                  color.withValues(alpha: 0.6),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  /// While TTS is speaking, render fake equalizer bars under the mic button.
  List<Widget> _buildSpeakingWaves(Color color) {
    return [
      AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          return Positioned(
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final h = 6 +
                    18 *
                        ((math.sin((t * 2 * math.pi) + i * 0.7) + 1) / 2);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 4,
                    height: h,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    ];
  }

  Color _stateColor() {
    switch (_state) {
      case VoiceState.listening:
        return const Color(0xFFE53935);
      case VoiceState.thinking:
        return const Color(0xFFFB8C00);
      case VoiceState.speaking:
        return const Color(0xFF1E88E5);
      case VoiceState.error:
        return Colors.grey;
      case VoiceState.loading:
      case VoiceState.idle:
        return const Color(0xFF2E7D32);
    }
  }

  IconData _stateIcon() {
    switch (_state) {
      case VoiceState.listening:
        return Icons.stop_rounded;
      case VoiceState.thinking:
        return Icons.hourglass_top_rounded;
      case VoiceState.speaking:
        return Icons.volume_up_rounded;
      case VoiceState.error:
      case VoiceState.loading:
      case VoiceState.idle:
        return Icons.mic_rounded;
    }
  }
}
