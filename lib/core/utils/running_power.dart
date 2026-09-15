class RunningPowerCalculator {
  RunningPowerCalculator._();

  /// Estimate running power (Watts) from pace and body weight
  /// Based on: Power = mass × g × velocity × CRR + 0.5 × ρ × CdA × velocity³
  /// Simplified formula: P = M × g × v × (CRR + slope) + 0.5 × ρ × CdA × v³
  static double estimate({
    required double paceSecPerKm,
    required double weightKg,
    double slope = 0.0, // gradient (0 = flat)
    double crr = 0.005, // coefficient of rolling resistance
  }) {
    if (paceSecPerKm <= 0 || weightKg <= 0) return 0;
    final velocity = 1000 / paceSecPerKm; // m/s
    final g = 9.81;
    final airDensity = 1.225; // kg/m³
    final cda = 0.24; // frontal area for running

    // Rolling resistance + gravity
    final mechanicalPower = weightKg * g * velocity * (crr + slope);
    // Aerodynamic drag
    final aeroPower = 0.5 * airDensity * cda * velocity * velocity * velocity;
    // Assume ~25% efficiency for running
    return (mechanicalPower + aeroPower) / 0.25;
  }

  /// Classify power zone (based on typical running power zones)
  static String classify(double watts, double thresholdPower) {
    if (watts <= 0 || thresholdPower <= 0) return '';
    final ratio = watts / thresholdPower;
    if (ratio < 0.85) return 'Восстановление';
    if (ratio < 1.0) return 'Выносливость';
    if (ratio < 1.1) return 'Tempo';
    if (ratio < 1.2) return 'Пороговый';
    return 'VO2max';
  }
}
