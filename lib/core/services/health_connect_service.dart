import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/core/utils/hr_estimator.dart';

class HealthConnectService {
  HealthConnectService._();
  static final HealthConnectService instance = HealthConnectService._();

  Health? _health;
  bool _hasPermissions = false;
  bool? _isAvailable;

  static const List<HealthDataType> _hcTypes = [
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
    HealthDataType.WEIGHT,
  ];
  static final List<HealthDataAccess> _hcPerms =
      List.filled(_hcTypes.length, HealthDataAccess.READ);

  Health get _h {
    _health ??= Health();
    return _health!;
  }

  bool get hasPermissionsConfirmed => _hasPermissions;

  Future<bool> isAvailable() async {
    try {
      final h = Health();
      _isAvailable = await h.isHealthConnectAvailable();
      return _isAvailable!;
    } catch (e) {
      debugPrint('HealthConnect: availability check error: $e');
      _isAvailable = false;
      return false;
    }
  }

  /// Authoritative, read-only permission check.
  /// Uses the plugin's real [Health.hasPermissions] instead of inferring
  /// permission from requestAuthorization() + a non-empty STEPS read.
  /// This fixes the false "no permissions" when access IS granted but the
  /// user has no recent step data.
  Future<bool> checkPermissions({bool force = false}) async {
    if (_hasPermissions && !force) return true;
    try {
      final granted = await _h.hasPermissions(_hcTypes, permissions: _hcPerms);
      if (granted == true) {
        _hasPermissions = true;
        _isAvailable = true;
        return true;
      }
      if (granted == false) {
        _hasPermissions = false;
        return false;
      }
      // granted == null: undetermined (e.g. iOS privacy prompt). Treat as not granted.
      _hasPermissions = false;
      return false;
    } catch (e) {
      debugPrint('HealthConnect: checkPermissions error: $e');
      _hasPermissions = false;
      return false;
    }
  }

  /// Kept for backward compatibility. Prefer [checkPermissions].
  Future<bool> hasPermissions() => checkPermissions();

