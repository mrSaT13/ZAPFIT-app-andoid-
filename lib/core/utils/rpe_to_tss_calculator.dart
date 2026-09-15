class RpeToTssCalculator {
  RpeToTssCalculator._();

  /// Convert RPE (Rate of Perceived Exertion 1-10) to estimated TSS
  /// Based on: TSS = duration(min) × (RPE/10)² × 100/60
  static double convert({
    required int durationMinutes,
    required int rpe, // 1-10 Borg scale
  }) {
    if (durationMinutes <= 0 || rpe <= 0 || rpe > 10) return 0;
    final intensityFactor = rpe / 10.0;
    return durationMinutes * intensityFactor * intensityFactor * 100 / 60;
  }

  /// Convert RPE to IF (Intensity Factor) approximation
  static double rpeToIf(int rpe) {
    if (rpe <= 0 || rpe > 10) return 0;
    return 0.5 + rpe * 0.05; // RPE 1 → 0.55, RPE 10 → 1.0
  }
}
