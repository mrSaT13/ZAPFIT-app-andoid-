import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:zapfit/core/models/server_settings.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/constants/api_constants.dart';
import 'package:zapfit/core/utils/url_utils.dart';

/// Service for fetching and managing server settings
class ServerSettingsService {
  final SecureStorageService _storage = SecureStorageService();

  /// Fetch server settings from the server
  Future<ServerSettings> getServerSettings({String? serverUrl}) async {
    // Use provided serverUrl or get from storage
    String? url = serverUrl;
    if (url == null || url.isEmpty) {
      url = await _storage.getServerUrl();
    }

    if (url == null || url.isEmpty) {
      throw Exception('Server URL not configured');
    }
    url = UrlUtils.normalizeBaseUrl(url);

    final apiUrl = UrlUtils.buildUrl(url, ApiConstants.serverSettingsEndpoint);

    try {
      final response = await http.get(
        apiUrl,
        headers: {ApiConstants.clientTypeHeader: ApiConstants.clientTypeValue},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final settings = ServerSettings.fromJson(data);

        // Store tile server settings for later use
        if (settings.tileserverUrl != null &&
            settings.tileserverUrl!.isNotEmpty) {
          await _storage.setTileServerUrl(settings.tileserverUrl!);
        }
        if (settings.tileserverAttribution != null &&
            settings.tileserverAttribution!.isNotEmpty) {
          await _storage.setTileServerAttribution(
            settings.tileserverAttribution!,
          );
        }
        if (settings.mapBackgroundColor != null &&
            settings.mapBackgroundColor!.isNotEmpty) {
          await _storage.setMapBackgroundColor(settings.mapBackgroundColor!);
        }

        return settings;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to fetch server settings');
      }
    } catch (e) {
      throw Exception('Failed to fetch server settings: $e');
    }
  }
}