  Future<List<SleepRecord>> fetchSleep({
    DateTime? start,
    DateTime? end,
  }) async {
    if (!_hasPermissions) {
      final ok = await hasPermissions();
      if (!ok) return [];
    }

    final now = DateTime.now();
    final startTime = start ?? now.subtract(const Duration(days: 7));
    final endTime = end ?? now;

    try {
      final hc = Health();
      final sleepData = await hc.getHealthDataFromTypes(
        types: [
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_REM,
          HealthDataType.SLEEP_AWAKE,
        ],
        startTime: startTime,
        endTime: endTime,
      );
      debugPrint('HealthConnect: raw sleep records = ${sleepData.length}');
      for (final d in sleepData) {
        debugPrint('  HC sleep segment: ${d.dateFrom.toLocal()} -> ${d.dateTo.toLocal()} type=${d.type}');
      }
      // Convert all segments to local time first
      final List<_SleepSegment> allSegments = sleepData.map((data) => _SleepSegment(
        start: data.dateFrom.toLocal(),
        end: data.dateTo.toLocal(),
        type: data.type,
      )).toList();

      if (allSegments.isEmpty) return [];

      // Group overlapping segments into sleep sessions (one night's sleep is one session)
      allSegments.sort((a, b) => a.start.compareTo(b.start));
      final List<List<_SleepSegment>> sessions = [];
      for (final seg in allSegments) {
        if (sessions.isEmpty) {
          sessions.add([seg]);
          continue;
        }
        final lastSeg = sessions.last.last;
        final gap = seg.start.difference(lastSeg.end);
        // Overlap: append to current session
        // Gap <= 2h: likely brief wake-up between sleep cycles - same session
        // Gap > 12h: definitely different session (e.g. yesterday's sleep and today's nap)
        if (seg.start.isBefore(lastSeg.end) || (gap.inMinutes >= 0 && gap.inMinutes <= 120)) {
          sessions.last.add(seg);
        } else {
          sessions.add([seg]);
        }
      }
      debugPrint('HealthConnect: grouped ${allSegments.length} segments into ${sessions.length} sleep sessions');

      // Merge overlapping intervals per type
      int mergedDuration(List<_SleepSegment> segs) {
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

      // For each session, compute sleep stats and assign to the wake-up date
      final sessionRecords = <String, SleepRecord>{};
      for (final segments in sessions) {
        if (segments.isEmpty) continue;
        final deep = mergedDuration(segments.where((s) => s.type == HealthDataType.SLEEP_DEEP).toList());
        final rem = mergedDuration(segments.where((s) => s.type == HealthDataType.SLEEP_REM).toList());
        final awake = mergedDuration(segments.where((s) => s.type == HealthDataType.SLEEP_AWAKE).toList());
        // Light = total sleep (all non-awake merged) - deep - rem
        final sleepSegs = segments.where((s) => s.type != HealthDataType.SLEEP_AWAKE).toList();
        final sleepMerged = mergedDuration(sleepSegs);
        final light = max(0, sleepMerged - deep - rem);
        final totalSleep = deep + light + rem;

        // Assign session to the wake-up date (date of last segment's end)
        final wakeUp = segments.map((s) => s.end).reduce((a, b) => a.isAfter(b) ? a : b);
        final dateStr = wakeUp.toIso8601String().split('T')[0];
        debugPrint('HealthConnect: sleep session $dateStr total=${totalSleep}s deep=$deep light=$light rem=$rem awake=$awake segs=${segments.length}');

        // Cap total sleep at 14h (50400s) to filter out clearly erroneous data
        final cappedTotal = totalSleep > 50400 ? 50400 : totalSleep;
        if (cappedTotal != totalSleep) {
          debugPrint('HealthConnect: sleep session capped from ${totalSleep}s to $cappedTotal}s (exceeded 14h limit)');
        }

        // If multiple sessions map to the same date (e.g. night + nap), keep the longest
        final existing = sessionRecords[dateStr];
        if (existing != null && existing.totalSleepSeconds >= cappedTotal) {
          debugPrint('HealthConnect: merging sleep session $dateStr — keeping ${existing.totalSleepSeconds}s over ${cappedTotal}s');
          continue;
        }

        // Calculate HR statistics for this sleep session
        final sleepStart = segments.first.start;
        final sleepEnd = segments.last.end;
        final avgHr = _calculateAvgHrForPeriod(sleepStart, sleepEnd);
        final minHr = _calculateMinHrForPeriod(sleepStart, sleepEnd);
        final maxHr = _calculateMaxHrForPeriod(sleepStart, sleepEnd);

        // Estimate resting HR from sleep data (10th percentile of HR during sleep)
        final restingHr = HrEstimator.estimateRestingHrFromSleepData(
          _getHrValuesForPeriod(sleepStart, sleepEnd),
        );

        debugPrint('HealthConnect: sleep $dateStr avgHR=$avgHr minHR=$minHr maxHR=$maxHr restingHR=$restingHr');

        sessionRecords[dateStr] = SleepRecord(
          date: DateTime.parse(dateStr),
          totalSleepSeconds: cappedTotal,
          deepSleepSeconds: deep,
          lightSleepSeconds: cappedTotal - deep - rem,
          remSleepSeconds: rem,
          awakeSleepSeconds: awake,
          restHeartRate: restingHr,
          avgHeartRate: avgHr,
          minHeartRate: minHr,
          maxHeartRate: maxHr,
          sleepStartTime: sleepStart,
          sleepEndTime: sleepEnd,
          isSynced: false,
        );
      }
      return sessionRecords.values.toList();
    } catch (e) {
      debugPrint('HealthConnect: fetch sleep error: $e');
      return [];
    }
  }

  /// Get all HR values for a time period (for resting HR estimation)
  List<int> _getHrValuesForPeriod(DateTime start, DateTime end) {
    // In real implementation, this would query the HR repository
    // For now, return empty list - resting HR will be calculated from sleep data
    return [];
  }

  /// Calculate average HR for sleep period
  int? _calculateAvgHrForPeriod(DateTime start, DateTime end) {
    // Placeholder - in real app would query heart_rate_records table
    return null;
  }

  /// Calculate minimum HR for sleep period
  int? _calculateMinHrForPeriod(DateTime start, DateTime end) {
    // Placeholder - in real app would query heart_rate_records table
    return null;
  }

  /// Calculate maximum HR for sleep period
  int? _calculateMaxHrForPeriod(DateTime start, DateTime end) {
    // Placeholder - in real app would query heart_rate_records table
    return null;
  }

  Future<List<HeartRateRecord>> fetchHeartRate({
    DateTime? start,
    DateTime? end,
  }) async {
    if (!_hasPermissions) {
      final ok = await hasPermissions();
      if (!ok) return [];
    }

    final now = DateTime.now();
    final startTime = start ?? now.subtract(const Duration(days: 7));
    final endTime = end ?? now;

    try {
      final hc = Health();
      final hrData = await hc.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startTime,
        endTime: endTime,
      );
      debugPrint('HealthConnect: raw HR records = ${hrData.length}');

      // Deduplicate: same timestamp = same reading from different sources - keep one
      final seen = <int>{};
      final result = <HeartRateRecord>[];
      for (final data in hrData) {
        final tsMs = data.dateFrom.millisecondsSinceEpoch;
        if (seen.contains(tsMs)) continue;
        seen.add(tsMs);
        final bpm = (data.value as NumericHealthValue).numericValue.toInt();
        if (bpm > 0 && bpm < 300) {
          result.add(HeartRateRecord(
            timestamp: data.dateFrom,
            bpm: bpm,
            source: 'health_connect',
            isSynced: true,
          ));
        }
      }
      return result;
    } catch (e) {
      debugPrint('HealthConnect: fetch HR error: $e');
      return [];
    }
  }

