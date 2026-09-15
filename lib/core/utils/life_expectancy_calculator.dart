class LifeExpectancyCalculator {
  LifeExpectancyCalculator._();

  /// Estimate remaining life expectancy based on current age and health factors
  static double estimate({
    required int ageYears,
    required bool male,
    double? vo2max,
    int? restingHr,
    bool smoker = false,
  }) {
    // Base life expectancy (WHO 2023 averages)
    double base = male ? 73.0 : 79.0;

    // VO2max adjustment
    if (vo2max != null && vo2max > 0) {
      if (vo2max >= 50) base += 4;
      else if (vo2max >= 40) base += 2;
      else if (vo2max < 30) base -= 4;
      else if (vo2max < 35) base -= 2;
    }

    // Resting HR adjustment
    if (restingHr != null && restingHr > 0) {
      if (restingHr < 55) base += 1;
      else if (restingHr > 80) base -= 2;
    }

    // Smoking
    if (smoker) base -= 8;

    return (base - ageYears).clamp(0.0, 100.0);
  }
}
