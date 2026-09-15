import 'dart:ui';

/// VO2 Max estimation and fitness level calculation.
/// Ported from VO2MaxUtil.java (Xiaomi/Huami Health).
enum FitnessLevel {
  veryLow,
  low,
  belowAverage,
  average,
  aboveAverage,
  high,
  superior,
}

class Vo2MaxResult {
  final double vo2max;
  final FitnessLevel level;
  final String levelLabel;
  final String description;

  const Vo2MaxResult({
    required this.vo2max,
    required this.level,
    required this.levelLabel,
    required this.description,
  });
}

class Vo2MaxCalculator {
  Vo2MaxCalculator._();

  // Age group boundaries (upper limits): 24, 29, 34, 39, 44, 49, 54, 59, 65
  static const List<int> _ageGroups = [24, 29, 34, 39, 44, 49, 54, 59, 65];

  // VO2 Max thresholds by gender (1=male, 0=female) and age group
  // Each row: [level1, level2, level3, level4, level5, level6]
  // Levels: Very Low, Low, Below Average, Average, Above Average, High+
  static const Map<int, List<List<int>>> _vo2maxThresholds = {
    1: [ // Male
      [31, 37, 43, 50, 56, 62], // age ≤24
      [30, 35, 42, 48, 53, 59], // age 25-29
      [28, 34, 40, 45, 51, 56], // age 30-34
      [27, 32, 38, 43, 48, 54], // age 35-39
      [25, 31, 35, 41, 46, 51], // age 40-44
      [24, 29, 34, 39, 43, 48], // age 45-49
      [23, 27, 32, 36, 41, 46], // age 50-54
      [21, 26, 30, 34, 39, 43], // age 55-59
      [20, 24, 28, 32, 36, 40], // age 60-65
    ],
    0: [ // Female
      [26, 31, 36, 41, 46, 51], // age ≤24
      [25, 30, 35, 40, 44, 49], // age 25-29
      [24, 29, 33, 37, 42, 46], // age 30-34
      [23, 27, 31, 35, 40, 44], // age 35-39
      [21, 25, 29, 33, 37, 41], // age 40-44
      [20, 23, 27, 31, 35, 38], // age 45-49
      [18, 22, 25, 29, 32, 36], // age 50-54
      [17, 20, 23, 27, 30, 33], // age 55-59
      [15, 18, 21, 24, 27, 30], // age 60-65
    ],
  };

  /// Calculate VO2 Max from resting heart rate (Firstbeat method approximation).
  /// VO2max ≈ 15.3 × (HRmax / HRrest)
  /// where HRmax ≈ 208 - 0.7 × age
  static double estimateFromHeartRate({
    required int restingHr,
    required int maxHr,
    required int age,
  }) {
    if (restingHr <= 0 || restingHr > 200) return 0;
    final effectiveMaxHr = maxHr > 0 ? maxHr : (208 - 0.7 * age).round();
    // Firstbeat-like estimation
    final vo2max = 15.3 * (effectiveMaxHr / restingHr);
    return vo2max.clamp(15.0, 85.0);
  }

  /// Convert VO2 Max to ml/kg/min MET equivalent.
  /// MET = VO2max / 3.5
  static double toMet(double vo2max) => vo2max / 3.5;

  /// Determine fitness level from VO2max value.
  static FitnessLevel getLevel(double vo2max, int gender, int age) {
    final thresholds = _getThresholds(gender, age);
    if (thresholds == null) return FitnessLevel.average;

    if (vo2max > thresholds[5]) return FitnessLevel.superior;
    if (vo2max > thresholds[4]) return FitnessLevel.high;
    if (vo2max > thresholds[3]) return FitnessLevel.aboveAverage;
    if (vo2max > thresholds[2]) return FitnessLevel.average;
    if (vo2max > thresholds[1]) return FitnessLevel.belowAverage;
    if (vo2max > thresholds[0]) return FitnessLevel.low;
    return FitnessLevel.veryLow;
  }

  /// Get the fitness level range for chart display.
  static List<int> getLevelRange(int gender, int age) {
    final thresholds = _getThresholds(gender, age);
    if (thresholds == null) return [15, 80];
    return [thresholds[0] - 5, thresholds[5] + 6];
  }

  static List<int>? _getThresholds(int gender, int age) {
    final ageGroupIdx = _ageGroupIndex(age);
    final genderThresholds = _vo2maxThresholds[gender];
    if (genderThresholds == null || ageGroupIdx >= genderThresholds.length) return null;
    return genderThresholds[ageGroupIdx];
  }

  static int _ageGroupIndex(int age) {
    for (int i = 0; i < _ageGroups.length; i++) {
      if (age <= _ageGroups[i]) return i;
    }
    return _ageGroups.length - 1;
  }

  /// Full result with label and description.
  static Vo2MaxResult calculate({
    required double vo2max,
    required int gender,
    required int age,
  }) {
    final level = getLevel(vo2max, gender, age);
    return Vo2MaxResult(
      vo2max: vo2max,
      level: level,
      levelLabel: _levelLabel(level),
      description: _levelDescription(level),
    );
  }

  static String _levelLabel(FitnessLevel level) {
    switch (level) {
      case FitnessLevel.veryLow:
        return 'Очень низкий';
      case FitnessLevel.low:
        return 'Низкий';
      case FitnessLevel.belowAverage:
        return 'Ниже среднего';
      case FitnessLevel.average:
        return 'Средний';
      case FitnessLevel.aboveAverage:
        return 'Выше среднего';
      case FitnessLevel.high:
        return 'Высокий';
      case FitnessLevel.superior:
        return 'Превосходный';
    }
  }

  static String _levelDescription(FitnessLevel level) {
    switch (level) {
      case FitnessLevel.veryLow:
        return 'Начните с лёгких пеших прогулок, постепенно увеличивая нагрузку.';
      case FitnessLevel.low:
        return 'Регулярные прогулки и лёгкий бег помогут улучшить результат.';
      case FitnessLevel.belowAverage:
        return 'Хорошая база. Добавьте кардио-тренировки 3-4 раза в неделю.';
      case FitnessLevel.average:
        return 'Нормальный уровень подготовки. Продолжайте тренировки.';
      case FitnessLevel.aboveAverage:
        return 'Хорошая форма! Интервалы помогут достичь высокого уровня.';
      case FitnessLevel.high:
        return 'Отличная форма. Вы в топ-20% людей вашего возраста.';
      case FitnessLevel.superior:
        return 'Превосходная форма! Вы в топ-5% людей вашего возраста.';
    }
  }

  static Color levelColor(FitnessLevel level) {
    switch (level) {
      case FitnessLevel.veryLow:
        return const Color(0xFFF44336);
      case FitnessLevel.low:
        return const Color(0xFFFF9800);
      case FitnessLevel.belowAverage:
        return const Color(0xFFFFC107);
      case FitnessLevel.average:
        return const Color(0xFF8BC34A);
      case FitnessLevel.aboveAverage:
        return const Color(0xFF4CAF50);
      case FitnessLevel.high:
        return const Color(0xFF2196F3);
      case FitnessLevel.superior:
        return const Color(0xFF9C27B0);
    }
  }
}
