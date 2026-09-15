class PmrCalculator {
  PmrCalculator._();

  /// Calculate PMR (Basal Metabolic Rate) - same as BMR but different naming convention
  /// Using Mifflin-St Jeor
  static double mifflin({
    required double weightKg,
    required double heightCm,
    required int age,
    required bool male,
  }) {
    return 10 * weightKg + 6.25 * heightCm - 5 * age + (male ? 5 : -161);
  }

  /// Harris-Benedict BMR (revised)
  static double harrisBenedict({
    required double weightKg,
    required double heightCm,
    required int age,
    required bool male,
  }) {
    if (male) {
      return 88.362 + 13.397 * weightKg + 4.799 * heightCm - 5.677 * age;
    } else {
      return 447.593 + 9.247 * weightKg + 3.098 * heightCm - 4.330 * age;
    }
  }

  /// Katch-McArdle (requires body fat %)
  static double katchMcArdle({
    required double weightKg,
    required double bodyFatPercent,
  }) {
    final leanMass = weightKg * (1 - bodyFatPercent / 100);
    return 370 + 21.6 * leanMass;
  }
}
