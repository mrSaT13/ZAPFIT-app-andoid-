class StressScoreCalculator {
  StressScoreCalculator._();

  /// Estimate stress score based on HRV metrics
  static int calculate({
    required double? hrvRmssd,
    required double? lfHfRatio,
    required double? restingHr,
  }) {
    if (hrvRmssd == null || hrvRmssd <= 0) return 0;

    int stressScore = 0;

    // HRV-based stress (higher RMSSD = less stress)
    if (hrvRmssd >= 80) stressScore = 10;
    else if (hrvRmssd >= 60) stressScore = 25;
    else if (hrvRmssd >= 40) stressScore = 45;
    else if (hrvRmssd >= 25) stressScore = 65;
    else stressScore = 85;

    // LF/HF ratio adjustment (sympathetic/parasympathetic balance)
    if (lfHfRatio != null && lfHfRatio > 0) {
      if (lfHfRatio > 3.0) stressScore += 10;
      else if (lfHfRatio < 1.0) stressScore -= 10;
    }

    // Resting HR adjustment
    if (restingHr != null && restingHr > 70) {
      stressScore += 5;
    } else if (restingHr != null && restingHr < 55) {
      stressScore -= 5;
    }

    return stressScore.clamp(0, 100);
  }

  static String classify(int score) {
    if (score <= 25) return 'Низкий стресс';
    if (score <= 50) return 'Умеренный стресс';
    if (score <= 75) return 'Повышенный стресс';
    return 'Высокий стресс';
  }
}
