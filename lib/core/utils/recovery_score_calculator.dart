class RecoveryScoreCalculator {
  RecoveryScoreCalculator._();

  /// Estimate recovery score (0-100) based on HRV, resting HR, sleep
  static int calculate({
    required double? hrvRmssd,
    required double? restingHr,
    required int sleepScore,
    required double? previousDayLoad,
  }) {
    int score = 0;
    int factors = 0;

    // HRV component (30 points)
    if (hrvRmssd != null && hrvRmssd > 0) {
      if (hrvRmssd >= 60) score += 30;
      else if (hrvRmssd >= 45) score += 24;
      else if (hrvRmssd >= 30) score += 18;
      else score += 10;
      factors++;
    }

    // Resting HR component (25 points)
    if (restingHr != null && restingHr > 0) {
      if (restingHr < 55) score += 25;
      else if (restingHr < 60) score += 21;
      else if (restingHr < 65) score += 17;
      else if (restingHr < 75) score += 12;
      else score += 6;
      factors++;
    }

    // Sleep component (25 points)
    if (sleepScore > 0) {
      score += (sleepScore * 25 / 100).round();
      factors++;
    }

    // Load recovery component (20 points)
    if (previousDayLoad != null && previousDayLoad > 0) {
      if (previousDayLoad < 30) score += 20;
      else if (previousDayLoad < 60) score += 16;
      else if (previousDayLoad < 90) score += 10;
      else score += 4;
      factors++;
    }

    if (factors == 0) return 0;
    return score.clamp(0, 100);
  }

  static String classify(int score) {
    if (score >= 80) return 'Полностью восстановлен';
    if (score >= 60) return 'Хорошее восстановление';
    if (score >= 40) return 'Частичное восстановление';
    return 'Нужен отдых';
  }
}
