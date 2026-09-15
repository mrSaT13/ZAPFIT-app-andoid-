import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:zapfit/core/models/identity_provider.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/constants/api_constants.dart';
import 'package:zapfit/core/utils/pkce_utils.dart';
import 'package:zapfit/core/utils/url_utils.dart';
import 'package:zapfit/core/services/auth_service.dart';

class SsoService {
  final SecureStorageService _storage = SecureStorageService();
  
  // [comment removed - encoding corrupted]
  static const String _ssoVerifierKey = 'temp_sso_verifier';

  Future<List<IdentityProvider>> getEnabledProviders({String? serverUrl}) async {
    String? url = serverUrl ?? await _storage.getServerUrl();
    if (url == null || url.isEmpty) throw Exception('Server URL not configured');
    
    url = UrlUtils.normalizeBaseUrl(url);
    final apiUrl = UrlUtils.buildUrl(url, ApiConstants.idpListEndpoint);

    try {
      final response = await http.get(
        apiUrl,
        headers: {ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final providers = ((data is List) ? data : ((data as Map)['providers'] ?? <dynamic>[])) as List<dynamic>;
        return providers.map((p) => IdentityProvider.fromJson(p as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to fetch providers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch identity providers: $e');
    }
  }

  Future<String> initiateOAuth(String idpSlug, {String? serverUrl}) async {
    String? url = serverUrl ?? await _storage.getServerUrl();
    if (url == null || url.isEmpty) throw Exception('Server URL not configured');
    
    final pkce = PkceUtils.generatePkce();
    // [comment removed - encoding corrupted]
    await _storage.write(key: _ssoVerifierKey, value: pkce['verifier']!);

    final oauthUrl = UrlUtils.buildUrl(UrlUtils.normalizeBaseUrl(url), '${ApiConstants.idpLoginEndpoint}/$idpSlug')
        .replace(queryParameters: {
          'code_challenge': pkce['challenge']!,
          'code_challenge_method': 'S256',
          'redirect': '/dashboard',
        });

    return oauthUrl.toString();
  }

  Future<AuthResult> exchangeSessionForTokens(String sessionId) async {
    final serverUrl = await _storage.getServerUrl();
    final verifier = await _storage.read(key: _ssoVerifierKey);

    if (serverUrl == null || verifier == null) {
      throw Exception('SSO session expired or invalid. Please try again.');
    }

    final url = UrlUtils.buildUrl(serverUrl, '${ApiConstants.idpSessionTokenExchangeEndpoint}/$sessionId/tokens');

    try {
      final response = await http.post(
        url,
        headers: {
          ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson,
          ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        },
        body: json.encode({'code_verifier': verifier}),
      ).timeout(const Duration(seconds: 15));

      await _storage.delete(key: _ssoVerifierKey);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final returnedSessionId = data['session_id'] as String?;

        if (accessToken != null) await _storage.setAccessToken(accessToken);
        if (refreshToken != null) await _storage.setRefreshToken(refreshToken);
        if (returnedSessionId != null) await _storage.setSessionId(returnedSessionId);

        return AuthResult(success: true, accessToken: accessToken, refreshToken: refreshToken, sessionId: returnedSessionId);
      } else {
        throw Exception('Token exchange failed');
      }
    } catch (e) {
      await _storage.delete(key: _ssoVerifierKey);
      throw Exception('SSO error: $e');
    }
  }
}
