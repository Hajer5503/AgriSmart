import 'api_service.dart';

class Alert {
  final int id;
  final String type;
  final String severity;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
    id: json['id'],
    type: json['type'],
    severity: json['severity'],
    message: json['message'],
    isRead: json['is_read'] ?? false,
    createdAt: DateTime.parse(json['created_at']),
  );
}

class AlertService {
  final ApiService _api = ApiService();

  Future<List<Alert>> getAlerts(int userId) async {
    final response = await _api.get('/alerts', queryParameters: {'user_id': userId});
    return (response.data as List).map((e) => Alert.fromJson(e)).toList();
  }

  Future<void> markAsRead(int alertId) async {
    await _api.put('/alerts/$alertId/read');
  }
}