class FonderalCalculator {
  FonderalCalculator._();

  /// Calculate Fonderal Index (ponderal index)
  /// PI = height(cm) / cubeRoot(weight(kg))
  static double calculate(double heightCm, double weightKg) {
    if (heightCm <= 0 || weightKg <= 0) return 0;
    double cubeRoot = weightKg;
    for (int i = 0; i < 20; i++) {
      cubeRoot = (2 * cubeRoot + weightKg / (cubeRoot * cubeRoot)) / 3;
    }
    return heightCm / cubeRoot;
  }

  /// Classify Fonderal Index
  static String classify(double pi) {
    if (pi <= 0) return 'Нет данных';
    if (pi < 11) return 'Ожирение';
    if (pi <= 13) return 'Норма';
    if (pi <= 14) return 'Избыточный';
    return 'Недостаточный';
  }
}
