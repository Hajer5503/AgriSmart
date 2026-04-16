/*import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? _currentUser;
  User? get currentUser => _currentUser;

  // Login
  Future<User> login(String email, String password) async {
    try {
      final response = await _apiService.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final token = response.data['token'];
      final userData = response.data['user'];

      // Sauvegarder le token
      await _storage.write(key: 'auth_token', value: token);
      
      // Créer l'objet utilisateur
      _currentUser = User.fromJson(userData);
      
      return _currentUser!;
    } catch (e) {
      throw Exception('Erreur de connexion: ${e.toString()}');
    }
  }

  // Register
  Future<User> register({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
  }) async {
    try {
      final response = await _apiService.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        'role': role,
        'phone': phone,
      });

      final token = response.data['token'];
      final userData = response.data['user'];

      await _storage.write(key: 'auth_token', value: token);
      _currentUser = User.fromJson(userData);

      return _currentUser!;
    } catch (e) {
      throw Exception('Erreur d\'inscription: ${e.toString()}');
    }
  }

  // Logout
  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    _currentUser = null;
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null;
  }

  // Get current user from API
  Future<User?> getCurrentUser() async {
    try {
      if (!await isLoggedIn()) return null;

      final response = await _apiService.get('/auth/me');
      _currentUser = User.fromJson(response.data);
      return _currentUser;
    } catch (e) {
      return null;
    }
  }
}*/

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? _currentUser;
  User? get currentUser => _currentUser;

  Future<User> login(String email, String password) async {
    final response = await _apiService.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    // ✅ Sauvegarde le VRAI token JWT
    final token = response.data['token'] as String;
    final userData = response.data['user'];

    await _storage.write(key: 'auth_token', value: token);
    _currentUser = User.fromJson(userData);
    return _currentUser!;
  }

  Future<User> register({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
  }) async {
    final response = await _apiService.post('/auth/register', data: {
      'email': email,
      'password': password,
      'name': name,
      'role': role,
      'phone': phone,
    });

    final token = response.data['token'] as String;
    final userData = response.data['user'];

    await _storage.write(key: 'auth_token', value: token);
    _currentUser = User.fromJson(userData);
    return _currentUser!;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    _currentUser = null;
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null && token.isNotEmpty;
  }

  Future<User?> getCurrentUser() async {
    try {
      if (!await isLoggedIn()) return null;
      final response = await _apiService.get('/auth/me');
      _currentUser = User.fromJson(response.data);
      return _currentUser;
    } catch (e) {
      // Token expiré ou invalide → déconnecte
      await _storage.delete(key: 'auth_token');
      return null;
    }
  }
}
