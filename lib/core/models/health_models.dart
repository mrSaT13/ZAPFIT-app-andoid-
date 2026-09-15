class WeightRecord {
  final int? id;
  final double weight;
  final DateTime date;
  final double? bmi;
  final bool isSynced;
  final double? bodyFatPercentage;
  final double? muscleMassKg;
  final double? boneMassKg;
  final double? bodyWaterPercentage;
  final int? visceralFatLevel;
  final int? bmr;
  final int? bodyScore;

  WeightRecord({
    this.id,
    required this.weight,
    required this.date,
    this.bmi,
    this.isSynced = false,
    this.bodyFatPercentage,
    this.muscleMassKg,
    this.boneMassKg,
    this.bodyWaterPercentage,
    this.visceralFatLevel,
    this.bmr,
    this.bodyScore,
  });

  WeightRecord copyWith({
    int? id,
    double? weight,
    DateTime? date,
    double? bmi,
    bool? isSynced,
    double? bodyFatPercentage,
    double? muscleMassKg,
    double? boneMassKg,
    double? bodyWaterPercentage,
    int? visceralFatLevel,
    int? bmr,
    int? bodyScore,
  }) => WeightRecord(
    id: id ?? this.id,
    weight: weight ?? this.weight,
    date: date ?? this.date,
    bmi: bmi ?? this.bmi,
    isSynced: isSynced ?? this.isSynced,
    bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
    muscleMassKg: muscleMassKg ?? this.muscleMassKg,
    boneMassKg: boneMassKg ?? this.boneMassKg,
    bodyWaterPercentage: bodyWaterPercentage ?? this.bodyWaterPercentage,
    visceralFatLevel: visceralFatLevel ?? this.visceralFatLevel,
    bmr: bmr ?? this.bmr,
    bodyScore: bodyScore ?? this.bodyScore,
  );

  Map<String, dynamic> toJson() {
    return {
      'weight': weight,
      'date': date.toIso8601String().split('T')[0],
      if (bmi != null) 'bmi': bmi,
      if (bodyFatPercentage != null) 'body_fat': bodyFatPercentage,
      if (muscleMassKg != null) 'muscle_mass': muscleMassKg,
      if (boneMassKg != null) 'bone_mass': boneMassKg,
      if (bodyWaterPercentage != null) 'body_water': bodyWaterPercentage,
      if (visceralFatLevel != null) 'visceral_fat': visceralFatLevel,
      if (bmr != null && bmr! <= 120) 'metabolic_age': bmr,
      if (bodyScore != null) 'physique_rating': bodyScore,
    };
  }

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      id: json['id'] as int?,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      date: _parseDate(json['date'] ?? json['created_at']),
      bmi: (json['bmi'] as num?)?.toDouble(),
      bodyFatPercentage: (json['body_fat'] as num?)?.toDouble(),
      muscleMassKg: (json['muscle_mass'] as num?)?.toDouble(),
      boneMassKg: (json['bone_mass'] as num?)?.toDouble(),
      bodyWaterPercentage: (json['body_water'] as num?)?.toDouble(),
      visceralFatLevel: (json['visceral_fat'] as num?)?.toInt(),
      bmr: (json['metabolic_age'] as num?)?.toInt(),
      bodyScore: (json['physique_rating'] as num?)?.toInt(),
      isSynced: true,
    );
  }
}

class SleepRecord {
  final int? id;
  final DateTime date;
  final int totalSleepSeconds;
  final int deepSleepSeconds;
  final int lightSleepSeconds;
  final int remSleepSeconds;
  final int awakeSleepSeconds;
  final int? sleepScoreOverall;
  final int? restHeartRate;
  final int? avgHeartRate;
  final int? minHeartRate;
  final int? maxHeartRate;
  final int? turnOverCount;
  final int? intoSleepCount;
  final int? lazyBedCount;
  final int? dreamTime;
  final int? sleepFeeling;
  final DateTime? sleepStartTime;
  final DateTime? sleepEndTime;
  final bool isSynced;

