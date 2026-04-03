import '../models/chat_message.dart';
import 'api_service.dart';
import 'package:uuid/uuid.dart';

class ChatbotService {
  final ApiService _apiService = ApiService();
  final List<ChatMessage> _messages = [];
  final _uuid = const Uuid();

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  // Envoyer un message au chatbot
  Future<ChatMessage> sendMessage(String text, {String? imageUrl}) async {
    try {
      // Ajouter le message de l'utilisateur
      final userMessage = ChatMessage(
        id: _uuid.v4(),
        text: text,
        isUser: true,
        imageUrl: imageUrl,
      );
      _messages.add(userMessage);

      // Appeler l'API du chatbot
      final response = await _apiService.post('/chatbot/message', data: {
        'message': text,
        'image_url': imageUrl,
        'conversation_history': _messages.map((m) => m.toJson()).toList(),
      });

      // Ajouter la réponse du bot
      final botMessage = ChatMessage(
        id: _uuid.v4(),
        text: response.data['response'],
        isUser: false,
      );
      _messages.add(botMessage);

      return botMessage;
    } catch (e) {
      throw Exception('Erreur chatbot: ${e.toString()}');
    }
  }

  // Effacer l'historique
  void clearHistory() {
    _messages.clear();
  }

  // Charger l'historique depuis l'API
  Future<void> loadHistory() async {
    try {
      final response = await _apiService.get('/chatbot/history');
      _messages.clear();
      _messages.addAll(
        (response.data as List).map((json) => ChatMessage.fromJson(json)),
      );
    } catch (e) {
      // Ignorer l'erreur si pas d'historique
    }
  }
}
