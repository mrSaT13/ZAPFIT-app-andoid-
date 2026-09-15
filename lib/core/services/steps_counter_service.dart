import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/services/health_connect_service.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/native_steps_reader.dart';

/// [comment removed - encoding corrupted]
/// [comment removed - encoding corrupted]
///
/// [comment removed - encoding corrupted]
/// [comment removed - encoding corrupted]
///
/// [comment removed - encoding corrupted]
/// [comment removed - encoding corrupted]
/// [comment removed - encoding corrupted]
/// [comment removed - encoding corrupted]
/// [comment removed - encoding corrupted]
class StepsCounterService extends ChangeNotifier {
  static final StepsCounterService instance = StepsCounterService._();
  StepsCounterService._();

  final AppSettingsController _settings = AppSettingsController.instance;
  final LocalActivityRepository _repo = LocalActivityRepository.instance;
  final HealthService _healthService = HealthService();
  final NativeStepsReader _reader = NativeStepsReader.instance;

  bool _isSyncing = false;
  DateTime? _lastSyncedAt;
  String? _lastError;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;
  bool get permissionsGranted => _settings.stepsHealthPermissionsGranted;
  bool get autoSyncEnabled => _settings.stepsAutoSyncEnabled;
  int get syncHour => _settings.stepsSyncHour;
  String get source => _reader.source;

  /// [comment removed - encoding corrupted]
  Future<bool> requestPermissions() async {
    final ok = await _reader.requestPermissions();
    await _settings.setStepsHealthPermissionsGranted(ok);
    await _settings.setStepsHealthSource(_reader.source);
    notifyListeners();
    return ok;
  }

  /// [comment removed - encoding corrupted]
  Future<bool> hasPermissions() async {
    return _reader.hasPermissions();
  }

  /// [comment removed - encoding corrupted]
  Future<int?> readStepsForDate(DateTime date) {
    if (!_settings.stepsHealthPermissionsGranted) return Future.value(null);
    return _reader.readStepsForDate(date);
  }

  /// [comment removed - encoding corrupted]
  /// [comment removed - encoding corrupted]
  /// [comment removed - encoding corrupted]
  Future<int> syncNow({int daysBack = 1}) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    if (_reader.source == 'none') {
      await _reader.requestPermissions();
    }

    int successDays = 0;
    try {
      final today = DateTime.now();
      for (int i = daysBack; i >= 1; i--) {
        final day = DateTime(today.year, today.month, today.day)
            .subtract(Duration(days: i - 1));
        final steps = await readStepsForDate(day);
        
        final existing = await _repo.getStepsRecords();
        final dayKey = _dateKey(day);
        final matchIndex = existing.indexWhere(
          (r) => _dateKey(r.date) == dayKey,
        );

        if (steps != null && steps > 0) {
          // Pedometer has data — use it
          if (matchIndex != -1) {
            if (existing[matchIndex].steps >= steps) {
              successDays++;
              continue;
            }
            await _repo.updateStepsRecord(
              existing[matchIndex].copyWith(steps: steps, isSynced: false),
            );
          } else {
            await _repo.addStepsRecord(StepsRecord(
              date: day,
              steps: steps,
              isSynced: false,
            ));
          }
        } else if (matchIndex == -1) {
          // No pedometer data and no local record — try Health Connect as fallback
          try {
            final hc = HealthConnectService.instance;
            final hcSteps = await hc.fetchSteps(start: day, end: day.add(const Duration(days: 1)));
            if (hcSteps.isNotEmpty && hcSteps.first.steps > 0) {
              await _repo.addStepsRecord(hcSteps.first.copyWith(isSynced: false));
            }
          } catch (_) {}
        }
        successDays++;
      }

      _lastSyncedAt = DateTime.now();
      await _settings.setStepsLastSyncDate(_dateKey(today));
    } catch (e) {
      _lastError = 'Ошибка синхронизации шагов: $e';
      debugPrint('StepsCounterService.syncNow: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
    return successDays;
  }

  /// [comment removed - encoding corrupted]
  bool shouldRunAutoSync() {
    if (!_settings.stepsAutoSyncEnabled) return false;
    if (!_settings.stepsHealthPermissionsGranted) return false;

    final now = DateTime.now();
    final todayKey = _dateKey(now);
    if (_settings.stepsLastSyncDate == todayKey) return false;

    final hourDiff = (now.hour - _settings.stepsSyncHour).abs();
    // [comment removed - encoding corrupted]
    return true;
  }

  /// [comment removed - encoding corrupted]
  Future<void> tickAutoSync() async {
    if (!shouldRunAutoSync()) return;
    await syncNow(daysBack: 2);
  }

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
