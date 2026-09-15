class HydrationNeedCalculator {
  HydrationNeedCalculator._();

  /// Calculate daily hydration need (ml) based on weight, activity, weather
  static int dailyNeedMl({
    required double weightKg,
    int activityMinutes = 0,
    bool hotWeather = false,
  }) {
    if (weightKg <= 0) return 2000;
    // Base: 30-35 ml per kg
    double base = weightKg * 33;
    // Add 500-1000 ml per hour of exercise
    base += (activityMinutes / 60.0) * 750;
    // Hot weather adds ~500 ml
    if (hotWeather) base += 500;
    return base.round();
  }

  /// Pre-exercise hydration (ml to drink 2h before)
  static int preExerciseMl(double weightKg) {
    return (weightKg * 5).round().clamp(200, 600);
  }

  /// Per-exercise hydration (ml per 15-20 min interval)
  static int duringExercisePerIntervalMl(double weightKg, int exerciseMinutes) {
    if (exerciseMinutes <= 30) return 150;
    if (exerciseMinutes <= 60) return 200;
    return 250;
  }

  /// Post-exercise rehydration (150% of fluid lost)
  static int postExerciseMl(double weightLostKg) {
    return (weightLostKg * 1000 * 1.5).round();
  }
}
