import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:endurain/core/di/service_locator.dart';
import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/services/user_service.dart';

/// One comment on an activity (`/api/v1/activities_comments` DTO).
class ActivityCommentRecord {
  final int id;
  final int activityId;
  final int userId;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ActivityCommentRecord({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.updatedAt,
  });

  factory ActivityCommentRecord.fromJson(Map<String, dynamic> json) =>
      ActivityCommentRecord(
        id: (json['id'] as num).toInt(),
        activityId: (json['activity_id'] as num).toInt(),
        userId: (json['user_id'] as num).toInt(),
        content: json['content'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.tryParse(json['updated_at'] as String),
      );
}

/// Full CRUD access to the server's activity comments.
///
/// Comments live on the server only (no offline queue for v1): an unposted
/// comment stays in the TextField so the user can retry after reconnecting —
/// activities themselves already carry the offline story.
class ActivityCommentsService {
  ActivityCommentsService._();
  static final ActivityCommentsService instance = ActivityCommentsService._();

  final ApiClient _apiClient = serviceLocator<ApiClient>();
  final UserService _userService = serviceLocator<UserService>();
  final SecureStorageService _storage = SecureStorageService();

  static const String _basePath = '/api/v1/activities_comments';
  static const int _contentMax = 2000;

  /// userId → {name, photo} cache (shared pattern with FeedService).
  static final Map<int, Map<String, String>> _profileCache = {};

  List<ActivityCommentRecord> _parseList(String body) {
    final decoded = json.decode(body) as List<dynamic>;
    return decoded
        .map((e) => ActivityCommentRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// All comments of an activity, ordered by creation time (server default).
  /// Empty list on any failure — the section renders as an empty state.
  Future<List<ActivityCommentRecord>> fetchComments(int activityId) async {
    try {
      final response = await _apiClient.get('$_basePath/activity_id/$activityId');
      if (response.statusCode == 200) return _parseList(response.body);
      debugPrint('CommentsService: fetch status ${response.statusCode}');
    } catch (e) {
      debugPrint('CommentsService: fetch error: $e');
    }
    return [];
  }

  /// Adds a comment; returns the created record or null on failure.
  Future<ActivityCommentRecord?> createComment(int activityId, String content) async {
    return _postComment('$_basePath/activity_id/$activityId', content);
  }

  /// Edits own comment content; returns the updated record or null.
  Future<ActivityCommentRecord?> updateComment(int commentId, String content) async {
    return _postComment('$_basePath/$commentId', content, isUpdate: true);
  }

  /// Deletes own comment (or a comment under own activity as activity owner).
  Future<bool> deleteComment(int commentId) async {
    try {
      final response = await _apiClient.delete('$_basePath/$commentId');
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('CommentsService: delete error: $e');
      return false;
    }
  }

  Future<ActivityCommentRecord?> _postComment(
    String path,
    String content, {
    bool isUpdate = false,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;
    final body = <String, dynamic>{
      'content': trimmed.length > _contentMax ? trimmed.substring(0, _contentMax) : trimmed,
    };
    try {
      final response =
          isUpdate ? await _apiClient.put(path, body: body) : await _apiClient.post(path, body: body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ActivityCommentRecord.fromJson(json.decode(response.body) as Map<String, dynamic>);
      }
      debugPrint('CommentsService: ${isUpdate ? 'update' : 'create'} status ${response.statusCode}');
    } catch (e) {
      debugPrint('CommentsService: ${isUpdate ? 'update' : 'create'} error: $e');
    }
    return null;
  }

  /// Display name of the comment author (own profile / /users/id/{uid} cache).
  Future<String?> resolveAuthorName(int userId) async {
    final me = _userService.profile;
    if (me != null && me.id == userId) return me.name;
    final cached = _profileCache[userId];
    if (cached != null) {
      final name = cached['name'] ?? '';
      return name.isNotEmpty ? name : null;
    }
    try {
      final res = await _apiClient.get('/api/v1/users/id/$userId');
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final name = data['name']?.toString() ?? data['username']?.toString() ?? '';
        var photo = data['photo_path']?.toString() ?? '';
        if (photo.isNotEmpty && !photo.startsWith('http')) {
          final lastSlash = photo.lastIndexOf('/');
          final fileName = lastSlash >= 0 ? photo.substring(lastSlash + 1) : photo;
          final baseUrl = await _storage.getServerUrl();
          photo = '$baseUrl/user_images/$fileName';
        }
        _profileCache[userId] = {'name': name, 'photo': photo};
        return name.isNotEmpty ? name : null;
      }
    } catch (e) {
      debugPrint('CommentsService: resolveAuthorName($userId) error: $e');
    }
    return null;
  }

  Future<String?> resolveAuthorPhoto(int userId) async {
    final me = _userService.profile;
    if (me != null && me.id == userId) return me.photoUrl;
    final cached = _profileCache[userId];
    if (cached != null) {
      final photo = cached['photo'] ?? '';
      return photo.isNotEmpty ? photo : null;
    }
    // Resolving photo without name would double the requests; name lookup
    // fills both entries.
    await resolveAuthorName(userId);
    final photo = _profileCache[userId]?['photo'] ?? '';
    return photo.isNotEmpty ? photo : null;
  }
}
