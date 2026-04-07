import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

// ─── Modèle de message ──────────────────────────────────────
class _Msg {
  final String text;
  final bool isUser;
  final DateTime time;
  _Msg({required this.text, required this.isUser}) : time = DateTime.now();
}

// ─── Widget chatbot ─────────────────────────────────────────
class ChatbotWidget extends StatefulWidget {
  const ChatbotWidget({super.key});

  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late AnimationController _animCtrl;

  bool _isOpen = false;
  bool _isLoading = false;
  final List<_Msg> _messages = [
    _Msg(
      text: '👋 Bonjour ! Je suis votre assistant AgriSmart. '
          'Posez-moi des questions sur l\'irrigation, '
          'les maladies des cultures, l\'élevage ou la météo.',
      isUser: false,
    ),
  ];

  // ⬇️ Remplace par ta vraie clé Anthropic
  static const String _apiKey = 'VOTRE_CLE_ANTHROPIC_ICI';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
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

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    _textCtrl.clear();

    // Récupère infos user avant async
    final authService = Provider.of<AuthService>(context, listen: false);
    final userName = authService.currentUser?.name ?? 'Agriculteur';
    final userRole = authService.currentUser?.role ?? 'farmer';

    setState(() {
      _messages.add(_Msg(text: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // Construire l'historique pour Claude
      final history = _messages
          .where((m) => m.text !=
              '👋 Bonjour ! Je suis votre assistant AgriSmart. '
              'Posez-moi des questions sur l\'irrigation, '
              'les maladies des cultures, l\'élevage ou la météo.')
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 500,
          'system': '''Tu es un assistant agricole expert pour la plateforme AgriSmart en Tunisie.
Tu aides les agriculteurs, éleveurs, vétérinaires et agronomes.
L'utilisateur s'appelle $userName et son rôle est $userRole.
Réponds de façon concise et pratique en français.
Spécialités : irrigation, maladies des cultures, santé animale, météo agricole, conseils de semis.
Si tu ne sais pas, dis-le honnêtement. Maximum 3 paragraphes par réponse.''',
          'messages': history,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['content'][0]['text'] as String;
        if (mounted) {
          setState(() {
            _messages.add(_Msg(text: reply, isUser: false));
          });
        }
      } else {
        // Fallback si API indisponible
        if (mounted) {
          setState(() {
            _messages.add(_Msg(
              text: _localFallback(text),
              isUser: false,
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_Msg(
            text: _localFallback(text),
            isUser: false,
          ));
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  /// Réponses de secours locales si l'API est indisponible
  String _localFallback(String question) {
    final q = question.toLowerCase();
    if (q.contains('irrigat') || q.contains('eau') || q.contains('arros')) {
      return '💧 Pour l\'irrigation : vérifiez l\'humidité du sol avant d\'arroser. '
          'En période chaude, privilégiez les arrosages tôt le matin ou en soirée '
          'pour réduire l\'évaporation.';
    }
    if (q.contains('maladie') || q.contains('parasite') || q.contains('champignon')) {
      return '🌿 En cas de maladie détectée, isolez les plants atteints, '
          'prenez des photos et consultez un agronome. '
          'Évitez les traitements chimiques sans diagnostic précis.';
    }
    if (q.contains('météo') || q.contains('pluie') || q.contains('température')) {
      return '☀️ Consultez les prévisions météo locales régulièrement. '
          'En Tunisie, adaptez vos pratiques selon les saisons : '
          'réduisez l\'irrigation après les pluies.';
    }
    if (q.contains('bétail') || q.contains('animal') || q.contains('vache')) {
      return '🐄 Pour la santé animale, surveillez l\'alimentation, '
          'l\'hydratation et le comportement. Tout changement brusque '
          'nécessite un avis vétérinaire.';
    }
    return '🤖 Je n\'ai pas pu contacter le serveur IA. '
        'Vérifiez votre connexion. En attendant, consultez '
        'votre agronome ou vétérinaire pour des conseils personnalisés.';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Panel chat
        if (_isOpen)
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
                parent: _animCtrl, curve: Curves.easeOutBack)),
            child: _buildPanel(),
          ),
        const SizedBox(height: 12),
        // Bouton
        _buildButton(),
      ],
    );
  }

  Widget _buildPanel() {
    return SizedBox(
      width: 320,
      height: 460,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10)),
          ],
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
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildMessages()),
                  _buildInput(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF34C759), Color(0xFF30D158)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assistant AgriSmart',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text('Propulsé par IA',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: _toggle),
        ],
      ),
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('En train de répondre…',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          );
        }
        final msg = _messages[i];
        return Align(
          alignment:
              msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 250),
            decoration: BoxDecoration(
              gradient: msg.isUser
                  ? const LinearGradient(
                      colors: [Color(0xFF34C759), Color(0xFF30D158)])
                  : null,
              color: msg.isUser ? null : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                  fontSize: 14,
                  color: msg.isUser ? Colors.white : Colors.black87),
            ),
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
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Posez votre question…',
                hintStyle: const TextStyle(fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF34C759), Color(0xFF30D158)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF34C759), Color(0xFF30D158)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF34C759).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Icon(
          _isOpen ? Icons.close_rounded : Icons.smart_toy_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}