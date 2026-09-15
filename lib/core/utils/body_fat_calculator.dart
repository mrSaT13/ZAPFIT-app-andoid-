import 'dart:math' as math;

class BodyFatCalculator {
  BodyFatCalculator._();

  static String classify(double percent, {required bool male}) {
    if (male) {
      if (percent < 6) return 'Очень низкий';
      if (percent < 14) return 'Атлетический';
      if (percent < 18) return 'Спортивный';
      if (percent < 25) return 'Норма';
      if (percent < 32) return 'Средний';
      return 'Высокий';
    }
    if (percent < 14) return 'Очень низкий';
    if (percent < 21) return 'Атлетический';
    if (percent < 25) return 'Спортивный';
    if (percent < 32) return 'Норма';
    if (percent < 38) return 'Средний';
    return 'Высокий';
  }

  static double? navy({
    required double heightCm,
    required double waistCm,
    required double neckCm,
    double? hipCm,
    required bool male,
  }) {
    if (heightCm <= 0 || waistCm <= 0 || neckCm <= 0) return null;
    if (waistCm <= neckCm) return null;
    if (!male && (hipCm == null || hipCm <= 0)) return null;
    final lh = math.log(heightCm) / math.ln10;
    if (male) {
      final lw = math.log(waistCm - neckCm) / math.ln10;
      return 86.010 * lw - 70.041 * lh + 36.76;
    }
    final sum = waistCm + hipCm! - neckCm;
    if (sum <= 0) return null;
    final lsum = math.log(sum) / math.ln10;
    return 163.205 * lsum - 97.684 * lh - 78.387;
  }

  static double? ymca({
    required double weightKg,
    required double waistCm,
    required bool male,
  }) {
    if (weightKg <= 0 || waistCm <= 0) return null;
    final offset = male ? -98.42 : -76.76;
    return (offset + 4.15 * waistCm - 0.082 * weightKg) / weightKg * 100;
  }

  static double? whr({required double waistCm, required double hipCm}) {
    if (waistCm <= 0 || hipCm <= 0) return null;
    return waistCm / hipCm;
  }

  static String classifyWhr(double whr, {required bool male}) {
    if (male) {
      if (whr < 0.85) return 'Низкий';
      if (whr < 0.90) return 'Умеренный';
      if (whr < 0.95) return 'Высокий';
      return 'Очень высокий';
    }
    if (whr < 0.80) return 'Низкий';
    if (whr < 0.85) return 'Умеренный';
    if (whr < 0.90) return 'Высокий';
    return 'Очень высокий';
  }

  static double? whtr({required double waistCm, required double heightCm}) {
    if (waistCm <= 0 || heightCm <= 0) return null;
    return waistCm / heightCm;
  }

  static String classifyWhtr(double whtr) {
    if (whtr < 0.40) return 'Очень худой';
    if (whtr < 0.50) return 'Норма';
    if (whtr < 0.55) return 'Повышенный';
    if (whtr < 0.60) return 'Высокий';
    return 'Очень высокий';
  }
}
