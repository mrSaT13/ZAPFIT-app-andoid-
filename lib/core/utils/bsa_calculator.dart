class BsaCalculator {
  BsaCalculator._();

  /// Mosteller formula: BSA = sqrt(height(cm) × weight(kg) / 3600)
  static double mosteller(double heightCm, double weightKg) {
    if (heightCm <= 0 || weightKg <= 0) return 0;
    return (heightCm * weightKg / 3600).sqrt();
  }

  /// DuBois formula: BSA = 0.007184 × height(cm)^0.725 × weight(kg)^0.425
  static double duBois(double heightCm, double weightKg) {
    if (heightCm <= 0 || weightKg <= 0) return 0;
    return 0.007184 * heightCm.pow(0.725) * weightKg.pow(0.425);
  }

  static String classify(double bsa) {
    if (bsa <= 0) return 'Нет данных';
    if (bsa < 1.6) return 'Малая площадь поверхности';
    if (bsa <= 2.0) return 'Норма';
    return 'Большая площадь поверхности';
  }
}

extension _MathExt on double {
  double sqrt() {
    if (this < 0) return 0;
    if (this == 0) return 0;
    double x = this / 2;
    for (int i = 0; i < 20; i++) {
      x = (x + this / x) / 2;
    }
    return x;
  }

  double pow(double exp) {
    if (exp == 0) return 1;
    if (exp == 1) return this;
    if (exp == 0.5) return sqrt();
    double result = 1;
    final intExp = exp.toInt();
    for (int i = 0; i < intExp; i++) {
      result *= this;
    }
    return result * pow(exp - intExp);
  }
}
