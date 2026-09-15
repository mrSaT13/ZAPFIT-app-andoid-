import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/user_service.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/utils/url_utils.dart';

class FeedService extends ChangeNotifier {
  final ApiClient _apiClient = serviceLocator<ApiClient>();
  final LocalActivityRepository _localRepo = LocalActivityRepository.instance;
  final UserService _userService = serviceLocator<UserService>();

  // Profile cache: userId -> {name, photo}
  static final Map<int, Map<String, String>> _profileCache = {};

  List<ActivityRecord> _myFeed = [];
  List<ActivityRecord> _friendsFeed = [];

  List<ActivityRecord> get myFeed => _myFeed;
  List<ActivityRecord> get friendsFeed => _friendsFeed;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  bool _myFeedInFlight = false;
  bool _friendsFeedInFlight = false;

  final Map<String, ActivityRecord> _myFeedMerged = {};
  final Map<String, ActivityRecord> _friendsFeedMerged = {};

  // Pagination state
  int _myFeedPage = 1;
  int _friendsFeedPage = 1;
  static const int _pageSize = 30;
  bool _myFeedHasMore = true;
  bool _friendsFeedHasMore = true;
  bool _isLoadingMoreMyFeed = false;
  bool _isLoadingMoreFriends = false;

  bool get myFeedHasMore => _myFeedHasMore;
  bool get friendsFeedHasMore => _friendsFeedHasMore;
  bool get isLoadingMoreMyFeed => _isLoadingMoreMyFeed;
  bool get isLoadingMoreFriends => _isLoadingMoreFriends;

