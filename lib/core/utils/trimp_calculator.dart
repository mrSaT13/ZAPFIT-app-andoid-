class TrimpCalculator {
  TrimpCalculator._();

  /// TRIMP (Banister) - Heart Rate Reserve based TRIMP
  /// Uses exponential weight for high-intensity sessions
  static double banister({
    required int durationMinutes,
    required double avgHr,
    required double restingHr,
    required double maxHr,
  }) {
    if (durationMinutes <= 0 || avgHr <= 0 || maxHr <= restingHr) return 0;
    final hrReserve = (avgHr - restingHr) / (maxHr - restingHr);
    return durationMinutes * hrReserve * 0.64 * Math.exp(1.92 * hrReserve);
  }

  /// TRIMP (Edwards) - Simple linear TRIMP
  /// Uses %HR zones (50-60=1, 60-70=2, 70-80=3, 80-90=4, 90-100=5)
  /// TRIMP = Σ (time_in_zone_minutes × zone_weight)
  static double edwards({
    required int durationMinutes,
    required List<double> zoneTimesMinutes,
  }) {
    if (zoneTimesMinutes.length != 5) return 0;
    double sum = 0;
    for (int i = 0; i < 5; i++) {
      sum += zoneTimesMinutes[i] * (i + 1);
    }
    return sum;
  }

  /// TRIMP based on heart rate only (simplified)
  static double simplified({
    required int durationMinutes,
    required double avgHr,
    required double maxHr,
  }) {
    if (durationMinutes <= 0 || avgHr <= 0 || maxHr <= 0) return 0;
    final hrPercent = avgHr / maxHr;
    return durationMinutes * hrPercent;
  }

  /// HR-based TSS (hrTSS)
  /// Standard: hrTSS = duration_hours × IF_hr² × 100,
  /// where IF_hr = (avgHR - restHR) / (maxHR - restHR)
  static double hrTss({
    required int durationMinutes,
    required double avgHr,
    required double restingHr,
    required double maxHr,
  }) {
    if (durationMinutes <= 0 || maxHr <= restingHr) return 0;
    final ifHr = (avgHr - restingHr) / (maxHr - restingHr);
    final durationHours = durationMinutes / 60.0;
    return durationHours * ifHr * ifHr * 100;
  }
}

class Math {
  static double exp(double x) {
    // Taylor series approximation of e^x
    double sum = 1.0;
    double term = 1.0;
    for (int i = 1; i < 20; i++) {
      term *= x / i;
      sum += term;
    }
    return sum;
  }
}
