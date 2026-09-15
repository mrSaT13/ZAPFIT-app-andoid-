import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zapfit/core/utils/url_utils.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _serverUrlKey = 'server_url';
  static const _usernameKey = 'username';
  static const _passwordKey = 'password';
  // [comment removed - encoding corrupted]
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _sessionIdKey = 'session_id';
  static const _csrfTokenKey = 'csrf_token';
  static const _pkceVerifierKey = 'pkce_verifier';
  static const _tileServerUrlKey = 'tile_server_url';
  static const _tileServerAttributionKey = 'tile_server_attribution';
  static const _mapBackgroundColorKey = 'map_background_color';

  Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      return null;
    }
  }

  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveAuthTokens({
    String? accessToken,
    String? refreshToken,
    String? sessionId,
    String? csrfToken,
  }) async {
    if (accessToken != null) await setAccessToken(accessToken);
    if (refreshToken != null) await setRefreshToken(refreshToken);
    if (sessionId != null) await setSessionId(sessionId);
    if (csrfToken != null) await setCsrfToken(csrfToken);
  }

  Future<void> clearAuthTokens() async {
    await deleteAccessToken();
    await deleteRefreshToken();
    await deleteSessionId();
    await deleteCsrfToken();
    await deletePkceVerifier();
  }

  Future<String?> getPkceVerifier() => read(key: _pkceVerifierKey);
  Future<void> setPkceVerifier(String v) => write(key: _pkceVerifierKey, value: v);
  Future<void> deletePkceVerifier() => delete(key: _pkceVerifierKey);

  Future<String?> getServerUrl() => read(key: _serverUrlKey);
  Future<void> setServerUrl(String url) => write(key: _serverUrlKey, value: UrlUtils.normalizeBaseUrl(url));
  
  Future<String?> getUsername() => read(key: _usernameKey);
  Future<void> setUsername(String u) => write(key: _usernameKey, value: u);
  
  Future<String?> getPassword() => read(key: _passwordKey);
  Future<void> setPassword(String p) => write(key: _passwordKey, value: p);

  // [comment removed - encoding corrupted]
  // [comment removed - encoding corrupted]

  Future<String?> getAccessToken() => read(key: _accessTokenKey);
  Future<void> setAccessToken(String t) => write(key: _accessTokenKey, value: t);
  Future<void> deleteAccessToken() => delete(key: _accessTokenKey);

  Future<String?> getRefreshToken() => read(key: _refreshTokenKey);
  Future<void> setRefreshToken(String t) => write(key: _refreshTokenKey, value: t);
  Future<void> deleteRefreshToken() => delete(key: _refreshTokenKey);

  Future<String?> getSessionId() => read(key: _sessionIdKey);
  Future<void> setSessionId(String s) => write(key: _sessionIdKey, value: s);
  Future<void> deleteSessionId() => delete(key: _sessionIdKey);

  Future<String?> getCsrfToken() => read(key: _csrfTokenKey);
  Future<void> setCsrfToken(String t) => write(key: _csrfTokenKey, value: t);
  Future<void> deleteCsrfToken() => delete(key: _csrfTokenKey);

  Future<String?> getTileServerUrl() => read(key: _tileServerUrlKey);
  Future<void> setTileServerUrl(String url) => write(key: _tileServerUrlKey, value: url);

  Future<String?> getTileServerAttribution() => read(key: _tileServerAttributionKey);
  Future<void> setTileServerAttribution(String attr) => write(key: _tileServerAttributionKey, value: attr);

  Future<String?> getMapBackgroundColor() => read(key: _mapBackgroundColorKey);
  Future<void> setMapBackgroundColor(String color) => write(key: _mapBackgroundColorKey, value: color);

  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static const _mfaSecretKey = 'mfa_secret';
  static const _ollamaApiKey = 'ollama_api_key';

  Future<String?> getMfaSecret() => read(key: _mfaSecretKey);
  Future<void> setMfaSecret(String v) => write(key: _mfaSecretKey, value: v);
  Future<void> deleteMfaSecret() => delete(key: _mfaSecretKey);

  Future<String?> getOllamaApiKey() => read(key: _ollamaApiKey);
  Future<void> setOllamaApiKey(String v) => write(key: _ollamaApiKey, value: v);
  Future<void> deleteOllamaApiKey() => delete(key: _ollamaApiKey);
}
