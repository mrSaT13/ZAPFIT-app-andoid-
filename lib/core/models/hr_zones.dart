import 'package:flutter/material.dart';

enum HeartRateZone {
  warmUp,
  fatBurn,
  cardio,
  endurance,
  anaerobic,
}

class HrZoneInfo {
  final HeartRateZone zone;
  final String name;
  final String nameRu;
  final int minBpm;
  final int maxBpm;
  final Color color;
  final double minPct;
  final double maxPct;

  const HrZoneInfo({
    required this.zone,
    required this.name,
    required this.nameRu,
    required this.minBpm,
    required this.maxBpm,
    required this.color,
    required this.minPct,
    required this.maxPct,
  });
}

class HeartRateZones {
  final int maxHeartRate;
  final int? restingHeartRate;
  final List<HrZoneInfo> zones;

  const HeartRateZones({
    required this.maxHeartRate,
    this.restingHeartRate,
    required this.zones,
  });

  /// Calculate max HR using Tanaka formula (more accurate than 220-age)
  static int calculateMaxHr(int age, {bool useTanaka = true}) {
    if (useTanaka) {
      return (208 - 0.7 * age).round();
    }
    return 220 - age;
  }

  /// Create zones from age (standard 5-zone model)
  factory HeartRateZones.fromAge(int age, {int? restingHr}) {
    final maxHr = calculateMaxHr(age);
    return HeartRateZones.fromMaxHr(maxHr, restingHr: restingHr);
  }

  /// Create zones using Karvonen formula (HR Reserve method).
  /// More accurate than simple %maxHR because accounts for individual resting HR.
  /// HR Reserve = HRmax - HRrest
  /// Target HR = HR Reserve × %intensity + HRrest
  /// Falls back to %maxHR if resting HR is not provided.
  factory HeartRateZones.fromMaxHr(int maxHr, {int? restingHr}) {
    if (restingHr != null && restingHr > 0 && restingHr < maxHr) {
      return HeartRateZones.fromKarvonen(maxHr: maxHr, restingHr: restingHr);
    }
    return HeartRateZones._fromMaxHrFallback(maxHr);
  }

  /// Karvonen zones: HR Reserve method (more accurate)
  /// Zone 1: 50-60% HRR + HRrest
  /// Zone 2: 60-70% HRR + HRrest
  /// Zone 3: 70-80% HRR + HRrest
  /// Zone 4: 80-90% HRR + HRrest
  /// Zone 5: 90-100% HRR + HRrest
  factory HeartRateZones.fromKarvonen({required int maxHr, required int restingHr}) {
    final hrr = maxHr - restingHr; // Heart Rate Reserve

    int karvonenBpm(double pct) => (restingHr + hrr * pct).round();

    final zones = [
      HrZoneInfo(
        zone: HeartRateZone.warmUp,
        name: 'Warm Up',
        nameRu: 'Разминка',
        minBpm: karvonenBpm(0.50),
        maxBpm: karvonenBpm(0.60),
        color: const Color(0xFF90CAF9),
        minPct: 0.50,
        maxPct: 0.60,
      ),
      HrZoneInfo(
        zone: HeartRateZone.fatBurn,
        name: 'Fat Burn',
        nameRu: 'Сжигание жира',
        minBpm: karvonenBpm(0.60),
        maxBpm: karvonenBpm(0.70),
        color: const Color(0xFFA5D6A7),
        minPct: 0.60,
        maxPct: 0.70,
      ),
      HrZoneInfo(
        zone: HeartRateZone.cardio,
        name: 'Cardio',
        nameRu: 'Кардио',
        minBpm: karvonenBpm(0.70),
        maxBpm: karvonenBpm(0.80),
        color: const Color(0xFFFFF176),
        minPct: 0.70,
        maxPct: 0.80,
      ),
      HrZoneInfo(
        zone: HeartRateZone.endurance,
        name: 'Endurance',
        nameRu: 'Выносливость',
        minBpm: karvonenBpm(0.80),
        maxBpm: karvonenBpm(0.90),
        color: const Color(0xFFFFAB91),
        minPct: 0.80,
        maxPct: 0.90,
      ),
      HrZoneInfo(
        zone: HeartRateZone.anaerobic,
        name: 'Anaerobic',
        nameRu: 'Анаэробная',
        minBpm: karvonenBpm(0.90),
        maxBpm: maxHr,
        color: const Color(0xFFEF9A9A),
        minPct: 0.90,
        maxPct: 1.00,
      ),
    ];

    return HeartRateZones(
      maxHeartRate: maxHr,
      restingHeartRate: restingHr,
      zones: zones,
    );
  }

