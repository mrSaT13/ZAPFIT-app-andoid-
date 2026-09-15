import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/constants/api_constants.dart';
import 'package:zapfit/core/utils/pkce_utils.dart';
import 'package:zapfit/core/utils/url_utils.dart';
import 'package:zapfit/core/utils/trusted_http_client.dart';
import 'package:flutter/foundation.dart';
import 'package:otp/otp.dart';
import 'package:zapfit/core/services/gear_photo_sync_service.dart';

class AuthService extends ChangeNotifier {
  final SecureStorageService _storage = SecureStorageService();
  static Future<bool>? _refreshFuture;

  final _authController = StreamController<bool>.broadcast();
  Stream<bool> get authState => _authController.stream;

  Future<AuthResult> login(String username, String password, {String? serverUrl}) async {
    String? url = serverUrl ?? await _storage.getServerUrl();
    if (url == null || url.isEmpty) throw Exception('Server URL not configured');
    url = UrlUtils.normalizeBaseUrl(url);

    if (serverUrl != null) await _storage.setServerUrl(serverUrl);

    final pkce = PkceUtils.generatePkce();
    final verifier = pkce['verifier']!;
    final challenge = pkce['challenge']!;

    final apiUrl = UrlUtils.buildUrl(url, '${ApiConstants.tokenEndpoint}?code_challenge=$challenge&code_challenge_method=S256');

    try {
      final response = await trustedHttpClient.post(
        apiUrl,
        headers: {
          ApiConstants.contentTypeHeader: ApiConstants.contentTypeFormUrlEncoded,
          ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        },
        body: {'username': username, 'password': password},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['mfa_required'] == true) {
          await _storage.setUsername(username);
          await _storage.setPassword(password);
          await _storage.setPkceVerifier(verifier);

          return AuthResult(
            success: true,
            mfaRequired: true,
            username: data['username'] as String?,
            message: data['message'] as String?,
          );
        }

        final sessionId = data['session_id'] as String?;
        if (sessionId != null) {
          final result = await _exchangeSessionForTokens(url, sessionId, username, verifier);
          if (result.success) {
            await _storage.setUsername(username);
            await _storage.setPassword(password);
            _authController.add(true);
            // Sync local gear photos right after login (fire-and-forget).
            // ignore: unawaited_futures
            GearPhotoSyncService.instance.syncAll().catchError((e) => debugPrint('GearPhoto sync after login failed: $e'));
          }
          return result;
        }
        throw Exception('No session ID received');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  Future<AuthResult> verifyMfa(String username, String code) async {
    final serverUrl = await _storage.getServerUrl();
    final verifier = await _storage.getPkceVerifier();
    if (serverUrl == null || verifier == null) throw Exception('MFA Session expired');
    
    final challenge = PkceUtils.generateCodeChallenge(verifier);
    final normalizedUrl = UrlUtils.normalizeBaseUrl(serverUrl);
    final url = UrlUtils.buildUrl(normalizedUrl, 
        '${ApiConstants.mfaVerifyEndpoint}?code_challenge=$challenge&code_challenge_method=S256');

    try {
      final response = await trustedHttpClient.post(
        url,
        headers: {
          ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson,
          ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        },
        body: json.encode({'username': username, 'mfa_code': code}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sessionId = data['session_id'] as String?;
        if (sessionId != null) {
          final result = await _exchangeSessionForTokens(normalizedUrl, sessionId, username, verifier);
          await _storage.deletePkceVerifier();
          if (result.success) {
            _authController.add(true);
            // ignore: unawaited_futures
            GearPhotoSyncService.instance.syncAll().catchError((e) => debugPrint('GearPhoto sync after MFA failed: $e'));
          }
          return result;
        }
      }
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'MFA verification failed');
    } catch (e) {
      throw Exception('MFA error: $e');
    }
  }

  Future<AuthResult> _exchangeSessionForTokens(String serverUrl, String sessionId, String username, String verifier) async {
    final url = UrlUtils.buildUrl(serverUrl, '${ApiConstants.idpSessionTokenExchangeEndpoint}/$sessionId/tokens');

    try {
      final response = await trustedHttpClient.post(
        url,
        headers: {
          ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson,
          ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
        },
        body: json.encode({'code_verifier': verifier}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        await _storage.clearAuthTokens();
        await _storage.saveAuthTokens(
          accessToken: data['access_token'] as String?,
          refreshToken: data['refresh_token'] as String?,
          sessionId: data['session_id'] as String?,
          csrfToken: response.headers['x-csrf-token'] ?? response.headers['X-CSRF-Token'],
        );
        await _storage.setUsername(username);

        return AuthResult(
          success: true,
          accessToken: data['access_token'] as String?,
          refreshToken: data['refresh_token'] as String?,
          sessionId: data['session_id'] as String?,
        );
      }
      throw Exception('Token exchange failed');
    } catch (e) {
      throw Exception('Token exchange error: $e');
    }
  }

  Future<bool> refreshToken() async {
    if (_refreshFuture != null) return _refreshFuture!;
    _refreshFuture = _performRefresh();
    try { 
      final result = await _refreshFuture!; 
      if (!result) {
        _authController.add(false);
      }
      return result;
    } finally { 
      _refreshFuture = null; 
    }
  }

  Future<bool> _performRefresh() async {
    final serverUrl = await _storage.getServerUrl();
    final refreshToken = await _storage.getRefreshToken();

    if (serverUrl == null || refreshToken == null) return await _tryBackgroundLogin();

    try {
      debugPrint('Auth: Attempting to refresh token using refresh_token...');
      final response = await trustedHttpClient.post(
        UrlUtils.buildUrl(serverUrl, ApiConstants.refreshEndpoint),
        headers: {
          ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue,
          ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson,
          'Cookie': 'endurain_refresh_token=$refreshToken',
        },
        body: json.encode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['access_token'] != null) {
          debugPrint('Auth: Refresh success.');
          await _storage.setAccessToken(data['access_token'] as String);
          if (data['refresh_token'] != null) {
            await _storage.setRefreshToken(data['refresh_token'] as String);
          }
          return true;
        }
      } 
      debugPrint('Auth: Refresh failed (${response.statusCode}). Trying background login...');
      return await _tryBackgroundLogin();
    } catch (e) {
      debugPrint('Auth: Refresh error: $e. Trying background login...');
      return await _tryBackgroundLogin();
    }
  }

  Future<bool> _tryBackgroundLogin() async {
    final username = await _storage.getUsername();
    final password = await _storage.getPassword();
    final mfaSecret = await _storage.getMfaSecret();

    if (username != null && password != null) {
      try {
        debugPrint('Auth: Attempting background login for $username...');
        final result = await login(username, password);
        
        if (result.success) {
          if (!result.mfaRequired) {
            debugPrint('Auth: Background login success (no MFA).');
            return true;
          } else if (mfaSecret != null && mfaSecret.isNotEmpty) {
            debugPrint('Auth: Background login requires MFA. Generating code from secret...');
            try {
              final code = OTP.generateTOTPCodeString(
                mfaSecret, 
                DateTime.now().millisecondsSinceEpoch,
                interval: 30,
                length: 6,
                algorithm: Algorithm.SHA1,
                isGoogle: true,
              );
              debugPrint('Auth: Generated MFA code. Verifying...');
              final mfaResult = await verifyMfa(username, code);
              if (mfaResult.success) {
                debugPrint('Auth: Background login success with AUTO MFA.');
                return true;
              }
            } catch (otpError) {
              debugPrint('Auth: OTP generation/verification error: $otpError');
            }
          }
        }
        debugPrint('Auth: Background login failed (MFA required but no secret or verification failed).');
      } catch (e) {
        debugPrint('Auth: Background login error: $e');
      }
    }
    return false;
  }

  Future<void> logout() async {
    await _storage.clearAuthTokens();
    _authController.add(false);
  }

  Future<bool> isAuthenticated() => _storage.isAuthenticated();

  @override
  void dispose() {
    _authController.close();
    super.dispose();
  }
}

class AuthResult {
  final bool success;
  final bool mfaRequired;
  final String? username;
  final String? message;
  final String? accessToken;
  final String? refreshToken;
  final String? sessionId;

  AuthResult({required this.success, this.mfaRequired = false, this.username, this.message, this.accessToken, this.refreshToken, this.sessionId});
}