  Future<List<StepsRecord>> fetchSteps({
    DateTime? start,
    DateTime? end,
  }) async {
    if (!_hasPermissions) {
      final ok = await hasPermissions();
      if (!ok) return [];
    }

    final now = DateTime.now();
    final startTime = start ?? now.subtract(const Duration(days: 7));
    final endTime = end ?? now;

    try {
      final hc = Health();
      final stepsData = await hc.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startTime,
        endTime: endTime,
      );
      debugPrint('HealthConnect: raw steps records = ${stepsData.length}');

      // Group ALL records by local date
      final Map<String, List<_StepEntry>> dailyEntries = {};
      for (final data in stepsData) {
        final dateStr = data.dateFrom.toLocal().toIso8601String().split('T')[0];
        final steps = (data.value as NumericHealthValue).numericValue.toInt();
        if (steps <= 0 || steps >= 50000) continue;
        dailyEntries.putIfAbsent(dateStr, () => []);
        dailyEntries[dateStr]!.add(_StepEntry(
          start: data.dateFrom,
          end: data.dateTo,
          steps: steps,
        ));
      }

      // For each day: merge overlapping records, take MAX per overlap group, sum groups
      final result = <StepsRecord>[];
      for (final e in dailyEntries.entries) {
        final entries = e.value;
        if (entries.isEmpty) continue;
        // Sort by start time
        entries.sort((a, b) => a.start.compareTo(b.start));
        // Merge overlapping time ranges: overlapping records measure the same thing
        int totalSteps = 0;
        var curEnd = entries.first.end;
        int curMaxSteps = entries.first.steps;
        for (var i = 1; i < entries.length; i++) {
          final entry = entries[i];
          if (entry.start.isBefore(curEnd) || entry.start.isAtSameMomentAs(curEnd)) {
            // Overlapping - take the max steps value
            if (entry.steps > curMaxSteps) curMaxSteps = entry.steps;
            if (entry.end.isAfter(curEnd)) curEnd = entry.end;
          } else {
            // Non-overlapping - add the previous group's max and start new group
            totalSteps += curMaxSteps;
            curEnd = entry.end;
            curMaxSteps = entry.steps;
          }
        }
        totalSteps += curMaxSteps;
        debugPrint('HealthConnect: steps ${e.key} = $totalSteps (from ${entries.length} records)');
        result.add(StepsRecord(
          date: DateTime.parse(e.key),
          steps: totalSteps,
          isSynced: false,
        ));
      }
      return result;
    } catch (e) {
      debugPrint('HealthConnect: fetch steps error: $e');
      return [];
    }
  }

  Future<List<WeightRecord>> fetchWeight({
    DateTime? start,
    DateTime? end,
  }) async {
    if (!_hasPermissions) {
      final ok = await hasPermissions();
      if (!ok) return [];
    }

    final now = DateTime.now();
    final startTime = start ?? now.subtract(const Duration(days: 30));
    final endTime = end ?? now;

    try {
      final hc = Health();
      final weightData = await hc.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT],
        startTime: startTime,
        endTime: endTime,
      );
      return weightData.map((data) {
        final weight = (data.value as NumericHealthValue).numericValue.toDouble();
        return WeightRecord(
          weight: weight,
          date: data.dateFrom,
          isSynced: false,
        );
      }).toList();
    } catch (e) {
      debugPrint('HealthConnect: fetch weight error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchCalories({
    DateTime? start,
    DateTime? end,
  }) async {
    if (!_hasPermissions) {
      final ok = await hasPermissions();
      if (!ok) return [];
    }

    final now = DateTime.now();
    final startTime = start ?? now.subtract(const Duration(days: 7));
    final endTime = end ?? now;

    try {
      final hc = Health();
      final data = await hc.getHealthDataFromTypes(
        types: [HealthDataType.TOTAL_CALORIES_BURNED],
        startTime: startTime,
        endTime: endTime,
      );
      final Map<String, double> dailyCalories = {};
      for (final d in data) {
        final dateStr = d.dateFrom.toLocal().toIso8601String().split('T')[0];
        final cals = (d.value as NumericHealthValue).numericValue.toDouble();
        dailyCalories[dateStr] = (dailyCalories[dateStr] ?? 0) + cals;
      }
      return dailyCalories.entries.map((e) => {
        'date': e.key,
        'calories': e.value,
      }).toList();
    } catch (e) {
      debugPrint('HealthConnect: fetch calories error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchDistance({
    DateTime? start,
    DateTime? end,
  }) async {
    if (!_hasPermissions) {
      final ok = await hasPermissions();
      if (!ok) return [];
    }

    final now = DateTime.now();
    final startTime = start ?? now.subtract(const Duration(days: 7));
    final endTime = end ?? now;

    try {
      final hc = Health();
      final data = await hc.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_DELTA],
        startTime: startTime,
        endTime: endTime,
      );
      final Map<String, double> dailyDistance = {};
      for (final d in data) {
        final dateStr = d.dateFrom.toLocal().toIso8601String().split('T')[0];
        final dist = (d.value as NumericHealthValue).numericValue.toDouble();
        dailyDistance[dateStr] = (dailyDistance[dateStr] ?? 0) + dist;
      }
      return dailyDistance.entries.map((e) => {
        'date': e.key,
        'distance': e.value,
      }).toList();
    } catch (e) {
      debugPrint('HealthConnect: fetch distance error: $e');
      return [];
    }
  }
}

class _SleepSegment {
  final DateTime start;
  final DateTime end;
  final HealthDataType type;
  _SleepSegment({required this.start, required this.end, required this.type});
}

class _StepEntry {
  final DateTime start;
  final DateTime end;
  final int steps;
  _StepEntry({required this.start, required this.end, required this.steps});
}
