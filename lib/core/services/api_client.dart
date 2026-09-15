import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/services/auth_service.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/constants/api_constants.dart';
import 'package:zapfit/core/utils/url_utils.dart';
import 'package:zapfit/core/utils/trusted_http_client.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class ApiClient {
  final SecureStorageService _storage = SecureStorageService();
  final AppSettingsController _settings = AppSettingsController.instance;

  AuthService get _authService => serviceLocator<AuthService>();

  static const Duration _defaultTimeout = Duration(seconds: 30);
  
  static final Map<String, Uint8List> _imageCache = {};

  Future<http.Response> get(String endpoint) => _makeRequest('GET', endpoint);
  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) => _makeRequest('POST', endpoint, body: body);
  Future<http.Response> put(String endpoint, {Map<String, dynamic>? body}) => _makeRequest('PUT', endpoint, body: body);
  Future<http.Response> patch(String endpoint, {Map<String, dynamic>? body}) => _makeRequest('PATCH', endpoint, body: body);
  Future<http.Response> delete(String endpoint) => _makeRequest('DELETE', endpoint);

  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) throw Exception('Server URL not configured');

    final apiKey = _settings.apiKey.trim();
    Uri url = UrlUtils.buildUrl(serverUrl, endpoint);
    
    if (apiKey.isNotEmpty) {
      final queryParams = Map<String, String>.from(url.queryParameters);
      queryParams['api_key'] = apiKey;
      url = url.replace(queryParameters: queryParams);
    }

    var headers = await _getHeaders();
    http.Response response = await _executeRequest(method, url, headers, body: body);

    if (response.statusCode == 401) {
      debugPrint('ApiClient: 401 error on $endpoint. Attempting token refresh...');
      final refreshed = await _authService.refreshToken();
      if (refreshed) {
        debugPrint('ApiClient: Token refreshed. RETRYING request with NEW headers...');
        headers = await _getHeaders(); // IMPORTANT: Get headers with the fresh token
        response = await _executeRequest(method, url, headers, body: body);
      }
    }

    return response;
  }

  Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{
      ApiConstants.clientTypeHeader: kIsWeb ? 'web' : 'mobile',
      ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson,
    };

    final accessToken = await _storage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      headers[ApiConstants.authorizationHeader] = 'Bearer $accessToken';
    }

    final apiKey = _settings.apiKey.trim();
    if (apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
      final apiPassword = _settings.apiPassword.trim();
      if (apiPassword.isNotEmpty) {
        headers['X-API-Password'] = apiPassword;
      }
    }

    final csrf = await _storage.getCsrfToken();
    if (csrf != null && csrf.isNotEmpty) headers['X-CSRF-Token'] = csrf;

    return headers;
  }

  Future<http.Response> _executeRequest(String method, Uri url, Map<String, String> headers, {Map<String, dynamic>? body}) async {
    try {
      final bodyStr = body != null ? json.encode(body) : null;
      Future<http.Response> request;
      final client = trustedHttpClient;

      switch (method) {
        case 'GET': request = client.get(url, headers: headers); break;
        case 'POST': request = client.post(url, headers: headers, body: bodyStr); break;
        case 'PUT': request = client.put(url, headers: headers, body: bodyStr); break;
        case 'PATCH': request = client.patch(url, headers: headers, body: bodyStr); break;
        case 'DELETE': request = client.delete(url, headers: headers); break;
        default: throw Exception('Unsupported method: $method');
      }

      return await request.timeout(_defaultTimeout);
    } on TimeoutException {
      throw Exception('Connection timeout');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Uint8List?> getImageBytes(String imageUrl) async {
    if (imageUrl.isEmpty) return null;
    if (_imageCache.containsKey(imageUrl)) return _imageCache[imageUrl];

    try {
      final serverUrl = await _storage.getServerUrl();
      if (serverUrl == null) return null;
      final baseUrl = UrlUtils.normalizeBaseUrl(serverUrl);

      // Build a deduplicated, ordered list of candidate URLs.
      // 1. If imageUrl is already absolute, use it directly.
      // 2. If it starts with "/" treat it as server-relative.
      // 3. Otherwise try the common Endurain asset folders under the base.
      final urlsToTry = _buildImageCandidates(imageUrl, baseUrl);

      for (final url in urlsToTry) {
        try {
          var headers = await _getHeaders();
          var response = await trustedHttpClient.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));

          if (response.statusCode == 401) {
            if (await _authService.refreshToken()) {
              headers = await _getHeaders();
              response = await trustedHttpClient.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
            }
          }

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            _imageCache[imageUrl] = response.bodyBytes;
            return response.bodyBytes;
          }
        } catch (e) {
          debugPrint('ApiClient: image attempt failed for $url: $e');
        }
      }
    } catch (e) {
      debugPrint('ApiClient: Image error: $e');
    }
    return null;
  }

  /// Build the list of URLs to try when loading an image.
  ///
  /// Handles three common Endurain cases:
  /// [comment removed - encoding corrupted]
  /// [comment removed - encoding corrupted]
  /// [comment removed - encoding corrupted]
  static List<String> _buildImageCandidates(String imageUrl, String baseUrl) {
    final candidates = <String>[];

    // [comment removed - encoding corrupted]
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      candidates.add(imageUrl);
      return candidates;
    }

    // Normalize to a leading slash.
    final path = imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';

    // If the path looks like an absolute filesystem path (e.g. /app/backend/...),
    // extract just the filename and try the API endpoints.
    if (path.contains('/activity_thumbnails/') || path.contains('/activity_media/') || path.contains('/user_images/') || path.contains('/gear_images/')) {
      final filename = path.split('/').last;
      if (filename.isNotEmpty) {
        candidates.add('$baseUrl/gear_images/$filename');
        candidates.add('$baseUrl/api/v1/activity_thumbnails/$filename');
        candidates.add('$baseUrl/api/v1/activity_media/$filename');
        candidates.add('$baseUrl/activity_thumbnails/$filename');
        candidates.add('$baseUrl/activity_media/$filename');
      }
    }

    // [comment removed - encoding corrupted]
    const knownFolders = [
      'user_images',
      'user_photos',
      'activity_media',
      'activity_thumbnails',
      'activity_photos',
      'gear_images',
      'images',
    ];
    final hasKnownFolder = knownFolders.any((f) => path.contains('/$f/') || path.startsWith('/$f'));

    if (hasKnownFolder) {
      // Extract just the filename for API endpoint construction
      final filename = path.split('/').last;
      if (filename.isNotEmpty && !candidates.any((c) => c.endsWith('/$filename'))) {
        candidates.add('$baseUrl$path');
      }
    } else {
      // Try known static mounts first
      candidates.add('$baseUrl/user_images$path');
      candidates.add('$baseUrl/activity_thumbnails$path');
      candidates.add('$baseUrl/activity_media$path');
      candidates.add('$baseUrl/gear_images$path');
      candidates.add('$baseUrl$path');
    }

    return candidates;
  }

  Future<http.StreamedResponse> uploadFile(String endpoint, String filePath, String fieldName) async {
    final serverUrl = await _storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) throw Exception('Server URL missing');
    Uri url = UrlUtils.buildUrl(serverUrl, endpoint);
    
    final apiKey = _settings.apiKey.trim();
    if (apiKey.isNotEmpty) {
      final qp = Map<String, String>.from(url.queryParameters);
      qp['api_key'] = apiKey;
      url = url.replace(queryParameters: qp);
    }

    Future<http.MultipartRequest> createRequest() async {
      final request = http.MultipartRequest('POST', url);
      final headers = await _getHeaders();
      headers.remove(ApiConstants.contentTypeHeader);
      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
      return request;
    }

    var response = await (await createRequest()).send().timeout(const Duration(seconds: 60));

    if (response.statusCode == 401) {
      debugPrint('ApiClient: 401 on upload. Refreshing token...');
      if (await _authService.refreshToken()) {
        debugPrint('ApiClient: Retrying file upload after refresh...');
        response = await (await createRequest()).send().timeout(const Duration(seconds: 60));
      }
    }
    return response;
  }
}
