import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  /// - Release: Railway (HTTPS). Override with `--dart-define=API_BASE_URL=...`.
  /// - Debug sans define: émulateur Android → `http://10.0.2.2:3000/api`.
  /// - Téléphone sur le Wi‑Fi: `flutter run --dart-define=API_BASE_URL=http://VOTRE_IP_PC:3000/api`
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kDebugMode) return 'http://10.0.2.2:3000/api';
    return 'https://grand-wonder-production-6ef6.up.railway.app/api';
  }

  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
    },
  )) {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Ajouter le token d'authentification
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Token expiré - déconnecter l'utilisateur
          await _storage.delete(key: 'auth_token');
        }
        return handler.next(error);
      },
    ));
  }

  static String extractError(Object e) {
    if (e is DioException) {
      assert(() {
        debugPrint('[API] type=${e.type} status=${e.response?.statusCode} data=${e.response?.data}');
        return true;
      }());
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Le serveur ne répond pas. Réessayez dans quelques secondes.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Impossible de joindre le serveur. Vérifiez votre connexion.';
      }
      if (e.response?.statusCode == 401) {
        return 'Session expirée. Veuillez vous reconnecter.';
      }
      final body = e.response?.data;
      if (body is Map) {
        final debug = body['debug']?.toString();
        final detail = body['detail']?.toString();
        final msg   = body['message']?.toString();
        if (detail != null && detail.isNotEmpty) return 'Erreur serveur : $detail';
        if (debug != null && debug.isNotEmpty) return 'Erreur serveur : $debug';
        if (msg   != null && msg.isNotEmpty)   return msg;
      }
      final code = e.response?.statusCode;
      if (code != null) return 'Erreur HTTP $code.';
    }
    assert(() { debugPrint('[API] Non-Dio: $e'); return true; }());
    return e.toString();
  }

  // GET request
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  // POST request
  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } catch (e) {
      rethrow;
    }
  }

  // PUT request
  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } catch (e) {
      rethrow;
    }
  }

  // DELETE request
  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } catch (e) {
      rethrow;
    }
  }

  // Upload file
  Future<Response> uploadFile(String path, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      return await _dio.post(path, data: formData);
    } catch (e) {
      rethrow;
    }
  }
}
