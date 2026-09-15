class SufferScoreCalculator {
  SufferScoreCalculator._();

  /// Calculate Suffer Score (0-100) based on time in HR zones
  /// Inspired by TrainerRoad / Strava suffer score
  static int calculate({
    required List<double> zoneMinutes, // minutes in zones Z1-Z5
    required int durationMinutes,
  }) {
    if (zoneMinutes.isEmpty || durationMinutes <= 0) return 0;

    // Weight per zone: 0, 1, 2, 3, 4, 5
    double weightedSum = 0;
    for (int i = 0; i < zoneMinutes.length && i < 5; i++) {
      weightedSum += zoneMinutes[i] * (i + 1);
    }

    if (weightedSum <= 0) return 0;
    final score = (weightedSum / durationMinutes * 20).round();
    return score.clamp(0, 100);
  }

  static String classify(int score) {
    if (score <= 15) return 'Лёгкая тренировка';
    if (score <= 35) return 'Умеренная';
    if (score <= 60) return 'Тяжёлая';
    return 'Очень тяжёлая';
  }
}
