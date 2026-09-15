import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/services/gpx_service.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/local_notification_service.dart';

class ActivityUploadService {
  final ApiClient _apiClient = ApiClient();
  final GpxService _gpxService = GpxService();
  final LocalActivityRepository _repository = LocalActivityRepository.instance;

  Future<void> uploadActivity(int activityId) async {
    final activity = await _repository.getActivity(activityId);
    if (activity == null) {
      throw StateError('Activity not found');
    }

    try {
      // If activity already has a serverId, update it directly via edit endpoint
      if (activity.serverId != null) {
        debugPrint('Activity already on server (id=${activity.serverId}), updating metadata...');
        final editBody = <String, dynamic>{
          'id': activity.serverId,
          'name': activity.title,
          'description': activity.notes,
          'activity_type': activity.kind.value,
          'visibility': activity.visibility,
          'gear_id': activity.gearId,
        };
        _addZapfitFields(editBody, activity);
        final editResponse = await _apiClient.put('/api/v1/activities/edit', body: editBody);
        if (editResponse.statusCode == 200) {
          // догружаем все локальные фото (gallery) + legacy photoPath, если ещё не на сервере
          try {
            final media = await _repository.getMediaForActivity(activityId);
            for (final m in media) {
              if (File(m.mediaPath).existsSync()) {
                await _apiClient.uploadFile(
                  '/api/v1/activities_media/upload/activity_id/${activity.serverId}',
                  m.mediaPath,
                  'file',
                );
              }
            }
            if (activity.photoPath != null && File(activity.photoPath!).existsSync()) {
              final already = media.any((e) => e.mediaPath == activity.photoPath);
              if (!already) {
                await _apiClient.uploadFile(
                  '/api/v1/activities_media/upload/activity_id/${activity.serverId}',
                  activity.photoPath!,
                  'file',
                );
              }
            }
          } catch (e) {
            debugPrint('Media upload on edit failed: $e');
          }
          await _repository.updateActivity(
            activity.copyWith(uploadStatus: UploadStatus.uploaded),
          );
          await LocalNotificationService.instance.showSyncSuccess(1);
          return;
        } else if (editResponse.statusCode == 404) {
          debugPrint('Activity 404 - stale serverId ${activity.serverId}, will re-create via GPX');
          await _repository.updateActivity(activity.copyWith(serverId: null, uploadStatus: UploadStatus.pending));
          // fall through to GPX upload below - рекурсивно как новая активность
          return uploadActivity(activityId);
        } else {
          debugPrint('Activity edit failed: ${editResponse.statusCode} ${editResponse.body}');
          if (editResponse.statusCode == 422) {
            debugPrint('Edit validation error: ${editResponse.body}');
          }
          await _markStatus(activity, false);
          await LocalNotificationService.instance.showError(
            'Ошибка сервера',
            'Не удалось обновить "${activity.title}": ${editResponse.statusCode} ${editResponse.body}',
          );
          return;
        }
      }

      // New activity — export GPX and upload
      final file = await _gpxService.exportActivity(activityId);
      final endpoint = AppSettingsController.instance.uploadEndpoint;
      final response = await _apiClient.uploadFile(endpoint, file.path, 'file');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic decoded = json.decode(await response.stream.bytesToString());
        final List<dynamic> result = decoded is List ? decoded : [decoded];
        
        if (result.isNotEmpty) {
          final serverId = result[0]['id'] as int;
          
          // [comment removed - encoding corrupted]
          final editBody = <String, dynamic>{
            'id': serverId,
            'name': activity.title,
            'description': activity.notes,
            'activity_type': activity.kind.value,
            'visibility': activity.visibility,
            'gear_id': activity.gearId,
          };
          _addZapfitFields(editBody, activity);
          final editResponse = await _apiClient.put('/api/v1/activities/edit', body: editBody);
          if (editResponse.statusCode != 200) {
            debugPrint('Activity edit metadata failed: ${editResponse.statusCode}');
          }

          // грузим все локальные фото (gallery + legacy photoPath)
          try {
            final media = await _repository.getMediaForActivity(activityId);
            for (final m in media) {
              if (File(m.mediaPath).existsSync()) {
                await _apiClient.uploadFile(
                  '/api/v1/activities_media/upload/activity_id/$serverId',
                  m.mediaPath,
                  'file',
                );
              }
            }
            if (activity.photoPath != null && File(activity.photoPath!).existsSync()) {
              final already = media.any((e) => e.mediaPath == activity.photoPath);
              if (!already) {
                await _apiClient.uploadFile(
                  '/api/v1/activities_media/upload/activity_id/$serverId',
                  activity.photoPath!,
                  'file',
                );
              }
            }
          } catch (e) {
            debugPrint('Media batch upload failed: $e');
          }

          // [comment removed - encoding corrupted]
          await _repository.updateActivity(
            activity.copyWith(
              serverId: serverId,
              uploadStatus: UploadStatus.uploaded,
            ),
          );
          
          await LocalNotificationService.instance.showSyncSuccess(1);
        }
      } else {
        debugPrint('Upload failed with status: ${response.statusCode}');
        await _markStatus(activity, false);
        await LocalNotificationService.instance.showError(
          'Ошибка облака', 
          'Сервер вернул ошибку ${response.statusCode} при загрузке "${activity.title}"'
        );
      }
      
      await _deleteIfExists(file);
    } catch (e) {
      debugPrint('Upload Error: $e');
      await _markStatus(activity, false);
      await LocalNotificationService.instance.showError(
        'Ошибка синхронизации', 
        'Не удалось загрузить "${activity.title}". Проверьте сеть.'
      );
      rethrow;
    }
  }

  Future<void> _markStatus(ActivityRecord record, bool success) async {
    await _repository.updateActivity(
      record.copyWith(
        uploadStatus: success ? UploadStatus.uploaded : UploadStatus.failed,
      ),
    );
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _addZapfitFields(Map<String, dynamic> body, ActivityRecord a) {
    if (a.vo2max != null) body['vo2max'] = (a.vo2max!.clamp(0.0, 100.0));
    if (a.tss != null) body['tss'] = a.tss!.clamp(0, 500);
    if (a.hrTss != null) body['hr_tss'] = a.hrTss!.clamp(0, 500);
    if (a.trimp != null) body['trimp'] = a.trimp!.clamp(0, 1000);
    if (a.intensityFactor != null) body['intensity_factor'] = (a.intensityFactor!.clamp(0.0, 2.0));
    if (a.aerobicTe != null) body['aerobic_te'] = (a.aerobicTe!.clamp(0.0, 5.0));
    if (a.anaerobicTe != null) body['anaerobic_te'] = (a.anaerobicTe!.clamp(0.0, 5.0));
    if (a.epoc != null) body['epoc'] = (a.epoc!);
    if (a.sufferScore != null) body['suffer_score'] = a.sufferScore!.clamp(0, 100);
    if (a.efficiencyFactor != null) body['efficiency_factor'] = a.efficiencyFactor;
  }
}
