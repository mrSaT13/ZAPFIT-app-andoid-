import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/activity_upload_service.dart';
import 'package:flutter/foundation.dart';

class SyncResult {
  final int pushed;
  final int pulled;
  final String? error;
  SyncResult({this.pushed = 0, this.pulled = 0, this.error});
  int get total => pushed + pulled;
}

class ActivitySyncService {
  final ApiClient _apiClient = ApiClient();
  final LocalActivityRepository _repository = LocalActivityRepository.instance;
  final ActivityUploadService _uploadService = ActivityUploadService();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Force-uploads a specific activity immediately, bypassing the 30-min delay.
  Future<SyncResult> forcePushActivity(int activityId) async {
    if (_isSyncing) return SyncResult(error: 'Синхронизация уже запущена');
    _isSyncing = true;
    try {
      debugPrint('Sync: Force uploading activity $activityId...');
      await _uploadService.uploadActivity(activityId);
      return SyncResult(pushed: 1);
    } catch (e) {
      debugPrint('Sync: Failed to force push activity $activityId: $e');
      return SyncResult(error: e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Full sync: Pushes pending local activities and pulls new ones from server.
  Future<SyncResult> syncAll() async {
    if (_isSyncing) return SyncResult(error: 'Sync already running');
    _isSyncing = true;
    try {
      debugPrint('Sync: Starting full synchronization...');
      int pushed = 0;
      int pulled = 0;
      try { pushed = await pushPendingActivities(); } catch (e) { debugPrint('Sync push error: $e'); }
      try { pulled = await syncActivities(); } catch (e) {
        debugPrint('Sync pull error: $e');
        if (e.toString().contains('timeout') || e.toString().contains('Connection') || e.toString().contains('Network') || e.toString().contains('Server URL')) {
          return SyncResult(pushed: pushed, pulled: pulled, error: 'Check network: $e');
        }
        return SyncResult(pushed: pushed, pulled: pulled, error: e.toString());
      }
      debugPrint('Sync: Finished. Pushed: $pushed, Pulled: $pulled');
      return SyncResult(pushed: pushed, pulled: pulled);
    } catch (e) {
      debugPrint('Sync: Critical error during syncAll: $e');
      return SyncResult(error: e.toString());
    } finally {
      _isSyncing = false;
    }
  }
  /// Pushes activities with 'pending' or 'failed' status to server.
  /// Imported activities (GPX/FIT) always upload immediately.
  /// Tracked activities are delayed 30 min after workout end.
  Future<int> pushPendingActivities() async {
    final activities = await _repository.getActivities();
    final pending = activities.where((a) => 
      a.uploadStatus == UploadStatus.pending || a.uploadStatus == UploadStatus.failed
    ).toList();

    bool trackedBlocked = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastEndMs = prefs.getInt('last_activity_end_ms');
      if (lastEndMs != null) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - lastEndMs;
        if (elapsed < 30 * 60 * 1000) {
          trackedBlocked = true;
        }
      }
    } catch (_) {}

    final toUpload = pending.where((a) {
      // Не отправляем активности в процессе записи (endedAt == null)
      if (a.endedAt == null) return false;
      final isImport = a.source == ActivitySource.gpxImport || a.source == ActivitySource.fitImport;
      if (isImport) return true;
      return !trackedBlocked;
    }).toList();

    if (toUpload.isEmpty) return 0;

    debugPrint('Sync: Found ${toUpload.length} activities to push (from ${pending.length} pending)');
    
    int count = 0;
    for (final activity in toUpload) {
      try {
        debugPrint('Sync: Uploading activity ${activity.id} ("${activity.title}")...');
        await _uploadService.uploadActivity(activity.id!);
        count++;
      } catch (e) {
        debugPrint('Sync: Failed to push activity ${activity.id}: $e');
      }
    }
    return count;
  }

  /// Syncs activities from server. Returns count of created/updated records.
  Future<int> syncActivities() async {
    try {
      debugPrint('Sync: Pulling activities from server...');
      final response = await _apiClient.get('/api/v1/activities/refresh');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = (decoded as List<dynamic>?) ?? <dynamic>[];
        debugPrint('Sync: Server returned ${data.length} activities');
        int count = 0;
        for (final item in data) {
          try {
            final serverActivity = ActivityRecord.fromServerJson(item as Map<String, dynamic>);
            if (serverActivity.serverId == null) continue;
            // Don't overwrite local pending/failed edits (e.g. after point add + distance recompute)
            final existing = await _repository.getActivityByServerId(serverActivity.serverId!);
            if (existing != null && (existing.uploadStatus == UploadStatus.pending || existing.uploadStatus == UploadStatus.failed)) {
              debugPrint('Sync pull: skip overwrite pending local id=${existing.id} serverId=${existing.serverId}');
              continue;
            }
            await _repository.upsertActivity(serverActivity.copyWith(source: ActivitySource.serverSync, uploadStatus: UploadStatus.uploaded));
            count++;
          } catch (e) { debugPrint('Sync: skip one item: $e'); }
        }
        try {
          final all = await _repository.getActivities();
          final byServerId = <int, ActivityRecord>{};
          final toDelete = <int>[];
          for (final a in all) {
            if (a.serverId != null) {
              if (byServerId.containsKey(a.serverId)) {
                final existing = byServerId[a.serverId]!;
                // Never delete a pending/failed local edit in favour of server copy
                final existingPending = existing.uploadStatus == UploadStatus.pending || existing.uploadStatus == UploadStatus.failed;
                final curPending = a.uploadStatus == UploadStatus.pending || a.uploadStatus == UploadStatus.failed;
                if (existingPending && !curPending) {
                  if (a.id != null) toDelete.add(a.id!);
                } else if (!existingPending && curPending) {
                  if (existing.id != null) toDelete.add(existing.id!);
                  byServerId[a.serverId!] = a;
                } else if (existing.source != ActivitySource.serverSync && a.source == ActivitySource.serverSync) {
                  if (existing.id != null) toDelete.add(existing.id!);
                  byServerId[a.serverId!] = a;
                } else if (a.id != null) { toDelete.add(a.id!); }
              } else { byServerId[a.serverId!] = a; }
            }
          }
          for (final id in toDelete) { try { await _repository.deleteActivity(id); } catch (_) {} }
        } catch (e) { debugPrint('Dedup error: $e'); }
        return count;
      } else {
        debugPrint('Sync: Server refresh failed ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      debugPrint('Sync: Error syncing activities: $e');
      if (e.toString().contains('timeout') || e.toString().contains('Network') || e.toString().contains('Connection')) return 0;
      rethrow;
    }
  }
}