  SleepRecord({
    this.id,
    required this.date,
    required this.totalSleepSeconds,
    this.deepSleepSeconds = 0,
    this.lightSleepSeconds = 0,
    this.remSleepSeconds = 0,
    this.awakeSleepSeconds = 0,
    this.sleepScoreOverall,
    this.restHeartRate,
    this.avgHeartRate,
    this.minHeartRate,
    this.maxHeartRate,
    this.turnOverCount,
    this.intoSleepCount,
    this.lazyBedCount,
    this.dreamTime,
    this.sleepFeeling,
    this.sleepStartTime,
    this.sleepEndTime,
    this.isSynced = false,
  });

  SleepRecord copyWith({
    int? id,
    DateTime? date,
    int? totalSleepSeconds,
    int? deepSleepSeconds,
    int? lightSleepSeconds,
    int? remSleepSeconds,
    int? awakeSleepSeconds,
    int? sleepScoreOverall,
    int? restHeartRate,
    int? avgHeartRate,
    int? minHeartRate,
    int? maxHeartRate,
    int? turnOverCount,
    int? intoSleepCount,
    int? lazyBedCount,
    int? dreamTime,
    int? sleepFeeling,
    DateTime? sleepStartTime,
    DateTime? sleepEndTime,
    bool? isSynced,
  }) => SleepRecord(
    id: id ?? this.id,
    date: date ?? this.date,
    totalSleepSeconds: totalSleepSeconds ?? this.totalSleepSeconds,
    deepSleepSeconds: deepSleepSeconds ?? this.deepSleepSeconds,
    lightSleepSeconds: lightSleepSeconds ?? this.lightSleepSeconds,
    remSleepSeconds: remSleepSeconds ?? this.remSleepSeconds,
    awakeSleepSeconds: awakeSleepSeconds ?? this.awakeSleepSeconds,
    sleepScoreOverall: sleepScoreOverall ?? this.sleepScoreOverall,
    restHeartRate: restHeartRate ?? this.restHeartRate,
    avgHeartRate: avgHeartRate ?? this.avgHeartRate,
    minHeartRate: minHeartRate ?? this.minHeartRate,
    maxHeartRate: maxHeartRate ?? this.maxHeartRate,
    turnOverCount: turnOverCount ?? this.turnOverCount,
    intoSleepCount: intoSleepCount ?? this.intoSleepCount,
    lazyBedCount: lazyBedCount ?? this.lazyBedCount,
    dreamTime: dreamTime ?? this.dreamTime,
    sleepFeeling: sleepFeeling ?? this.sleepFeeling,
    sleepStartTime: sleepStartTime ?? this.sleepStartTime,
    sleepEndTime: sleepEndTime ?? this.sleepEndTime,
    isSynced: isSynced ?? this.isSynced,
  );

  Map<String, dynamic> toJson() {
    final start = sleepStartTime ?? date.subtract(const Duration(hours: 8));
    final end = sleepEndTime ?? date;
    return {
      'date': date.toIso8601String().split('T')[0],
      'total_sleep_seconds': totalSleepSeconds,
      'deep_sleep_seconds': deepSleepSeconds,
      'light_sleep_seconds': lightSleepSeconds,
      'rem_sleep_seconds': remSleepSeconds,
      'awake_sleep_seconds': awakeSleepSeconds,
      'sleep_start_time_gmt': start.toUtc().toIso8601String(),
      'sleep_end_time_gmt': end.toUtc().toIso8601String(),
      if (sleepScoreOverall != null) 'sleep_score_overall': sleepScoreOverall,
      if (restHeartRate != null) 'resting_heart_rate': restHeartRate,
      if (avgHeartRate != null) 'avg_heart_rate': avgHeartRate,
      if (minHeartRate != null) 'min_heart_rate': minHeartRate,
      if (maxHeartRate != null) 'max_heart_rate': maxHeartRate,
      if (turnOverCount != null) 'turn_over_count': turnOverCount,
      if (intoSleepCount != null) 'into_sleep_count': intoSleepCount,
      if (lazyBedCount != null) 'lazy_bed_count': lazyBedCount,
      if (dreamTime != null) 'dream_time': dreamTime,
      if (sleepFeeling != null) 'sleep_feeling': sleepFeeling,
    };
  }

