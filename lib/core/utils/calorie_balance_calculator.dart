class CalorieBalanceCalculator {
  CalorieBalanceCalculator._();

  /// Calculate calorie balance based on intake vs expenditure
  static CalorieBalanceResult calculate({
    required double intakeCalories,
    required double expenditureCalories,
    double? targetWeightChange, // kg per week
  }) {
    final balance = intakeCalories - expenditureCalories;
    // 1 kg of fat ≈ 7700 kcal
    final weeklyChangeKg = balance * 7 / 7700;

    String status;
    if (balance.abs() < 50) status = 'Баланс';
    else if (balance > 0) status = 'Избыток';
    else status = 'Дефицит';

    return CalorieBalanceResult(
      dailyBalance: balance.round(),
      weeklyChangeKg: weeklyChangeKg,
      status: status,
      daysToGoal: targetWeightChange != null && weeklyChangeKg != 0
          ? (targetWeightChange / weeklyChangeKg * 7).abs().round()
          : null,
    );
  }
}

class CalorieBalanceResult {
  final int dailyBalance;
  final double weeklyChangeKg;
  final String status;
  final int? daysToGoal;

  const CalorieBalanceResult({
    required this.dailyBalance,
    required this.weeklyChangeKg,
    required this.status,
    this.daysToGoal,
  });
}
