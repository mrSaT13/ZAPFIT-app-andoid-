import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zapfit/core/models/training_metrics.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/utils/hr_estimator.dart';

class TrainingMetricsService {
  TrainingMetricsService._();
  static final TrainingMetricsService instance = TrainingMetricsService._();

  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'endurain_training.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE activity_tss(
            activity_id INTEGER PRIMARY KEY,
            tss REAL NOT NULL,
            duration_seconds INTEGER NOT NULL,
            if_value REAL,
            rpe INTEGER,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
      },
    );
    return _db!;
  }

  /// Рассчитать TSS для активности
  /// Основан на длительности и интенсивности
  /// Если нет пульсовых зон — оценка по типу активности
  double calculateTss(ActivityRecord activity, {int? rpe}) {
    final durationHours = activity.durationSeconds / 3600.0;
    if (durationHours <= 0) return 0;

    // Интенсивность по типу активности
    double intensityFactor = _estimateIntensityFactor(activity);

    // Если есть RPE (Rate of Perceived Exertion), корректируем
    if (rpe != null) {
      // RPE: 1=легко(0.5), 2=нормально(0.7), 3=тяжело(0.9)
      final rpeMultiplier = {1: 0.5, 2: 0.7, 3: 0.9}[rpe] ?? 0.7;
      intensityFactor = (intensityFactor + rpeMultiplier) / 2;
    }

    // Если есть пульс — используем его
    if (activity.avgHeartRate != null && activity.avgHeartRate! > 0) {
      final hrIF = _heartRateIntensityFactor(activity.avgHeartRate!);
      intensityFactor = (intensityFactor + hrIF) / 2;
    }

    // TSS = duration_hours × IF² × 100
    final tss = durationHours * intensityFactor * intensityFactor * 100;
    return max(0, min(tss, 500)); // Ограничиваем 0-500
  }

  /// Оценка интенсивности по типу активности
  double _estimateIntensityFactor(ActivityRecord activity) {
    switch (activity.kind) {
      case ActivityKind.run:
      case ActivityKind.trailRun:
      case ActivityKind.trackRun:
        return 0.75;
      case ActivityKind.treadmillRun:
      case ActivityKind.virtualRun:
        return 0.70;
      case ActivityKind.roadCycling:
      case ActivityKind.gravelCycling:
      case ActivityKind.mtbCycling:
        return 0.65;
      case ActivityKind.indoorCycling:
      case ActivityKind.virtualCycling:
        return 0.60;
      case ActivityKind.walk:
      case ActivityKind.hike:
      case ActivityKind.indoorWalk:
        return 0.35;
      case ActivityKind.yoga:
        return 0.30;
      case ActivityKind.strengthTraining:
      case ActivityKind.crossfit:
      case ActivityKind.hiit:
        return 0.80;
      case ActivityKind.indoorSwimming:
      case ActivityKind.openWaterSwimming:
        return 0.70;
      default:
        return 0.60;
    }
  }

  /// Интенсивность по пульсу (от максимального)
  double _heartRateIntensityFactor(int avgHr) {
    // Предполагаем max HR = 190 (среднее для взрослых)
    final maxHr = 190;
    final hrPercentage = avgHr / maxHr;
    // Нормализуем: 60% = 0.5 IF, 100% = 1.0 IF
    return (hrPercentage - 0.5).clamp(0.0, 0.5) * 2;
  }

  /// Сохранить TSS для активности
  Future<void> saveTss(int activityId, double tss, int durationSeconds, {double? ifValue, int? rpe}) async {
    final db = await _database();
    await db.insert('activity_tss', {
      'activity_id': activityId,
      'tss': tss,
      'duration_seconds': durationSeconds,
      'if_value': ifValue,
      'rpe': rpe,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Получить RPE для активности
  Future<int?> getRpe(int activityId) async {
    final db = await _database();
    final rows = await db.query('activity_tss', columns: ['rpe'], where: 'activity_id = ?', whereArgs: [activityId]);
    if (rows.isEmpty) return null;
    return rows.first['rpe'] as int?;
  }

  /// Рассчитать все метрики формы
  Future<TrainingMetrics> calculateMetrics() async {
    final repo = LocalActivityRepository.instance;
    final activities = await repo.getActivities();
    final now = DateTime.now();

    // Получаем TSS для каждой активности (или рассчитываем)
    final db = await _database();
    final tssRows = await db.query('activity_tss');
    final tssMap = <int, double>{};
    for (final row in tssRows) {
      tssMap[row['activity_id'] as int] = (row['tss'] as num).toDouble();
    }

    // Собираем TSS по дням за 90 дней
    final dailyTss = <DateTime, double>{};
    for (final activity in activities) {
      final daysAgo = now.difference(activity.startedAt).inDays;
      if (daysAgo > 90) continue;

      final dayKey = DateTime(activity.startedAt.year, activity.startedAt.month, activity.startedAt.day);
      final tss = tssMap[activity.id] ?? calculateTss(activity);
      dailyTss[dayKey] = (dailyTss[dayKey] ?? 0) + tss;
    }

    // CTL: 42-day EWMA
    final ctl = _calculateEwma(dailyTss, now, 42);
    // ATL: 7-day EWMA
    final atl = _calculateEwma(dailyTss, now, 7);
    // TSB = CTL - ATL
    final tsb = ctl - atl;

    // TSS за сегодня
    final todayKey = DateTime(now.year, now.month, now.day);
    final tssToday = dailyTss[todayKey] ?? 0;

    // Возраст
    final age = AppSettingsController.instance.userAge;

    // Средний пульс покоя за последние 14 ночей
    final sleepRecords = await repo.getSleepRecords();
    final recentRestHr = <int>[];
    for (final r in sleepRecords) {
      if (r.restHeartRate != null && r.restHeartRate! > 0) {
        final daysAgo = now.difference(r.date).inDays;
        if (daysAgo >= 0 && daysAgo <= 14) {
          recentRestHr.add(r.restHeartRate!);
        }
      }
    }
    final avgRestHr = recentRestHr.isNotEmpty
        ? recentRestHr.reduce((a, b) => a + b) / recentRestHr.length
        : null;

    // Дни до восстановления
    final recoveryDays = _estimateRecoveryDays(ctl, atl, tsb, age: age, avgRestHr: avgRestHr);
    
    // Оценка пульса покоя и максимального пульса
    final estimatedRestingHr = HrEstimator.estimateRestingHr(
      age: age ?? 30, // Default age 30 if not set
      sleepAvgHr: avgRestHr?.round(),
      userRestingHr: AppSettingsController.instance.userRestingHeartRate,
    );
    
    final estimatedMaxHr = HrEstimator.estimateMaxHr(
      age: age ?? 30, // Default age 30 if not set
    );

    return TrainingMetrics(
      ctl: ctl,
      atl: atl,
      tsb: tsb,
      tssToday: tssToday,
      recoveryDays: recoveryDays,
      estimatedRestingHr: estimatedRestingHr,
      estimatedMaxHr: estimatedMaxHr,
    );
  }

  /// Получить данные для графика за 30 дней
  Future<List<DailyTss>> getDailyTssChart() async {
    final repo = LocalActivityRepository.instance;
    final activities = await repo.getActivities();
    final now = DateTime.now();

    final db = await _database();
    final tssRows = await db.query('activity_tss');
    final tssMap = <int, double>{};
    for (final row in tssRows) {
      tssMap[row['activity_id'] as int] = (row['tss'] as num).toDouble();
    }

    final dailyTss = <DateTime, double>{};
    for (final activity in activities) {
      final daysAgo = now.difference(activity.startedAt).inDays;
      if (daysAgo > 30) continue;

      final dayKey = DateTime(activity.startedAt.year, activity.startedAt.month, activity.startedAt.day);
      final tss = tssMap[activity.id] ?? calculateTss(activity);
      dailyTss[dayKey] = (dailyTss[dayKey] ?? 0) + tss;
    }

    final result = <DailyTss>[];
    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateTime(date.year, date.month, date.day);
      result.add(DailyTss(dayKey, dailyTss[dayKey] ?? 0));
    }

    return result;
  }

  /// Получить CTL и ATL за 30 дней для графика
  Future<List<Map<String, dynamic>>> getFormChart() async {
    final repo = LocalActivityRepository.instance;
    final activities = await repo.getActivities();
    final now = DateTime.now();

    final db = await _database();
    final tssRows = await db.query('activity_tss');
    final tssMap = <int, double>{};
    for (final row in tssRows) {
      tssMap[row['activity_id'] as int] = (row['tss'] as num).toDouble();
    }

    final dailyTss = <DateTime, double>{};
    for (final activity in activities) {
      final daysAgo = now.difference(activity.startedAt).inDays;
      if (daysAgo > 90) continue;
      final dayKey = DateTime(activity.startedAt.year, activity.startedAt.month, activity.startedAt.day);
      final tss = tssMap[activity.id] ?? calculateTss(activity);
      dailyTss[dayKey] = (dailyTss[dayKey] ?? 0) + tss;
    }

    final result = <Map<String, dynamic>>[];
    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateTime(date.year, date.month, date.day);
      final ctl = _calculateEwma(dailyTss, dayKey, 42);
      final atl = _calculateEwma(dailyTss, dayKey, 7);
      result.add({
        'date': dayKey,
        'ctl': ctl,
        'atl': atl,
        'tsb': ctl - atl,
      });
    }

    return result;
  }

  /// EWMA (Exponentially Weighted Moving Average)
  double _calculateEwma(Map<DateTime, double> dailyTss, DateTime endDate, int periodDays) {
    final alpha = 2.0 / (periodDays + 1);
    double ewma = 0;

    for (int i = periodDays; i >= 0; i--) {
      final date = endDate.subtract(Duration(days: i));
      final dayKey = DateTime(date.year, date.month, date.day);
      final tss = dailyTss[dayKey] ?? 0;
      ewma = alpha * tss + (1 - alpha) * ewma;
    }

    return ewma;
  }

  /// Оценка дней до восстановления
  /// Учитывает TSB (баланс), ATL (острая нагрузка), возраст и пульс покоя
  int _estimateRecoveryDays(double ctl, double atl, double tsb, {int? age, double? avgRestHr}) {
    // Acute:Chronic Workload Ratio
    final acwr = ctl > 0 ? atl / ctl : (atl > 0 ? 3.0 : 0.0);

    // Already recovered
    if (tsb > 10 && acwr < 1.2) return 0;

    // Базовые дни по ACWR/TSB
    int baseDays;
    if (acwr > 2.0) {
      if (tsb > -20) baseDays = 2;
      else if (tsb > -40) baseDays = 3;
      else if (tsb > -60) baseDays = 4;
      else baseDays = 5;
    } else if (acwr > 1.5) {
      if (tsb > -10) baseDays = 1;
      else if (tsb > -25) baseDays = 2;
      else if (tsb > -40) baseDays = 3;
      else baseDays = 4;
    } else {
      if (tsb > 10) baseDays = 0;
      else if (tsb > -10) baseDays = 1;
      else if (tsb > -25) baseDays = 2;
      else if (tsb > -40) baseDays = 3;
      else baseDays = 4;
    }

    // Коррекция по возрасту: +1 день за каждые 10 лет после 30
    int ageBonus = 0;
    if (age != null && age > 30) {
      ageBonus = ((age - 30) / 10).floor();
    }

    // Коррекция по пульсу покоя:
    // Высокий пульс покоя = плохое восстановление
    // Норма: 50-65 для активных, >70 = плохо восстановлен
    int hrBonus = 0;
    if (avgRestHr != null) {
      if (avgRestHr > 75) hrBonus = 2;
      else if (avgRestHr > 70) hrBonus = 1;
      else if (avgRestHr < 50) hrBonus = -1; // Отличная форма — быстрее восстанавливается
    }

    return max(0, baseDays + ageBonus + hrBonus);
  }

  /// Auto-detect FTP (Functional Threshold Power) for cycling.
  /// Requires power data in activity points. Best 20-minute average × 0.95.
  Future<double?> detectFtp(List<ActivityRecord> cyclingActivities) async {
    final repo = LocalActivityRepository.instance;
    double? bestTwentyMinPower;

    for (final activity in cyclingActivities) {
      if (activity.durationSeconds < 1200) continue;

      final points = await repo.getPoints(activity.id!);
      final powerPoints = points
          .where((p) => p.power != null && p.power! > 0)
          .map((p) => (p.timestamp.millisecondsSinceEpoch, p.power!))
          .toList();
      if (powerPoints.length < 30) continue;

      powerPoints.sort((a, b) => a.$1.compareTo(b.$1));

      // Best rolling 20-minute (1200 s) average power
      double? bestWindow;
      int j = 0;
      for (int i = 0; i < powerPoints.length; i++) {
        final windowEnd = powerPoints[i].$1;
        final windowStart = windowEnd - 1200 * 1000;
        while (powerPoints[j].$1 < windowStart) j++;
        double sum = 0;
        int count = 0;
        for (int k = j; k <= i; k++) {
          sum += powerPoints[k].$2;
          count++;
        }
        if (count >= 30) {
          final avg = sum / count;
          if (bestWindow == null || avg > bestWindow) bestWindow = avg;
        }
      }

      if (bestWindow != null &&
          (bestTwentyMinPower == null || bestWindow > bestTwentyMinPower)) {
        bestTwentyMinPower = bestWindow;
      }
    }

    if (bestTwentyMinPower == null) return null;
    return bestTwentyMinPower * 0.95;
  }

  /// Auto-detect FTP indirectly from running data (no power meter).
  /// Uses threshold pace + estimated power from running speed.
  /// FTP_cycling ≈ FTP_running_equivalent (Coggan cross-sport)
  double? detectFtpIndirect(List<ActivityRecord> runningActivities, {double? weightKg}) {
    final thresholdPace = detectThresholdPace(runningActivities);
    if (thresholdPace == null || thresholdPace <= 0) return null;

    // Convert running pace (sec/m) to speed (km/h)
    final speedKmh = 1000.0 / (thresholdPace * 3600.0);

    // Estimate cycling power from running speed (Dr. Andrew Coggan approximation):
    // Cycling power ≈ weight × speed × CRR + 0.5 × ρ × CdA × v³
    // Simplified: running threshold pace → approximate cycling watts
    final mass = weightKg ?? 75.0;
    final crr = 0.005;
    final airDensity = 1.225;
    final cda = 0.4;
    final vMs = speedKmh / 3.6;
    final mechPower = mass * 9.81 * vMs * crr;
    final aeroPower = 0.5 * airDensity * cda * vMs * vMs * vMs;
    final runningPowerEst = (mechPower + aeroPower) / 0.25; // 25% running efficiency

    // Running power → cycling FTP approximation (roughly 1:1 for threshold efforts)
    final estimatedFtp = runningPowerEst * 0.95;
    return estimatedFtp > 0 ? estimatedFtp : null;
  }

  /// Auto-detect Threshold Pace for running.
  /// Method: best pace sustained for 20+ minutes
  double? detectThresholdPace(List<ActivityRecord> runningActivities) {
    double? bestPace; // sec per meter (lower = faster)

    for (final activity in runningActivities) {
      if (activity.distanceMeters == null || activity.distanceMeters! <= 0) continue;
      if (activity.durationSeconds < 1200) continue; // less than 20 min

      final pace = activity.durationSeconds / activity.distanceMeters!; // sec/m
      if (bestPace == null || pace < bestPace) {
        bestPace = pace;
      }
    }

    return bestPace;
  }

  /// Auto-detect LTHR (Lactate Threshold Heart Rate).
  /// Method: highest HR sustained for 30+ minutes
  int? detectLthr(List<ActivityRecord> activities) {
    int? bestHr;
    int bestDuration = 0;

    for (final activity in activities) {
      if (activity.avgHeartRate == null || activity.avgHeartRate! <= 0) continue;
      if (activity.durationSeconds < 1800) continue; // less than 30 min

      if (activity.durationSeconds > bestDuration) {
        bestDuration = activity.durationSeconds;
        bestHr = activity.avgHeartRate;
      }
    }

    return bestHr;
  }

  /// Efficiency Factor (EF) = pace per km / HR
  /// Higher = more efficient. Useful for tracking fitness improvement.
  double? calculateEfficiencyFactor(ActivityRecord activity) {
    if (activity.avgHeartRate == null || activity.avgHeartRate! <= 0) return null;
    if (activity.distanceMeters == null || activity.distanceMeters! <= 0) return null;

    final paceMinPerKm = (activity.durationSeconds / 60.0) / (activity.distanceMeters! / 1000.0);
    return paceMinPerKm / activity.avgHeartRate!;
  }

  /// Pa:HR Decoupling — aerobic decoupling percentage.
  /// Compares first-half vs second-half HR drift.
  /// > 5% = deconditioned, < 5% = well-conditioned.
  /// Simplified: compares HR in first 50% of time vs last 50%.
  double? calculateDecoupling(ActivityRecord activity, List<(int, int)> hrSamples) {
    if (hrSamples.length < 4) return null;

    final midTs = (hrSamples.first.$1 + hrSamples.last.$1) ~/ 2;
    final firstHalf = hrSamples.where((s) => s.$1 <= midTs).toList();
    final secondHalf = hrSamples.where((s) => s.$1 > midTs).toList();

    if (firstHalf.isEmpty || secondHalf.isEmpty) return null;

    final avgFirst = firstHalf.map((s) => s.$2).reduce((a, b) => a + b) / firstHalf.length;
    final avgSecond = secondHalf.map((s) => s.$2).reduce((a, b) => a + b) / secondHalf.length;

    if (avgFirst <= 0) return null;
    return ((avgSecond - avgFirst) / avgFirst) * 100;
  }

  /// Intensity Factor (IF) = normalized power / FTP
  /// IF = 1.0 for a 1-hour maximal effort.
  double? calculateIntensityFactor(double? normalizedPower, double? ftp) {
    if (normalizedPower == null || ftp == null || ftp <= 0) return null;
    return normalizedPower / ftp;
  }

  /// Normalized Power (NP) — 30-second rolling average method.
  /// Requires power samples (timestamp_ms, watts).
  double? calculateNormalizedPower(List<(int, num)> powerSamples) {
    if (powerSamples.length < 2) return null;

    powerSamples.sort((a, b) => a.$1.compareTo(b.$1));

    const windowMs = 30000;
    final rollingPowers = <double>[];
    int j = 0;
    for (int i = 0; i < powerSamples.length; i++) {
      final end = powerSamples[i].$1;
      final start = end - windowMs;
      while (powerSamples[j].$1 < start) j++;
      double sum = 0;
      int count = 0;
      for (int k = j; k <= i; k++) {
        sum += powerSamples[k].$2.toDouble();
        count++;
      }
      if (count > 0) rollingPowers.add(sum / count);
    }

    if (rollingPowers.isEmpty) return null;
    final avg4thPower =
        rollingPowers.map((p) => p * p * p * p).reduce((a, b) => a + b) / rollingPowers.length;
    return pow(avg4thPower, 0.25).toDouble();
  }
}
