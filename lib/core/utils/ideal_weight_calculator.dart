class IdealWeightCalculator {
  IdealWeightCalculator._();

  /// Devine formula (1974)
  static double devine(double heightCm, bool male) {
    if (heightCm <= 0) return 0;
    final inches = heightCm / 2.54;
    return male
        ? 50.0 + 2.3 * (inches - 60)
        : 45.5 + 2.3 * (inches - 60);
  }

  /// Robinson formula (1983)
  static double robinson(double heightCm, bool male) {
    if (heightCm <= 0) return 0;
    final inches = heightCm / 2.54;
    return male
        ? 52.0 + 1.9 * (inches - 60)
        : 49.0 + 1.7 * (inches - 60);
  }

  /// Miller formula (1983)
  static double miller(double heightCm, bool male) {
    if (heightCm <= 0) return 0;
    final inches = heightCm / 2.54;
    return male
        ? 56.2 + 1.41 * (inches - 60)
        : 53.1 + 1.36 * (inches - 60);
  }

  /// Hamwi formula (1964)
  static double hamwi(double heightCm, bool male) {
    if (heightCm <= 0) return 0;
    final inches = heightCm / 2.54;
    return male
        ? 48.0 + 2.7 * (inches - 60)
        : 45.5 + 2.2 * (inches - 60);
  }

  /// Average of all formulas
  static double average(double heightCm, bool male) {
    final d = devine(heightCm, male);
    final r = robinson(heightCm, male);
    final m = miller(heightCm, male);
    final h = hamwi(heightCm, male);
    return (d + r + m + h) / 4;
  }
}