  Future<void> fetchMyFeed() async {
    if (_myFeedInFlight) return;
    _myFeedInFlight = true;
    _myFeedPage = 1;
    _myFeedHasMore = true;

    if (_myFeed.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final localActivities = await _localRepo.getActivities();
      _applyLocalToMyFeed(localActivities);
    } catch (e) {
      debugPrint('FeedService: local myFeed failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    await _localRepo.withSuppressedChanges(() => _fetchMyFeedFromServer(page: 1));
    _myFeedInFlight = false;
  }

  Future<void> loadMoreMyFeed() async {
    if (_isLoadingMoreMyFeed || !_myFeedHasMore || _myFeedInFlight) return;
    _isLoadingMoreMyFeed = true;
    notifyListeners();
    try {
      await _localRepo.withSuppressedChanges(() => _fetchMyFeedFromServer(page: _myFeedPage));
    } finally {
      _isLoadingMoreMyFeed = false;
      notifyListeners();
    }
  }

  /// [comment removed - encoding corrupted]
  void _applyLocalToMyFeed(List<ActivityRecord> localActivities) {
    final profileName = _userService.profile?.name;
    final profilePhoto = _userService.profile?.photoUrl;

    for (var act in localActivities) {
      final enriched = act.copyWith(
        userName: act.userName ?? profileName,
        userPhotoUrl: act.userPhotoUrl ?? profilePhoto,
      );
      if (enriched.serverId != null) {
        final key = 's_${enriched.serverId}';
        final existing = _myFeedMerged[key];
        // Update if: no entry yet, OR local version has pending edits (user edited)
        if (existing == null || enriched.uploadStatus == UploadStatus.pending) {
          _myFeedMerged[key] = enriched;
        }
      } else {
        _myFeedMerged['l_${enriched.id ?? enriched.hashCode}'] = enriched;
      }
    }
    _emitMyFeed();
  }

  Future<void> _fetchMyFeedFromServer({required int page}) async {
    try {
      if (_userService.profile == null) {
        await _userService.fetchProfile();
      }
      final userId = _userService.profile?.id;
      if (userId == null) return;

      debugPrint('FeedService: Fetching server activities for user $userId page $page');
      final response = await _apiClient.get('/api/v1/activities/user/$userId/page_number/$page/num_records/$_pageSize');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final serverData = (decoded as List<dynamic>?) ?? <dynamic>[];

        final profileName = _userService.profile?.name;
        final profilePhoto = _userService.profile?.photoUrl;

        if (page == 1) {
          _myFeedMerged.clear();
          final localActs = await _localRepo.getActivities();
          for (var act in localActs) {
            if (act.uploadStatus == UploadStatus.pending || act.uploadStatus == UploadStatus.failed) {
              final key = act.serverId != null ? 's_${act.serverId}' : 'l_${act.id ?? act.hashCode}';
              final enriched = act.copyWith(
                userName: act.userName ?? profileName,
                userPhotoUrl: act.userPhotoUrl ?? profilePhoto,
              );
              _myFeedMerged[key] = enriched;
            }
          }
        }

        for (var item in serverData) {
          try {
            var act = ActivityRecord.fromServerJson(item as Map<String, dynamic>);
            if (act.userName == null || act.userPhotoUrl == null) {
              act = act.copyWith(
                userName: act.userName ?? profileName,
                userPhotoUrl: act.userPhotoUrl ?? profilePhoto,
              );
            }
            if (act.serverId != null) {
              // Check if local version has pending edits — don't overwrite
              final existing = await _localRepo.getActivityByServerId(act.serverId!);
              if (existing != null && existing.uploadStatus == UploadStatus.pending) {
                // Keep the locally-edited version in the feed
                _myFeedMerged['s_${act.serverId}'] = existing;
              } else {
                _myFeedMerged['s_${act.serverId}'] = act;
              }

              // Кэшируем/обновляем серверную активность локально
              try {
                if (existing != null) {
                  // Only update from server if local is not pending
                  if (existing.uploadStatus != UploadStatus.pending) {
                    await _localRepo.updateActivity(existing.copyWith(
                      title: act.title,
                      kind: act.kind,
                      distanceMeters: act.distanceMeters,
                      durationSeconds: act.durationSeconds,
                      thumbnailUrl: act.thumbnailUrl,
                      avgHeartRate: act.avgHeartRate,
                      maxHeartRate: act.maxHeartRate,
                      uploadStatus: UploadStatus.uploaded,
                    ));
                  }
                } else {
                  await _localRepo.createActivity(act.copyWith(
                    uploadStatus: UploadStatus.uploaded,
                  ));
                }
              } catch (_) {}
            }
          } catch (e) {
            debugPrint('FeedService: skip bad server item: $e');
          }
        }
        _lastError = null;
        if (serverData.length < _pageSize) {
          _myFeedHasMore = false;
        } else {
          _myFeedPage++;
        }
      } else if (response.statusCode >= 500) {
        _lastError = 'Сервер временно недоступен (${response.statusCode})';
      }
    } catch (e) {
      debugPrint('Error fetching my feed: $e');
      _lastError = 'Нет сети, показаны локальные активности';
    } finally {
      _emitMyFeed();
    }
  }

  void _emitMyFeed() {
    final list = _myFeedMerged.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    _myFeed = list;
    notifyListeners();
  }

  Future<void> fetchFriendsFeed() async {
    if (_friendsFeedInFlight) return;
    _friendsFeedInFlight = true;
    _friendsFeedPage = 1;
    _friendsFeedHasMore = true;

    try {
      if (_userService.profile == null) await _userService.fetchProfile();
      final userId = _userService.profile?.id;
      if (userId == null) {
        _friendsFeedInFlight = false;
        return;
      }

      final response = await _apiClient.get('/api/v1/activities/user/$userId/followed/page_number/$_friendsFeedPage/num_records/$_pageSize');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = (decoded as List<dynamic>?) ?? <dynamic>[];
        _friendsFeedMerged.clear();
        
        final uniqueUserIds = <int>{};
        for (var item in data) {
          try {
            final act = ActivityRecord.fromServerJson(item as Map<String, dynamic>);
            if (act.userId != null) uniqueUserIds.add(act.userId!);
            if (act.serverId != null) {
              _friendsFeedMerged['s_${act.serverId}'] = act;
            }
          } catch (e) {
            debugPrint('FeedService: skip bad friend item: $e');
          }
        }
        
        final uncachedUserIds = uniqueUserIds.where((uid) => !_profileCache.containsKey(uid)).toList();
        
        if (uncachedUserIds.isNotEmpty) {
          await _fetchProfilesBatch(uncachedUserIds);
        }
        
        _applyProfilesToFriendsFeed(uniqueUserIds);

        _friendsFeed = _friendsFeedMerged.values.toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        _lastError = null;
        if (data.length < _pageSize) {
          _friendsFeedHasMore = false;
        } else {
          _friendsFeedPage++;
        }
      } else if (response.statusCode >= 500) {
        _lastError = 'Сервер временно недоступен (${response.statusCode})';
      }
    } catch (e) {
      debugPrint('Error fetching friends feed: $e');
      _lastError = 'Не удалось загрузить ленту друзей';
    } finally {
      notifyListeners();
      _friendsFeedInFlight = false;
    }
  }

