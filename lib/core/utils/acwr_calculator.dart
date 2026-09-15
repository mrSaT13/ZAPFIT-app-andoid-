class AcwrCalculator {
  AcwrCalculator._();

  /// Calculate ACWR (Acute:Chronic Workload Ratio)
  /// ACWR = ATL / CTL
  static double calculate({
    required double atl,
    required double ctl,
  }) {
    if (ctl <= 0) return 0;
    return atl / ctl;
  }

  /// Classify ACWR zone
  static String classify(double acwr) {
    if (acwr <= 0) return 'Нет данных';
    if (acwr < 0.8) return 'Детренировка';
    if (acwr <= 1.3) return 'Оптимальная зона';
    if (acwr <= 1.5) return 'Повышенный риск';
    return 'Опасная зона';
  }

  /// Calculate CTL (Chronic Training Load) using EWMA
  static double calculateCtl(List<double> dailyTss, {int decayDays = 42}) {
    if (dailyTss.isEmpty) return 0;
    final alpha = 2.0 / (decayDays + 1);
    double ctl = dailyTss.first;
    for (int i = 1; i < dailyTss.length; i++) {
      ctl = alpha * dailyTss[i] + (1 - alpha) * ctl;
    }
    return ctl;
  }

  /// Calculate ATL (Acute Training Load) using EWMA
  static double calculateAtl(List<double> dailyTss, {int decayDays = 7}) {
    if (dailyTss.isEmpty) return 0;
    final alpha = 2.0 / (decayDays + 1);
    double atl = dailyTss.first;
    for (int i = 1; i < dailyTss.length; i++) {
      atl = alpha * dailyTss[i] + (1 - alpha) * atl;
    }
    return atl;
  }

  /// Calculate TSB (Training Stress Balance)
  static double calculateTsb(double ctl, double atl) => ctl - atl;
}
