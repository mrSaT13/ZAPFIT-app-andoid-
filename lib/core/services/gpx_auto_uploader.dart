import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:zapfit/core/services/gpx_service.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/services/activity_repository.dart';
import 'package:zapfit/core/di/injection.dart';

class GpxAutoUploader {
  static final GpxAutoUploader _instance = GpxAutoUploader._internal();
  factory GpxAutoUploader() => _instance;
  GpxAutoUploader._internal();

  Timer? _periodicTimer;
  final Duration _period = const Duration(minutes: 2);
  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _startTimer();
  }

  void _startTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_period, (_) => _scanAndProcess());
  }

  Future<void> stop() async {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _running = false;
  }

  Future<void> triggerScan() async {
    await _scanAndProcess();
  }

  Future<void> _scanAndProcess() async {
    try {
      final storage = SecureStorageService();
      
      // 1. Check auto-upload GPX setting
      final autoUploadEnabled = await storage.getAutoUploadGpx();
      final folderPath = await storage.getScanFolderPath();
      
      if (autoUploadEnabled && folderPath != null && folderPath.isNotEmpty) {
        final dir = Directory(folderPath);
        if (await dir.exists()) {
          final files = dir.listSync()
              .whereType<File>()
              .where((f) => p.extension(f.path).toLowerCase() == '.gpx')
              .toList();

          final repository = getIt<ActivityRepository>();
          for (final file in files) {
            final activity = await GpxService.parseGpx(file);
            if (activity != null) {
              await repository.create(activity);
              // [comment removed - encoding corrupted]
            }
          }
        }
      }

      // 2. Auto-sync with API
      final autoUploadApi = await storage.getAutoUploadGpx();
      if (autoUploadApi) {
        final repository = getIt<ActivityRepository>();
        final activities = await repository.listAll();
        final unuploaded = activities.where((a) => !a.uploaded).toList();

        // TODO: Implement activity upload
        for (final activity in unuploaded) {
          // await getIt<ActivityUploadService>().uploadActivity(activity);
          if (activity.name != null) {
            // Placeholder to use activity variable
          }
        }
      }
    } catch (e) {
      // Log error
    }
  }
}