  Future<void> loadMoreFriendsFeed() async {
    if (_isLoadingMoreFriends || !_friendsFeedHasMore || _friendsFeedInFlight) return;
    _isLoadingMoreFriends = true;
    notifyListeners();

    try {
      if (_userService.profile == null) await _userService.fetchProfile();
      final userId = _userService.profile?.id;
      if (userId == null) return;

      final response = await _apiClient.get('/api/v1/activities/user/$userId/followed/page_number/$_friendsFeedPage/num_records/$_pageSize');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = (decoded as List<dynamic>?) ?? <dynamic>[];
        for (var item in data) {
          try {
            final act = ActivityRecord.fromServerJson(item as Map<String, dynamic>);
            if (act.serverId != null) {
              _friendsFeedMerged['s_${act.serverId}'] = act;
            }
          } catch (_) {}
        }
        if (data.length < _pageSize) {
          _friendsFeedHasMore = false;
        } else {
          _friendsFeedPage++;
        }
        _friendsFeed = _friendsFeedMerged.values.toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      }
    } catch (e) {
      debugPrint('loadMoreFriendsFeed error: $e');
    } finally {
      _isLoadingMoreFriends = false;
      notifyListeners();
    }
  }

  /// Fetch profiles in parallel batches of [batchSize] to avoid ANR.
  Future<void> _fetchProfilesBatch(List<int> userIds, {int batchSize = 5}) async {
    final serverUrl = await SecureStorageService().getServerUrl();
    final baseUrl = serverUrl != null ? UrlUtils.normalizeBaseUrl(serverUrl) : '';

    for (var i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.sublist(i, (i + batchSize).clamp(0, userIds.length));
      final futures = batch.map((uid) async {
        try {
          final res = await _apiClient.get('/api/v1/users/id/$uid');
          if (res.statusCode == 200) {
            final data = json.decode(res.body) as Map<String, dynamic>;
            final name = data['name']?.toString() ?? data['username']?.toString() ?? '';
            var photo = data['photo_path']?.toString() ?? '';
            if (photo.isNotEmpty && !photo.startsWith('http')) {
              final lastSlash = photo.lastIndexOf('/');
              final fileName = lastSlash >= 0 ? photo.substring(lastSlash + 1) : photo;
              photo = '$baseUrl/user_images/$fileName';
            }
            _profileCache[uid] = {
              'name': name,
              'photo': photo,
            };
          }
        } catch (_) {}
      });
      await Future.wait(futures);
    }
  }

  void _applyProfilesToFriendsFeed(Set<int> userIds) {
    for (final key in _friendsFeedMerged.keys.toList()) {
      final act = _friendsFeedMerged[key]!;
      if (act.userId != null && _profileCache.containsKey(act.userId)) {
        final profile = _profileCache[act.userId]!;
        final name = profile['name'] ?? '';
        final photo = profile['photo'] ?? '';
        _friendsFeedMerged[key] = act.copyWith(
          userName: act.userName ?? (name.isNotEmpty ? name : null),
          userPhotoUrl: act.userPhotoUrl ?? (photo.isNotEmpty ? photo : null),
        );
      }
    }
  }

  void clearCache() {
    _myFeed.clear();
    _friendsFeed.clear();
    _myFeedMerged.clear();
    _friendsFeedMerged.clear();
    _myFeedPage = 1;
    _friendsFeedPage = 1;
    _myFeedHasMore = true;
    _friendsFeedHasMore = true;
    _lastError = null;
    notifyListeners();
  }
}
