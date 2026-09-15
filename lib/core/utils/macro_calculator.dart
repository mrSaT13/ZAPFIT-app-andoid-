class MacroCalculator {
  MacroCalculator._();

  /// Calculate macros for a goal
  static MacroResult calculate({
    required double tdee,
    required double weightKg,
    String goal = 'maintain', // maintain, cut, bulk
    String bodyType = 'mesomorph', // ectomorph, mesomorph, endomorph
  }) {
    double calorieTarget = tdee;
    if (goal == 'cut') calorieTarget = tdee - 400;
    else if (goal == 'bulk') calorieTarget = tdee + 400;

    // Protein: 1.6-2.2 g/kg
    double proteinPerKg;
    switch (goal) {
      case 'cut': proteinPerKg = 2.2; break;
      case 'bulk': proteinPerKg = 1.8; break;
      default: proteinPerKg = 1.6;
    }

    // Fat: 0.8-1.2 g/kg
    double fatPerKg;
    switch (bodyType) {
      case 'ectomorph': fatPerKg = 1.0; break;
      case 'endomorph': fatPerKg = 0.8; break;
      default: fatPerKg = 0.9;
    }

    final proteinG = weightKg * proteinPerKg;
    final fatG = weightKg * fatPerKg;
    final proteinCal = proteinG * 4;
    final fatCal = fatG * 9;
    final carbCal = calorieTarget - proteinCal - fatCal;
    final carbG = carbCal > 0 ? carbCal / 4 : 0;

    return MacroResult(
      calories: calorieTarget.round(),
      proteinGrams: proteinG.round(),
      fatGrams: fatG.round(),
      carbGrams: carbG.round(),
      proteinCal: proteinCal.round(),
      fatCal: fatCal.round(),
      carbCal: carbCal.round(),
    );
  }
}

class MacroResult {
  final int calories;
  final int proteinGrams;
  final int fatGrams;
  final int carbGrams;
  final int proteinCal;
  final int fatCal;
  final int carbCal;

  const MacroResult({
    required this.calories,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbGrams,
    required this.proteinCal,
    required this.fatCal,
    required this.carbCal,
  });
}
