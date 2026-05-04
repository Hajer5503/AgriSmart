/*import 'api_service.dart';

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
}*/
import 'api_service.dart';

// Adapté à ta vraie BD : alert_type, title, is_read
class Alert {
  final int id;
  final String type;     // colonne: alert_type
  final String severity;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'],
        // BD utilise alert_type, fallback sur type pour compatibilité
        type: json['alert_type'] ?? json['type'] ?? 'unknown',
        severity: json['severity'] ?? 'low',
        title: json['title'] ?? json['alert_type'] ?? 'Alerte',
        message: json['message'] ?? '',
        isRead: json['is_read'] ?? false,
        createdAt: DateTime.parse(json['created_at']),
      );
}

class AlertService {
  final ApiService _api = ApiService();

  // ✅ Plus de user_id en paramètre — le JWT s'en charge côté serveur
  Future<List<Alert>> getAlerts() async {
    final response = await _api.get('/alerts');
    return (response.data as List).map((e) => Alert.fromJson(e)).toList();
  }

  Future<void> markAsRead(int alertId) async {
    await _api.put('/alerts/$alertId/read');
  }

  Future<Alert> createAlert({
    required String alertType,
    required String severity,
    required String title,
    required String message,
    int? farmId,
  }) async {
    final response = await _api.post('/alerts', data: {
      'alert_type': alertType,
      'severity': severity,
      'title': title,
      'message': message,
      'farm_id': farmId,
    });
    return Alert.fromJson(response.data);
  }
}