  factory SleepRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      try {
        final dt = DateTime.parse(v.toString());
        return dt.isUtc ? dt.toLocal() : dt;
      } catch (_) { return null; }
    }
    return SleepRecord(
      id: json['id'] as int?,
      date: _parseDate(json['date']),
      totalSleepSeconds: (json['total_sleep_seconds'] as num?)?.toInt() ?? 0,
      deepSleepSeconds: (json['deep_sleep_seconds'] as num?)?.toInt() ?? 0,
      lightSleepSeconds: (json['light_sleep_seconds'] as num?)?.toInt() ?? 0,
      remSleepSeconds: (json['rem_sleep_seconds'] as num?)?.toInt() ?? 0,
      awakeSleepSeconds: (json['awake_sleep_seconds'] as num?)?.toInt() ?? 0,
      sleepScoreOverall: (json['sleep_score_overall'] as num?)?.toInt(),
      restHeartRate: (json['rest_heart_rate'] as num?)?.toInt(),
      avgHeartRate: (json['avg_heart_rate'] as num?)?.toInt(),
      minHeartRate: (json['min_heart_rate'] as num?)?.toInt(),
      maxHeartRate: (json['max_heart_rate'] as num?)?.toInt(),
      turnOverCount: (json['turn_over_count'] as num?)?.toInt(),
      intoSleepCount: (json['into_sleep_count'] as num?)?.toInt(),
      lazyBedCount: (json['lazy_bed_count'] as num?)?.toInt(),
      dreamTime: (json['dream_time'] as num?)?.toInt(),
      sleepFeeling: (json['sleep_feeling'] as num?)?.toInt(),
      sleepStartTime: parseDt(json['sleep_start_time_gmt'] ?? json['sleep_start_time']),
      sleepEndTime: parseDt(json['sleep_end_time_gmt'] ?? json['sleep_end_time']),
      isSynced: true,
    );
  }
}

class WaterRecord {
  final int? id;
  final DateTime date;
  final double amountMl;
  final bool isSynced;

  WaterRecord({
    this.id,
    required this.date,
    required this.amountMl,
    this.isSynced = false,
  });

  WaterRecord copyWith({
    int? id,
    DateTime? date,
    double? amountMl,
    bool? isSynced,
  }) => WaterRecord(
    id: id ?? this.id,
    date: date ?? this.date,
    amountMl: amountMl ?? this.amountMl,
    isSynced: isSynced ?? this.isSynced,
  );

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0], // API expects YYYY-MM-DD
      'amount_ml': amountMl,
    };
  }

  factory WaterRecord.fromJson(Map<String, dynamic> json) {
    return WaterRecord(
      id: json['id'] as int?,
      date: _parseDate(json['date']),
      amountMl: (json['amount_ml'] as num?)?.toDouble() ?? 0.0,
      isSynced: true,
    );
  }
}

class StepsRecord {
  final int? id;
  final DateTime date;
  final int steps;
  final double? distanceMeters;
  final double? calories;
  final int? runDistanceMeters;
  final int? walkDistanceMeters;
  final double? runCalories;
  final double? walkCalories;
  final int? activeMinutes;
  final bool isSynced;

  StepsRecord({
    this.id,
    required this.date,
    required this.steps,
    this.distanceMeters,
    this.calories,
    this.runDistanceMeters,
    this.walkDistanceMeters,
    this.runCalories,
    this.walkCalories,
    this.activeMinutes,
    this.isSynced = false,
  });

