/*import '../models/chat_message.dart';
import 'api_service.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart'; // INDISPENSABLE pour le débug

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
     final response = await _apiService.post('/agent/chat', data: {
  'message': text,
  'image_url': imageUrl,
  'history': _messages.map((m) => m.toJson()).toList(), // Utilise 'history' pour matcher server.js
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
  print('❌ ERREUR CHATBOT SERVICE: $e'); // AJOUTE CETTE LIGNE
  if (e is DioException) {
    print('Status: ${e.response?.statusCode}');
    print('Data: ${e.response?.data}');
  }
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
      // Ajoute ces prints pour voir l'erreur dans ta console VS Code
  print('DEBUG CHATBOT ERROR: $e'); 
  if (e is DioException) {
    print('DATA: ${e.response?.data}');
    print('STATUS: ${e.response?.statusCode}');
    }
    throw Exception('Erreur chatbot: ${e.toString()}');
    }
  }
}
*/

import '../models/chat_message.dart';
import 'api_service.dart';
import 'package:uuid/uuid.dart';

class ChatbotService {
  final ApiService _apiService = ApiService();
  final _uuid = const Uuid();

  // Historique local pour l'affichage
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  // Historique API (format {role, content})
  final List<Map<String, dynamic>> _apiHistory = [];

  Future<ChatMessage> sendMessage(String text) async {
    // Ajoute le message utilisateur
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      text: text,
      isUser: true,
    );
    _messages.add(userMsg);

    // Appelle /api/agent/chat avec le vrai token JWT (géré par ApiService)
    final response = await _apiService.post('/agent/chat', data: {
      'message': text,
      'history': _apiHistory, // historique propre sans le message de bienvenue
    });

    final reply = response.data['response'] as String? ??
        'Désolé, je ne peux pas répondre maintenant.';

    // Met à jour l'historique API depuis la réponse serveur
    final serverHistory = response.data['history'];
    if (serverHistory is List) {
      _apiHistory.clear();
      _apiHistory.addAll(serverHistory.cast<Map<String, dynamic>>());
    } else {
      // Fallback manuel
      _apiHistory.add({'role': 'user', 'content': text});
      _apiHistory.add({'role': 'assistant', 'content': reply});
    }

    final botMsg = ChatMessage(
      id: _uuid.v4(),
      text: reply,
      isUser: false,
    );
    _messages.add(botMsg);
    return botMsg;
  }

  void clearHistory() {
    _messages.clear();
    _apiHistory.clear();
  }
}