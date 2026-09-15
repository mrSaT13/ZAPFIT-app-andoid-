class SleepNeedCalculator {
  SleepNeedCalculator._();

  /// Calculate recommended sleep duration based on age
  static int recommendedHours(int ageYears) {
    if (ageYears < 0) return 8;
    if (ageYears <= 3) return 14;
    if (ageYears <= 5) return 13;
    if (ageYears <= 12) return 10;
    if (ageYears <= 17) return 9;
    if (ageYears <= 64) return 8;
    return 7;
  }

  /// Calculate sleep debt
  static double sleepDebtHours({
    required List<int> recentSleepHours,
    required int ageYears,
  }) {
    final needed = recommendedHours(ageYears);
    double debt = 0;
    for (final hours in recentSleepHours) {
      debt += needed - hours;
    }
    return debt.clamp(0.0, double.infinity);
  }
}
