class EpocCalculator {
  EpocCalculator._();

  /// Estimate EPOC (Excess Post-exercise Oxygen Consumption)
  /// Based on duration and intensity (%HRmax)
  static double estimate({
    required int durationMinutes,
    required double avgHrPercentMax,
    required int age,
  }) {
    if (durationMinutes <= 0 || avgHrPercentMax <= 0) return 0;
    // Simplified model: EPOC (kcal) ≈ duration × intensity² × age_factor
    final intensity = avgHrPercentMax.clamp(0.0, 1.0);
    final ageFactor = age > 40 ? 0.85 : 1.0;
    return durationMinutes * intensity * intensity * 3.5 * ageFactor;
  }

  /// Classification of EPOC effect
  static String classify(double epocKcal) {
    if (epocKcal <= 0) return 'Нет данных';
    if (epocKcal < 50) return 'Минимальный';
    if (epocKcal < 150) return 'Умеренный';
    if (epocKcal < 300) return 'Высокий';
    return 'Очень высокий';
  }
}
