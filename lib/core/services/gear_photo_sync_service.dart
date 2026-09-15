import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/models/gear_photo.dart';

/// Sync local gear_photos to server /gear_images + pull server images for offline cache
class GearPhotoSyncService {
  GearPhotoSyncService._();
  static final GearPhotoSyncService instance = GearPhotoSyncService._();

  final ApiClient _api = ApiClient();
  final LocalActivityRepository _repo = LocalActivityRepository.instance;

  /// Upload all unsynced local gear photos. Marks synced on success.
  Future<void> syncAll() async {
    try {
      final photos = await _repo.getUnsyncedGearPhotos();
      for (final photo in photos) {
        final filePath = photo.filePath;
        final gearId = photo.gearId;
        final f = File(filePath);
        if (!await f.exists()) continue;
        try {
          final resp = await _api.uploadFile('/api/v1/gear_images/upload/gear/$gearId', filePath, 'file');
          if (resp.statusCode == 201 || resp.statusCode == 200) {
            debugPrint('GearPhotoSync: uploaded gear $gearId $filePath');
            await _repo.updateGearPhoto(photo.copyWith(synced: true));
          } else if (resp.statusCode == 409) {
            debugPrint('GearPhotoSync: duplicate $filePath');
            await _repo.updateGearPhoto(photo.copyWith(synced: true));
          } else {
            debugPrint('GearPhotoSync: failed ${resp.statusCode} for $filePath');
          }
        } catch (e) {
          debugPrint('GearPhotoSync error $e for $filePath');
        }
      }
    } catch (e) {
      debugPrint('GearPhotoSync syncAll error: $e');
    }
  }

  /// Pull server images for [gearId] and cache on disk (offline). Called on gear detail open.
  Future<List<GearPhoto>> syncFromServer(int gearId) async {
    try {
      final resp = await _api.get('/api/v1/gear_images/gear/$gearId');
      if (resp.statusCode != 200) return [];
      final data = json.decode(resp.body) as List<dynamic>;
      final appDir = await getApplicationDocumentsDirectory();
      final gearDir = Directory(p.join(appDir.path, 'gear_photos', '$gearId'));
      if (!gearDir.existsSync()) await gearDir.create(recursive: true);
      final List<GearPhoto> result = [];
      for (final item in data) {
        final m = item as Map<String, dynamic>;
        final serverId = (m['id'] as num).toInt();
        final imageUrl = (m['image_url'] as String?) ?? (m['image_path'] as String?) ?? '';
        if (imageUrl.isEmpty) continue;
        // Skip if already cached
        final existing = await _repo.getGearPhotoByServerId(serverId);
        if (existing != null && File(existing.filePath).existsSync()) {
          result.add(existing);
          continue;
        }
        try {
          final bytes = await _api.getImageBytes(imageUrl);
          if (bytes == null || bytes.isEmpty) continue;
          final filename = 'server_${serverId}_${imageUrl.split('/').last}';
          final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final filePath = p.join(gearDir.path, safeName);
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          final photo = GearPhoto(
            gearId: gearId,
            filePath: filePath,
            serverId: serverId,
            synced: true,
            createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : DateTime.now(),
          );
          final id = await _repo.addGearPhoto(photo);
          result.add(photo.copyWith(id: id));
          debugPrint('GearPhotoSync: cached server image $serverId -> $filePath');
        } catch (e) {
          debugPrint('GearPhotoSync cache error $serverId: $e');
        }
      }
      return result;
    } catch (e) {
      debugPrint('GearPhotoSync syncFromServer error: $e');
      return [];
    }
  }
}
