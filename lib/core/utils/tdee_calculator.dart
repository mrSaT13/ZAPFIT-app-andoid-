/// TDEE (Total Daily Energy Expenditure) + Macro Breakdown Calculator.
/// Combines multiple BMR formulas with activity levels.
enum ActivityLevel {
  sedentary,      // office work, little exercise
  lightlyActive,  // light exercise 1-3 days/week
  moderatelyActive, // moderate exercise 3-5 days/week
  veryActive,     // hard exercise 6-7 days/week
  extraActive,    // very hard exercise + physical job
}

class MacroBreakdown {
  final double proteinGrams;
  final double fatGrams;
  final double carbGrams;
  final double proteinCal;
  final double fatCal;
  final double carbCal;

  const MacroBreakdown({
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbGrams,
    required this.proteinCal,
    required this.fatCal,
    required this.carbCal,
  });

  double get totalCal => proteinCal + fatCal + carbCal;
}

class TdeeResult {
  final double bmrMifflin;
  final double bmrHarris;
  final double bmrKatch;
  final double tdee;
  final ActivityLevel activityLevel;
  final String activityLabel;
  final String activityDescription;
  final MacroBreakdown maintenanceMacros;
  final MacroBreakdown cuttingMacros; // -500 kcal
  final MacroBreakdown bulkingMacros; // +300 kcal

  const TdeeResult({
    required this.bmrMifflin,
    required this.bmrHarris,
    required this.bmrKatch,
    required this.tdee,
    required this.activityLevel,
    required this.activityLabel,
    required this.activityDescription,
    required this.maintenanceMacros,
    required this.cuttingMacros,
    required this.bulkingMacros,
  });

  double get bmrAvg => (bmrMifflin + bmrHarris + bmrKatch) / 3;
}

class TdeeCalculator {
  TdeeCalculator._();

  static const Map<ActivityLevel, double> _activityMultipliers = {
    ActivityLevel.sedentary: 1.2,
    ActivityLevel.lightlyActive: 1.375,
    ActivityLevel.moderatelyActive: 1.55,
    ActivityLevel.veryActive: 1.725,
    ActivityLevel.extraActive: 1.9,
  };

  static const Map<ActivityLevel, String> _activityLabels = {
    ActivityLevel.sedentary: 'Малоподвижный',
    ActivityLevel.lightlyActive: 'Легкая активность',
    ActivityLevel.moderatelyActive: 'Умеренная активность',
    ActivityLevel.veryActive: 'Высокая активность',
    ActivityLevel.extraActive: 'Экстра активность',
  };

  static const Map<ActivityLevel, String> _activityDescriptions = {
    ActivityLevel.sedentary: 'Сидячая работа, мало тренировок',
    ActivityLevel.lightlyActive: 'Лёгкие тренировки 1-3 раза в неделю',
    ActivityLevel.moderatelyActive: 'Тренировки 3-5 раз в неделю',
    ActivityLevel.veryActive: 'Интенсивные тренировки 6-7 раз в неделю',
    ActivityLevel.extraActive: 'Очень тяжёлые тренировки + физическая работа',
  };

  /// Calculate full TDEE result.
  /// [weightKg], [heightCm], [age], [gender] (1=male, 0=female)
  static TdeeResult calculate({
    required double weightKg,
    required double heightCm,
    required int age,
    required int gender,
    required ActivityLevel activityLevel,
  }) {
    final bmrMifflin = _bmrMifflin(weightKg, heightCm, age, gender);
    final bmrHarris = _bmrHarris(weightKg, heightCm, age, gender);
    final bmrKatch = _bmrKatch(weightKg, heightCm, gender, bodyFatPercent: null);
    final bmrAvg = (bmrMifflin + bmrHarris + bmrKatch) / 3;

    final multiplier = _activityMultipliers[activityLevel]!;
    final tdee = bmrAvg * multiplier;

    final maintenance = _calculateMacros(tdee, weightKg, 0.30, 0.25, 0.45);
    final cutting = _calculateMacros(tdee - 500, weightKg, 0.35, 0.25, 0.40);
    final bulking = _calculateMacros(tdee + 300, weightKg, 0.25, 0.25, 0.50);

    return TdeeResult(
      bmrMifflin: bmrMifflin,
      bmrHarris: bmrHarris,
      bmrKatch: bmrKatch,
      tdee: tdee,
      activityLevel: activityLevel,
      activityLabel: _activityLabels[activityLevel]!,
      activityDescription: _activityDescriptions[activityLevel]!,
      maintenanceMacros: maintenance,
      cuttingMacros: cutting,
      bulkingMacros: bulking,
    );
  }

  /// Mifflin-St Jeor (most accurate for general population)
  static double _bmrMifflin(double weight, double heightCm, int age, int gender) {
    if (gender == 1) {
      return 10 * weight + 6.25 * heightCm - 5 * age + 5;
    }
    return 10 * weight + 6.25 * heightCm - 5 * age - 161;
  }

  /// Harris-Benedict (revised)
  static double _bmrHarris(double weight, double heightCm, int age, int gender) {
    if (gender == 1) {
      return 88.362 + (13.397 * weight) + (4.799 * heightCm) - (5.677 * age);
    }
    return 447.593 + (9.247 * weight) + (3.098 * heightCm) - (4.330 * age);
  }

  /// Katch-McArdle (best if body fat % is known, otherwise uses average)
  static double _bmrKatch(double weight, double heightCm, int gender, {double? bodyFatPercent}) {
    // Estimate lean body mass
    double lbm;
    if (bodyFatPercent != null && bodyFatPercent > 0) {
      lbm = weight * (1 - bodyFatPercent / 100);
    } else {
      // Default estimate: ~78% lean mass for male, ~72% for female
      lbm = weight * (gender == 1 ? 0.78 : 0.72);
    }
    return 370 + 21.6 * lbm;
  }

  /// Calculate macro breakdown for given calorie target.
  static MacroBreakdown _calculateMacros(
    double calories,
    double weightKg,
    double proteinPct,
    double fatPct,
    double carbPct,
  ) {
    // Protein: 1.6-2.2g per kg (use 2.0g for active people)
    final proteinG = weightKg * 2.0;
    final proteinCal = proteinG * 4; // 4 kcal/g

    // Fat: percentage of total calories
    final fatCal = calories * fatPct;
    final fatG = fatCal / 9; // 9 kcal/g

    // Carbs: remaining calories
    final carbCal = calories - proteinCal - fatCal;
    final carbG = carbCal / 4; // 4 kcal/g

    return MacroBreakdown(
      proteinGrams: proteinG.roundToDouble(),
      fatGrams: fatG.roundToDouble(),
      carbGrams: carbG.roundToDouble(),
      proteinCal: proteinCal.roundToDouble(),
      fatCal: fatCal.roundToDouble(),
      carbCal: carbCal.roundToDouble(),
    );
  }

  /// Activity level labels for UI.
  static String activityLevelLabel(ActivityLevel level) => _activityLabels[level]!;
  static String activityLevelDescription(ActivityLevel level) => _activityDescriptions[level]!;
}
