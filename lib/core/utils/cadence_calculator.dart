class CadenceCalculator {
  CadenceCalculator._();

  /// Calculate stride length from cadence and pace
  /// strideLength = pace(km/h) * 1000 / (cadence steps/min * 60) meters
  static double strideLength({
    required double paceSecPerKm,
    required int cadenceSpm,
  }) {
    if (paceSecPerKm <= 0 || cadenceSpm <= 0) return 0;
    final speedMs = 1000 / paceSecPerKm;
    final speedPerMin = speedMs * 60;
    return speedPerMin / cadenceSpm; // meters per step
  }

  /// Calculate cadence from pace and stride length
  static int cadence({
    required double paceSecPerKm,
    required double strideLengthMeters,
  }) {
    if (paceSecPerKm <= 0 || strideLengthMeters <= 0) return 0;
    final speedMs = 1000 / paceSecPerKm;
    final speedPerMin = speedMs * 60;
    return (speedPerMin / strideLengthMeters).round();
  }

  static String formatStride(double meters) {
    if (meters <= 0) return '-- см';
    return '${(meters * 100).round()} см';
  }
}
