class StepsConverter {
  StepsConverter._();

  /// Convert steps to distance (km)
  static double stepsToDistanceKm(int steps, {double strideLengthCm = 75}) {
    return steps * strideLengthCm / 100000;
  }

  /// Convert steps to calories burned
  static double stepsToCalories(int steps, double weightKg, {double met = 3.5}) {
    if (steps <= 0 || weightKg <= 0) return 0;
    // ~0.04 kcal per step per kg of body weight
    return steps * 0.04 * (weightKg / 70);
  }

  /// Convert distance to steps
  static int distanceToSteps(double distanceKm, {double strideLengthCm = 75}) {
    return (distanceKm * 100000 / strideLengthCm).round();
  }

  /// Convert distance (km) to calories
  static double distanceToCalories(double distanceKm, double weightKg) {
    if (distanceKm <= 0 || weightKg <= 0) return 0;
    return distanceKm * weightKg * 1.0; // ~1 kcal per kg per km
  }

  /// Convert steps to active minutes (WHO: 100 steps/min threshold)
  static int stepsToActiveMinutes(int steps, {int thresholdSpm = 100}) {
    return steps ~/ thresholdSpm;
  }
}
