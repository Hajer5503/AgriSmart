import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/chatbot_service.dart';

// ─── Modèle message ──────────────────────────────────────
class _Msg {
  final String text;
  final bool isUser;
  _Msg({required this.text, required this.isUser});

  Map<String, dynamic> toJson() =>
      {'role': isUser ? 'user' : 'assistant', 'content': text};
}

// ─── Widget ──────────────────────────────────────────────
class ChatbotWidget extends StatefulWidget {
  const ChatbotWidget({super.key});
  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget>
    with SingleTickerProviderStateMixin {
      
  final _textCtrl = TextEditingController();
  final ChatbotService _chatbotService = ChatbotService();
  final _scrollCtrl = ScrollController();
  late AnimationController _animCtrl;
  bool _isOpen = false;
  bool _isLoading = false;

  // Historique conservé pour la conversation
  final List<_Msg> _messages = [
    _Msg(
      text: '👋 Bonjour ! Je suis **AgriBot**, votre assistant agricole intelligent.\n\n'
          'Je peux :\n'
          '• 🌤️ Consulter la météo en temps réel\n'
          '• 🌾 Analyser vos fermes et cultures\n'
          '• 🚨 Créer des alertes automatiquement\n'
          '• 🐄 Suivre votre bétail\n\n'
          'Posez-moi une question !',
      isUser: false,
    ),
  ];

  // Historique pour l'API (sans le message de bienvenue)
  final List<Map<String, dynamic>> _apiHistory = [];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      _isOpen ? _animCtrl.forward() : _animCtrl.reverse();
    });
  }

  Future<void> _send() async {
  final text = _textCtrl.text.trim();
  if (text.isEmpty || _isLoading) return;
  _textCtrl.clear();

  setState(() {
    _messages.add(_Msg(text: text, isUser: true));
    _isLoading = true;
  });
  _scrollToBottom();

  try {
    // On appelle le service de manière propre
    final botResponse = await _chatbotService.sendMessage(text);

    if (mounted) {
      setState(() {
        _messages.add(_Msg(text: botResponse.text, isUser: false));
      });
    }
  } catch (e) {
    print("ERREUR WIDGET: $e"); // Pour voir l'erreur dans VS Code
    if (mounted) {
      setState(() => _messages.add(_Msg(
            text: '⚠️ Erreur : ${e.toString()}',
            isUser: false,
          )));
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
    _scrollToBottom();
  }
}

  void _clearHistory() {
    setState(() {
      _messages.clear();
      _messages.add(_Msg(
        text: '🔄 Conversation réinitialisée. Comment puis-je vous aider ?',
        isUser: false,
      ));
      _apiHistory.clear();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen)
          SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0, 0.1), end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: _animCtrl, curve: Curves.easeOutBack)),
            child: _buildPanel(),
          ),
        const SizedBox(height: 12),
        _buildButton(),
      ],
    );
  }

  Widget _buildPanel() {
    return SizedBox(
      width: 320,
      height: 480,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Column(children: [
                _buildHeader(),
                Expanded(child: _buildMessages()),
                _buildInput(),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF34C759), Color(0xFF30D158)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AgriBot',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Groq IA · n8n MCP · données réelles',
                style: TextStyle(fontSize: 10, color: Colors.white70)),
          ]),
        ),
        // Bouton effacer historique
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
          tooltip: 'Nouvelle conversation',
          onPressed: _clearHistory,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: _toggle,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
      ]),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _messages.length && _isLoading) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.green.shade400)),
                const SizedBox(width: 10),
                const Text('AgriBot réfléchit…',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ]),
            ),
          );
        }

        final msg = _messages[i];
        return Align(
          alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              gradient: msg.isUser
                  ? const LinearGradient(
                      colors: [Color(0xFF34C759), Color(0xFF30D158)])
                  : null,
              color: msg.isUser ? null : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(msg.text,
                style: TextStyle(
                    fontSize: 14,
                    color: msg.isUser ? Colors.white : Colors.black87,
                    height: 1.4)),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _textCtrl,
            style: const TextStyle(fontSize: 14),
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Ex: Quelle est la météo à Tunis ?',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _send,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isLoading
                    ? [Colors.grey.shade400, Colors.grey.shade400]
                    : const [Color(0xFF34C759), Color(0xFF30D158)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isLoading ? Icons.hourglass_empty_rounded : Icons.send_rounded,
              color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _buildButton() {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58, height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF34C759), Color(0xFF30D158)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: const Color(0xFF34C759).withValues(alpha: 0.4),
              blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Icon(
            _isOpen ? Icons.close_rounded : Icons.smart_toy_rounded,
            color: Colors.white, size: 28),
      ),
    );
  }
}