  /// Fallback: simple %maxHR (used when resting HR is unknown)
  factory HeartRateZones._fromMaxHrFallback(int maxHr) {
    final zones = [
      HrZoneInfo(
        zone: HeartRateZone.warmUp,
        name: 'Warm Up',
        nameRu: 'Разминка',
        minBpm: (maxHr * 0.50).round(),
        maxBpm: (maxHr * 0.60).round(),
        color: const Color(0xFF90CAF9),
        minPct: 0.50,
        maxPct: 0.60,
      ),
      HrZoneInfo(
        zone: HeartRateZone.fatBurn,
        name: 'Fat Burn',
        nameRu: 'Сжигание жира',
        minBpm: (maxHr * 0.60).round(),
        maxBpm: (maxHr * 0.70).round(),
        color: const Color(0xFFA5D6A7),
        minPct: 0.60,
        maxPct: 0.70,
      ),
      HrZoneInfo(
        zone: HeartRateZone.cardio,
        name: 'Cardio',
        nameRu: 'Кардио',
        minBpm: (maxHr * 0.70).round(),
        maxBpm: (maxHr * 0.80).round(),
        color: const Color(0xFFFFF176),
        minPct: 0.70,
        maxPct: 0.80,
      ),
      HrZoneInfo(
        zone: HeartRateZone.endurance,
        name: 'Endurance',
        nameRu: 'Выносливость',
        minBpm: (maxHr * 0.80).round(),
        maxBpm: (maxHr * 0.90).round(),
        color: const Color(0xFFFFAB91),
        minPct: 0.80,
        maxPct: 0.90,
      ),
      HrZoneInfo(
        zone: HeartRateZone.anaerobic,
        name: 'Anaerobic',
        nameRu: 'Анаэробная',
        minBpm: (maxHr * 0.90).round(),
        maxBpm: maxHr,
        color: const Color(0xFFEF9A9A),
        minPct: 0.90,
        maxPct: 1.00,
      ),
    ];

    return HeartRateZones(
      maxHeartRate: maxHr,
      zones: zones,
    );
  }

  /// Get zone for a given HR value
  HrZoneInfo getZone(int bpm) {
    for (int i = zones.length - 1; i >= 0; i--) {
      if (bpm >= zones[i].minBpm) return zones[i];
    }
    return zones.first;
  }

  /// Get zone index (0-4) for a given HR value
  int getZoneIndex(int bpm) {
    for (int i = zones.length - 1; i >= 0; i--) {
      if (bpm >= zones[i].minBpm) return i;
    }
    return 0;
  }

  /// Calculate time in each zone from a list of HR samples
  /// Each sample is (timestamp_ms, bpm)
  Map<HeartRateZone, int> calculateZoneDistribution(List<(int, int)> samples) {
    final distribution = <HeartRateZone, int>{
      HeartRateZone.warmUp: 0,
      HeartRateZone.fatBurn: 0,
      HeartRateZone.cardio: 0,
      HeartRateZone.endurance: 0,
      HeartRateZone.anaerobic: 0,
    };

    if (samples.length < 2) return distribution;

    for (int i = 1; i < samples.length; i++) {
      final prevTs = samples[i - 1].$1;
      final currTs = samples[i].$1;
      final bpm = samples[i].$2;
      final durationMs = currTs - prevTs;
      final zone = getZone(bpm).zone;
      distribution[zone] = (distribution[zone] ?? 0) + durationMs;
    }

    return distribution;
  }

  /// Calculate zone distribution in minutes from HR records
  Map<HeartRateZone, int> calculateZoneDistributionFromRecords(
    List<Map<String, dynamic>> records, {
    required int Function(Map<String, dynamic>) bpmGetter,
    required int Function(Map<String, dynamic>) timestampGetter,
  }) {
    final samples = records.map((r) => (timestampGetter(r), bpmGetter(r))).toList();
    samples.sort((a, b) => a.$1.compareTo(b.$1));

    final result = calculateZoneDistribution(samples);
    // Convert ms to minutes
    return result.map((k, v) => MapEntry(k, (v / 60000).round()));
  }
}