  StepsRecord copyWith({
    int? id,
    DateTime? date,
    int? steps,
    double? distanceMeters,
    double? calories,
    int? runDistanceMeters,
    int? walkDistanceMeters,
    double? runCalories,
    double? walkCalories,
    int? activeMinutes,
    bool? isSynced,
  }) => StepsRecord(
    id: id ?? this.id,
    date: date ?? this.date,
    steps: steps ?? this.steps,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    calories: calories ?? this.calories,
    runDistanceMeters: runDistanceMeters ?? this.runDistanceMeters,
    walkDistanceMeters: walkDistanceMeters ?? this.walkDistanceMeters,
    runCalories: runCalories ?? this.runCalories,
    walkCalories: walkCalories ?? this.walkCalories,
    activeMinutes: activeMinutes ?? this.activeMinutes,
    isSynced: isSynced ?? this.isSynced,
  );

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'steps': steps,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (calories != null) 'calories': calories,
      if (runDistanceMeters != null) 'run_distance_meters': runDistanceMeters,
      if (walkDistanceMeters != null) 'walk_distance_meters': walkDistanceMeters,
      if (runCalories != null) 'run_calories': runCalories,
      if (walkCalories != null) 'walk_calories': walkCalories,
      if (activeMinutes != null) 'active_minutes': activeMinutes,
    };
  }

  factory StepsRecord.fromJson(Map<String, dynamic> json) {
    return StepsRecord(
      id: json['id'] as int?,
      date: _parseDate(json['date']),
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      calories: (json['calories'] as num?)?.toDouble(),
      runDistanceMeters: (json['run_distance_meters'] as num?)?.toInt(),
      walkDistanceMeters: (json['walk_distance_meters'] as num?)?.toInt(),
      runCalories: (json['run_calories'] as num?)?.toDouble(),
      walkCalories: (json['walk_calories'] as num?)?.toDouble(),
      activeMinutes: (json['active_minutes'] as num?)?.toInt(),
      isSynced: true,
    );
  }

  /// Estimated distance from steps (avg stride ~0.75m)
  double get estimatedDistanceMeters => steps * 0.75;
  /// Estimated calories from steps (avg ~0.04 kcal/step)
  double get estimatedCalories => steps * 0.04;
}

class NutritionRecord {
  final int? id;
  final DateTime date;
  final int calories;
  final bool isSynced;

  NutritionRecord({this.id, required this.date, required this.calories, this.isSynced = false});

  factory NutritionRecord.fromJson(Map<String, dynamic> json) => NutritionRecord(
    id: json['id'] as int?,
    date: _parseDate(json['date']),
    calories: (json['calories'] as num?)?.toInt() ?? 0,
    isSynced: true,
  );
}

class HealthDashboard {
  final SleepRecord? latestSleep;
  final WeightRecord? latestWeight;
  final int todaySteps;
  final double todayWaterMl;
  final bool todayNutrition;
  final int avgHeartRateLast7Days;

  HealthDashboard({
    this.latestSleep,
    this.latestWeight,
    this.todaySteps = 0,
    this.todayWaterMl = 0.0,
    this.todayNutrition = false,
    this.avgHeartRateLast7Days = 0,
  });

  factory HealthDashboard.fromJson(Map<String, dynamic> json) {
    return HealthDashboard(
      latestSleep: (json['sleep'] is Map) ? SleepRecord.fromJson(Map<String, dynamic>.from(json['sleep'] as Map)) : null,
      latestWeight: (json['weight'] is Map) ? WeightRecord.fromJson(Map<String, dynamic>.from(json['weight'] as Map)) : null,
      todaySteps: (json['steps'] is Map) ? ((json['steps'] as Map)['steps'] as int? ?? 0) : 0,
      todayWaterMl: (json['water'] is Map) ? ((json['water'] as Map)['amount_ml'] as num?)?.toDouble() ?? 0.0 : 0.0,
      todayNutrition: false,
    );
  }
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return DateTime.now();
  }
}

class HeartRateRecord {
  final int? id;
  final DateTime timestamp;
  final int bpm;
  final String source;
  final bool isSynced;

  const HeartRateRecord({
    this.id,
    required this.timestamp,
    required this.bpm,
    this.source = 'health_connect',
    this.isSynced = false,
  });

  HeartRateRecord copyWith({
    int? id,
    DateTime? timestamp,
    int? bpm,
    String? source,
    bool? isSynced,
  }) => HeartRateRecord(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    bpm: bpm ?? this.bpm,
    source: source ?? this.source,
    isSynced: isSynced ?? this.isSynced,
  );

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'timestamp_ms': timestamp.millisecondsSinceEpoch,
      'bpm': bpm,
      'source': source,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory HeartRateRecord.fromMap(Map<String, Object?> map) {
    return HeartRateRecord(
      id: map['id'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      bpm: (map['bpm'] as num?)?.toInt() ?? 0,
      source: map['source'] as String? ?? 'health_connect',
      isSynced: (map['is_synced'] as num?)?.toInt() == 1,
    );
  }
}
