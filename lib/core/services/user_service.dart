import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/utils/url_utils.dart';

class UserProfile {
  final int id;
  final String name;
  final String username;
  final String? email;
  final String? city;
  final String? birthdate;
  final String gender;
  final double? height;
  final double? weight;
  final int? maxHeartRate;
  final int? restingHeartRate;
  final double? ftp;
  final double? vo2max;
  final String? photoPath;
  final String? photoUrl;
  final int? fetchedAtMs;

  UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    this.city,
    this.birthdate,
    required this.gender,
    this.height,
    this.weight,
    this.maxHeartRate,
    this.restingHeartRate,
    this.ftp,
    this.vo2max,
    this.photoPath,
    this.photoUrl,
    this.fetchedAtMs,
  });

  UserProfile withPhotoUrl(String? url) {
    return UserProfile(
      id: id,
      name: name,
      username: username,
      email: email,
      city: city,
      birthdate: birthdate,
      gender: gender,
      height: height,
      weight: weight,
      maxHeartRate: maxHeartRate,
      restingHeartRate: restingHeartRate,
      ftp: ftp,
      vo2max: vo2max,
      photoPath: photoPath,
      photoUrl: url,
      fetchedAtMs: fetchedAtMs,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      email: json['email'] as String?,
      city: json['city'] as String?,
      birthdate: json['birthdate'] as String?,
      gender: (json['gender'] as String?) ?? 'unspecified',
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      maxHeartRate: (json['max_heart_rate'] as num?)?.toInt(),
      restingHeartRate: (json['resting_heart_rate'] as num?)?.toInt(),
      ftp: (json['ftp'] as num?)?.toDouble(),
      vo2max: (json['vo2max'] as num?)?.toDouble(),
      photoPath: json['photo_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'email': email,
        'city': city,
        'birthdate': birthdate,
        'gender': gender,
        'height': height,
        'weight': weight,
        'max_heart_rate': maxHeartRate,
        'resting_heart_rate': restingHeartRate,
        'ftp': ftp,
        'vo2max': vo2max,
        'photo_path': photoPath,
        'photo_url': photoUrl,
        'fetched_at_ms': fetchedAtMs,
      };

  factory UserProfile.fromCacheJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      email: json['email'] as String?,
      city: json['city'] as String?,
      birthdate: json['birthdate'] as String?,
      gender: (json['gender'] as String?) ?? 'unspecified',
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      maxHeartRate: (json['max_heart_rate'] as num?)?.toInt(),
      restingHeartRate: (json['resting_heart_rate'] as num?)?.toInt(),
      ftp: (json['ftp'] as num?)?.toDouble(),
      vo2max: (json['vo2max'] as num?)?.toDouble(),
      photoPath: json['photo_path'] as String?,
      photoUrl: json['photo_url'] as String?,
      fetchedAtMs: json['fetched_at_ms'] as int?,
    );
  }
}

class UserService extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final AppSettingsController _settings = AppSettingsController.instance;
  final SecureStorageService _storage = SecureStorageService();

  static const _kProfileCacheKey = 'user_profile_cache_v1';
  /// [comment removed - encoding corrupted]
  static const _kCacheTtlMs = 30 * 60 * 1000;

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  UserService() {
    _loadFromCache();
  }

  /// [comment removed - encoding corrupted]
  void _loadFromCache() {
    try {
      final raw = _settings.rawPrefs?.getString(_kProfileCacheKey);
      if (raw == null || raw.isEmpty) return;
      final map = json.decode(raw) as Map<String, dynamic>;
      _profile = UserProfile.fromCacheJson(map);
      debugPrint('UserService: profile loaded from cache (${_profile?.username})');
    } catch (e) {
      debugPrint('UserService: cache read error: $e');
    }
  }

  /// [comment removed - encoding corrupted]
  Future<void> _saveToCache(UserProfile p) async {
    try {
      final prefs = _settings.rawPrefs;
      if (prefs == null) return;
      await prefs.setString(_kProfileCacheKey, json.encode(p.toJson()));
    } catch (e) {
      debugPrint('UserService: cache write error: $e');
    }
  }

  /// [comment removed - encoding corrupted]
  bool get _isCacheStale {
    final p = _profile;
    if (p?.fetchedAtMs == null) return true;
    return DateTime.now().millisecondsSinceEpoch - p!.fetchedAtMs! > _kCacheTtlMs;
  }

  /// [comment removed - encoding corrupted]
  /// [comment removed - encoding corrupted]
  Future<void> fetchProfile({bool force = false}) async {
    // [comment removed - encoding corrupted]
    if (!force && _profile != null && !_isCacheStale) {
      return;
    }
    if (_isLoading) return;
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/api/v1/profile');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rawProfile = UserProfile.fromJson(data);
        final serverUrl = await _storage.getServerUrl();

        String? fullPhotoUrl;
        if (serverUrl != null) {
          final baseUrl = UrlUtils.normalizeBaseUrl(serverUrl);
          // [comment removed - encoding corrupted]
          fullPhotoUrl = '$baseUrl/user_images/${rawProfile.id}.jpg?t=${DateTime.now().millisecondsSinceEpoch}';
        }

        final withPhoto = rawProfile.withPhotoUrl(fullPhotoUrl).withFetchedAt(DateTime.now().millisecondsSinceEpoch);
        _profile = withPhoto;

        // [comment removed - encoding corrupted]
        if (_profile!.height != null && _profile!.height! > 0) {
          await _settings.setUserHeight(_profile!.height!);
        }
        if (_profile!.weight != null && _profile!.weight! > 0) {
          await _settings.setUserWeight(_profile!.weight!);
        }
        if (_profile!.maxHeartRate != null && _profile!.maxHeartRate! > 0) {
          await _settings.setUserMaxHeartRate(_profile!.maxHeartRate!);
        }
        if (_profile!.restingHeartRate != null && _profile!.restingHeartRate! > 0) {
          await _settings.setUserRestingHeartRate(_profile!.restingHeartRate!);
        }
        if (_profile!.ftp != null && _profile!.ftp! > 0) {
          await _settings.setUserFtp(_profile!.ftp!);
        }
        if (_profile!.vo2max != null && _profile!.vo2max! > 0) {
          await _settings.setUserVo2max(_profile!.vo2max!);
        }
        if (_profile!.city != null) {
          await _settings.setUserCity(_profile!.city!);
        }
        await _settings.setUserGender(_profile!.gender);
        if (_profile!.birthdate != null && _profile!.birthdate!.isNotEmpty) {
          final parsed = DateTime.tryParse(_profile!.birthdate!);
          if (parsed != null) await _settings.setUserBirthDate(parsed);
        }

        await _saveToCache(_profile!);
        _lastError = null;
      } else {
        _lastError = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      _lastError = 'Failed to update profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// [comment removed - encoding corrupted]
  Future<void> clearCache() async {
    _profile = null;
    _lastError = null;
    try {
      final prefs = _settings.rawPrefs;
      if (prefs != null) await prefs.remove(_kProfileCacheKey);
    } catch (_) {}
    notifyListeners();
  }
}

extension on UserProfile {
  UserProfile withFetchedAt(int ms) {
    return UserProfile(
      id: id,
      name: name,
      username: username,
      email: email,
      city: city,
      birthdate: birthdate,
      gender: gender,
      height: height,
      weight: weight,
      maxHeartRate: maxHeartRate,
      restingHeartRate: restingHeartRate,
      ftp: ftp,
      vo2max: vo2max,
      photoPath: photoPath,
      photoUrl: photoUrl,
      fetchedAtMs: ms,
    );
  }
}
