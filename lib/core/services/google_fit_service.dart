import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Fit integration service.
/// Two-way sync of steps, sleep, heart rate, and weight with Google Fit.
/// Uses the health package which supports Google Fit on Android.
class GoogleFitService extends ChangeNotifier {
  static const String _enabledKey = 'google_fit_enabled';
  static const String _lastSyncKey = 'google_fit_last_sync';

  final Health _health = Health();
  bool _isEnabled = false;
  bool _isAvailable = false;
  bool _hasPermissions = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastError;

  bool get isEnabled => _isEnabled;
  bool get isAvailable => _isAvailable;
  bool get hasPermissions => _hasPermissions;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;

  /// Check if Google Fit is available on this device.
  Future<bool> checkAvailability() async {
    try {
      _isAvailable = await _health.isHealthConnectAvailable();
      if (!_isAvailable) {
        _lastError = 'Health Connect не установлен. Установите приложение Health Connect из Google Play.';
      }
      return _isAvailable;
    } catch (e) {
      debugPrint('GoogleFit: availability check error: $e');
      _isAvailable = false;
      _lastError = 'Ошибка проверки Health Connect: $e';
      return false;
    }
  }

  /// Request permissions for all data types we need.
  Future<bool> requestPermissions() async {
    if (!_isAvailable) {
      await checkAvailability();
    }
    if (!_isAvailable) return false;

    // First try requestAuthorization
    try {
      _hasPermissions = await _health.requestAuthorization([
        HealthDataType.STEPS,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.HEART_RATE,
        HealthDataType.WEIGHT,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ], permissions: [
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
      ]);

      if (_hasPermissions) {
        _isEnabled = true;
        await _saveSettings();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('GoogleFit: requestAuthorization exception: $e');
    }

    // Fallback: try reading data directly
    try {
      final test = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now(),
      );
      debugPrint('GoogleFit: test read returned ${test.length} records');
      _hasPermissions = true;
      _isEnabled = true;
      await _saveSettings();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('GoogleFit: test read failed: $e');
    }

    _hasPermissions = false;
    return false;
  }

  /// Disable Google Fit integration.
  Future<void> disable() async {
    _isEnabled = false;
    await _saveSettings();
    notifyListeners();
  }

