import 'dart:async';
import 'dart:io';
import 'package:zapfit/core/services/gpx_service.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:flutter/foundation.dart';

/// Monitors a folder for new GPX/TCX files and auto-imports them.
class FolderImportService {
  FolderImportService._();
  static final FolderImportService instance = FolderImportService._();

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  Timer? _monitorTimer;
  final Set<String> _importedFiles = {};

  /// Start monitoring the configured folder for new GPX/TCX files.
  void startMonitoring() {
    if (_isMonitoring) return;
    final settings = AppSettingsController.instance;
    if (!settings.folderAutoImportEnabled || settings.folderAutoImportPath.isEmpty) return;

    _isMonitoring = true;
    _scanFolder();

    // Check every 5 minutes
    _monitorTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _scanFolder();
    });
  }

  /// Stop monitoring.
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
  }

  /// Scan the folder for new GPX/TCX files.
  Future<void> _scanFolder() async {
    final settings = AppSettingsController.instance;
    final folderPath = settings.folderAutoImportPath;
    if (folderPath.isEmpty) return;

    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) return;

      final files = await dir.list().where((entity) {
        if (entity is! File) return false;
        final name = entity.path.toLowerCase();
        return name.endsWith('.gpx') || name.endsWith('.tcx') || name.endsWith('.fit');
      }).toList();

      int importedCount = 0;
      for (final file in files) {
        final filePath = file.path;
        if (_importedFiles.contains(filePath)) continue;

        final stat = await file.stat();

        try {
          final gpxService = GpxService();
          final isFit = filePath.toLowerCase().endsWith('.fit');
          final id = isFit
              ? await gpxService.importFitFromPath(filePath)
              : await gpxService.importFromPath(filePath);
          if (id != null) {
            _importedFiles.add(filePath);
            importedCount++;
          }
        } catch (e) {
          debugPrint('FolderImport: Error importing $filePath: $e');
        }
      }

      if (importedCount > 0) {
        debugPrint('FolderImport: Imported $importedCount new files from $folderPath');
      }
    } catch (e) {
      debugPrint('FolderImport: Error scanning folder: $e');
    }
  }

  /// Check for new files on demand (manual trigger).
  Future<int> checkNow() async {
    final before = _importedFiles.length;
    await _scanFolder();
    return _importedFiles.length - before;
  }

  void dispose() {
    stopMonitoring();
    _importedFiles.clear();
  }
}
