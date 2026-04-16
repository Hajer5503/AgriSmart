import 'api_service.dart';

class Task {
  final int id;
  final int userId;
  final String title;
  final String description;
  bool done;
  final String priority;
  final String? dueDate;
  final String? category;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.done,
    required this.priority,
    this.dueDate,
    this.category,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        userId: json['user_id'],
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        done: json['done'] ?? false,
        priority: json['priority'] ?? 'medium',
        dueDate: json['due_date'],
        category: json['category'],
      );
}

class TaskService {
  final ApiService _api = ApiService();

  Future<List<Task>> getTasks() async {
    final response = await _api.get('/tasks');
    return (response.data as List).map((e) => Task.fromJson(e)).toList();
  }

  Future<Task> createTask({
    required String title,
    required String description,
    required String priority,
    required String category,
    String? dueDate,
  }) async {
    final response = await _api.post('/tasks', data: {
      'title': title,
      'description': description,
      'priority': priority,
      'category': category,
      'due_date': dueDate,
    });
    return Task.fromJson(response.data);
  }

  Future<Task> toggleTask(int taskId) async {
    final response = await _api.put('/tasks/$taskId/toggle');
    return Task.fromJson(response.data);
  }

  Future<void> deleteTask(int taskId) async {
    await _api.delete('/tasks/$taskId');
  }
}