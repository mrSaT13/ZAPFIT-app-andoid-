import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:flutter/foundation.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}

class UploadException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic responseBody;
  UploadException(this.message, {this.statusCode, this.responseBody});
  @override
  String toString() => 'UploadException: $message (Code: $statusCode, Body: $responseBody)';
}

class ZapfitAuthManager {
  final SecureStorageService _storage = SecureStorageService();
  final String baseUrl;

  ZapfitAuthManager({required this.baseUrl});

  Future<Map<String, String>> getValidAuthHeaders() async {
    final token = await _storage.getAccessToken();
    final csrf = await _storage.getCsrfToken();
    final sessionId = await _storage.getSessionId();

    if (token != null) {
      return _buildHeaders(token, csrf, sessionId);
    }

    final username = await _storage.getUsername();
    final password = await _storage.getPassword();

    if (username != null && password != null) {
      try {
        final newToken = await login(username, password);
        final newCsrf = await _storage.getCsrfToken();
        final newSid = await _storage.getSessionId();
        return _buildHeaders(newToken, newCsrf, newSid);
      } catch (e) {
        debugPrint('Fallback login failed: $e');
      }
    }

    final refresh = await _storage.getRefreshToken();
    if (refresh != null) {
      try {
        final newToken = await refreshToken(refresh);
        final newCsrf = await _storage.getCsrfToken();
        final newSid = await _storage.getSessionId();
        return _buildHeaders(newToken, newCsrf, newSid);
      } catch (e) {
        debugPrint('Fallback refresh failed: $e');
      }
    }

    throw AuthException("Требуется авторизация");
  }

  Map<String, String> _buildHeaders(String token, String? csrf, String? sessionId) {
    return {
      'Authorization': 'Bearer $token',
      if (csrf != null) 'X-CSRF-Token': csrf,
      if (sessionId != null) 'X-Session-ID': sessionId,
    };
  }

  Future<String> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String?;
      if (accessToken == null) throw AuthException("Сервер не вернул токен");

      await _storage.saveAuthTokens(
        accessToken: accessToken,
        refreshToken: data['refresh_token'] as String?,
        sessionId: data['session_id'] as String?,
        csrfToken: response.headers['x-csrf-token'],
      );
      return accessToken;
    }
    throw AuthException("Ошибка входа: ${response.statusCode}");
  }

  Future<String> refreshToken(String token) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/refresh');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh_token': token}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String?;
      if (accessToken == null) throw AuthException("Ошибка обновления");

      await _storage.saveAuthTokens(
        accessToken: accessToken,
        refreshToken: (data['refresh_token'] as String?) ?? token,
      );
      return accessToken;
    }
    throw AuthException("Ошибка обновления: ${response.statusCode}");
  }
}

class ZapfitUploader {
  final String baseUrl;
  late final ZapfitAuthManager _authManager;

  ZapfitUploader({required this.baseUrl}) {
    _authManager = ZapfitAuthManager(baseUrl: baseUrl);
  }

  Future<Map<String, dynamic>> uploadActivity({
    required File file,
    String? name,
    String? type,
    String? privacy,
    String? description,
    void Function(int sent, int total)? onProgress,
  }) async {
    final authHeaders = await _authManager.getValidAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/v1/activities/upload');

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(authHeaders);

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: file.path.split(Platform.pathSeparator).last,
    ));

    if (name != null) request.fields['name'] = name;
    if (type != null) request.fields['type'] = type;
    if (privacy != null) request.fields['privacy'] = privacy;
    if (description != null) request.fields['description'] = description;

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      final body = response.body.isNotEmpty ? json.decode(response.body) : null;
      throw UploadException(
        (body is Map ? body['message'] as String? : null) ?? 'Ошибка загрузки',
        statusCode: response.statusCode,
        responseBody: body,
      );
    } catch (e) {
      if (e is UploadException) rethrow;
      throw UploadException('Ошибка соединения: $e');
    }
  }

  Future<bool> testConnection() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/status');
      final response = await http.get(uri);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }
}