  /// Initialize from saved settings.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? false;
    final lastSyncMs = prefs.getInt(_lastSyncKey);
    if (lastSyncMs != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
    }
    await checkAvailability();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, _isEnabled);
    if (_lastSyncTime != null) {
      await prefs.setInt(_lastSyncKey, _lastSyncTime!.millisecondsSinceEpoch);
    }
  }

  /// Sync steps from Google Fit.
  Future<List<StepsRecord>> fetchSteps({
    DateTime? start,
    DateTime? end,
  }) async {
    if (!_isEnabled || !_hasPermissions) return [];

    final now = DateTime.now();
    final startTime = start ?? now.subtract(const Duration(days: 7));
    final endTime = end ?? now;

    try {
      final stepsData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startTime,
        endTime: endTime,
      );

      // Group by day
      final Map<String, int> dailySteps = {};
      for (final data in stepsData) {
        final dateStr = data.dateFrom.toLocal().toIso8601String().split('T')[0];
        final steps = (data.value as NumericHealthValue).numericValue.toInt();
        if (steps > 0 && steps < 40000) {
          dailySteps[dateStr] = (dailySteps[dateStr] ?? 0) + steps;
        }
      }

      return dailySteps.entries.map((e) {
        return StepsRecord(
          date: DateTime.parse(e.key),
          steps: e.value,
          isSynced: true,
        );
      }).toList();
    } catch (e) {
      debugPrint('GoogleFit: fetch steps error: $e');
      return [];
    }
  }

  /// Sync sleep from Google Fit.
  Future<List<SleepRecord>> fetchSleep({
    DateTime? start,
    DateTime? end,
  }) async {
    if (!_isEnabled || !_hasPermissions) return [];

    final now = DateTime.now();
    final startTime = start ?? now.subtract(const Duration(days: 7));
    final endTime = end ?? now;

    try {
      final sleepTypes = [
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_AWAKE,
      ];

      final sleepData = await _health.getHealthDataFromTypes(
        types: sleepTypes,
        startTime: startTime,
        endTime: endTime,
      );

      // Convert all segments to local time
      final List<_GFSleepSegment> allSegments = sleepData.map((data) => _GFSleepSegment(
        start: data.dateFrom.toLocal(),
        end: data.dateTo.toLocal(),
        type: data.type,
      )).toList();
      if (allSegments.isEmpty) return [];

      // Group overlapping segments into sleep sessions
      allSegments.sort((a, b) => a.start.compareTo(b.start));
      final List<List<_GFSleepSegment>> sessions = [];
      for (final seg in allSegments) {
        if (sessions.isEmpty) {
          sessions.add([seg]);
          continue;
        }
        final lastSeg = sessions.last.last;
        final gap = seg.start.difference(lastSeg.end);
        if (seg.start.isBefore(lastSeg.end) || (gap.inMinutes >= 0 && gap.inMinutes <= 120)) {
          sessions.last.add(seg);
        } else {
          sessions.add([seg]);
        }
      }

      return sessions.map((segments) {
        if (segments.isEmpty) return null;

        int _mergedDuration(List<_GFSleepSegment> segs) {
          if (segs.isEmpty) return 0;
          segs.sort((a, b) => a.start.compareTo(b.start));
          int total = 0;
          var curStart = segs.first.start;
          var curEnd = segs.first.end;
          for (var i = 1; i < segs.length; i++) {
            if (segs[i].start.isBefore(curEnd)) {
              if (segs[i].end.isAfter(curEnd)) curEnd = segs[i].end;
            } else {
              total += curEnd.difference(curStart).inSeconds;
              curStart = segs[i].start;
              curEnd = segs[i].end;
            }
          }
          total += curEnd.difference(curStart).inSeconds;
          return total;
        }

        final deep = _mergedDuration(segments.where((s) => s.type == HealthDataType.SLEEP_DEEP).toList());
        final rem = _mergedDuration(segments.where((s) => s.type == HealthDataType.SLEEP_REM).toList());
        final awake = _mergedDuration(segments.where((s) => s.type == HealthDataType.SLEEP_AWAKE).toList());
        final sleepSegs = segments.where((s) => s.type != HealthDataType.SLEEP_AWAKE).toList();
        final sleepMerged = _mergedDuration(sleepSegs);
        final light = max(0, sleepMerged - deep - rem);
        final totalSleep = deep + light + rem;

        // Cap at 14h
        final cappedTotal = totalSleep > 50400 ? 50400 : totalSleep;

        // Assign to wake-up date
        final wakeUp = segments.map((s) => s.end).reduce((a, b) => a.isAfter(b) ? a : b);
        final dateStr = wakeUp.toIso8601String().split('T')[0];

        return SleepRecord(
          date: DateTime.parse(dateStr),
          totalSleepSeconds: cappedTotal,
          deepSleepSeconds: deep,
          lightSleepSeconds: cappedTotal - deep - rem,
          remSleepSeconds: rem,
          awakeSleepSeconds: awake,
          isSynced: true,
        );
      }).whereType<SleepRecord>().toList();
    } catch (e) {
      debugPrint('GoogleFit: fetch sleep error: $e');
      return [];
    }
  }

  /// Sync heart rate from Google Fit.
  Future<List<HeartRateRecord>> fetchHeartRate({
    DateTime? start,
    DateTime? end,
  }) async {
    if (!_isEnabled || !_hasPermissions) return [];

    final now = DateTime.now();
    final startTime = start ?? now.subtract(const Duration(days: 7));
    final endTime = end ?? now;

    try {
      final hrData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startTime,
        endTime: endTime,
      );

      return hrData.map((data) {
        final bpm = (data.value as NumericHealthValue).numericValue.toInt();
        return HeartRateRecord(
          timestamp: data.dateFrom,
          bpm: bpm,
          source: 'google_fit',
          isSynced: true,
        );
      }).toList();
    } catch (e) {
      debugPrint('GoogleFit: fetch HR error: $e');
      return [];
    }
  }

  /// Sync weight from Google Fit.
  Future<List<WeightRecord>> fetchWeight({
    DateTime? start,
    DateTime? end,
  }) async {
    if (!_isEnabled || !_hasPermissions) return [];

    final now = DateTime.now();
    final startTime = start ?? now.subtract(const Duration(days: 30));
    final endTime = end ?? now;

    try {
      final weightData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT],
        startTime: startTime,
        endTime: endTime,
      );

      return weightData.map((data) {
        final weight = (data.value as NumericHealthValue).numericValue.toDouble();
        return WeightRecord(
          weight: weight,
          date: data.dateFrom,
          isSynced: true,
        );
      }).toList();
    } catch (e) {
      debugPrint('GoogleFit: fetch weight error: $e');
      return [];
    }
  }

  /// Full sync: fetch all data types and return them.
  Future<GoogleFitSyncResult> syncAll({int daysBack = 7}) async {
    if (!_isEnabled || !_hasPermissions) {
      return const GoogleFitSyncResult();
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysBack));

      final steps = await fetchSteps(start: start, end: now);
      final sleep = await fetchSleep(start: start, end: now);
      final hr = await fetchHeartRate(start: start, end: now);
      final weight = await fetchWeight(start: start, end: now);

      _lastSyncTime = DateTime.now();
      await _saveSettings();

      _isSyncing = false;
      notifyListeners();

      return GoogleFitSyncResult(
        steps: steps,
        sleep: sleep,
        heartRate: hr,
        weight: weight,
      );
    } catch (e) {
      _lastError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return const GoogleFitSyncResult();
    }
  }
}

class GoogleFitSyncResult {
  final List<StepsRecord> steps;
  final List<SleepRecord> sleep;
  final List<HeartRateRecord> heartRate;
  final List<WeightRecord> weight;

  const GoogleFitSyncResult({
    this.steps = const [],
    this.sleep = const [],
    this.heartRate = const [],
    this.weight = const [],
  });

  int get totalCount => steps.length + sleep.length + heartRate.length + weight.length;
}

class _GFSleepSegment {
  final DateTime start;
  final DateTime end;
  final HealthDataType type;
  _GFSleepSegment({required this.start, required this.end, required this.type});
}
