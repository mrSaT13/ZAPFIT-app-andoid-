class FitnessAgeCalculator {
  FitnessAgeCalculator._();

  /// Estimate biological fitness age based on VO2max
  static int estimate({
    required double vo2max,
    required int chronologicalAge,
    required bool male,
  }) {
    if (vo2max <= 0) return chronologicalAge;

    // Average VO2max for age groups (ml/kg/min) - Cooper Institute data
    final maleNorms = {
      20: 51.0, 25: 50.0, 30: 48.2, 35: 46.8, 40: 44.5,
      45: 42.4, 50: 41.0, 55: 39.5, 60: 37.8, 65: 36.0,
      70: 34.5, 75: 33.0, 80: 31.0,
    };
    final femaleNorms = {
      20: 40.0, 25: 39.0, 30: 38.0, 35: 37.0, 40: 36.0,
      45: 35.0, 50: 34.0, 55: 33.0, 60: 32.0, 65: 31.0,
      70: 30.0, 75: 29.0, 80: 28.0,
    };

    final norms = male ? maleNorms : femaleNorms;
    // Find age where user's VO2max matches average
    int estimatedAge = 80;
    for (final entry in norms.entries) {
      if (vo2max >= entry.value) {
        estimatedAge = entry.key;
        break;
      }
    }

    return estimatedAge.clamp(15, 85);
  }
}
