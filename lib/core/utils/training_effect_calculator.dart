class TrainingEffectCalculator {
  TrainingEffectCalculator._();

  /// Calculate aerobic training effect (1.0-5.0)
  /// Based on Firstbeat methodology
  static double aerobic({
    required double? tss,
    required double? hrvResponse,
    required double? atl,
    required double? ctl,
  }) {
    if (tss == null || tss <= 0) return 0;

    double effect = 1.0;
    // Base on TSS
    if (tss > 150) effect = 4.0;
    else if (tss > 100) effect = 3.5;
    else if (tss > 75) effect = 3.0;
    else if (tss > 50) effect = 2.5;
    else if (tss > 25) effect = 2.0;
    else effect = 1.0;

    // CTL ratio adjustment
    if (ctl != null && ctl > 0 && atl != null) {
      final ratio = atl / ctl;
      if (ratio > 1.5) effect += 0.5;
      else if (ratio < 0.7) effect -= 0.3;
    }

    return effect.clamp(1.0, 5.0);
  }

  /// Calculate anaerobic training effect (1.0-5.0)
  static double anaerobic({
    required double? tss,
    required int? peakPowerWatts,
    required double? ftpWatts,
  }) {
    if (tss == null || tss <= 0) return 1.0;

    double effect = 1.0;
    if (peakPowerWatts != null && ftpWatts != null && ftpWatts > 0) {
      final ratio = peakPowerWatts / ftpWatts;
      if (ratio > 1.6) effect = 4.5;
      else if (ratio > 1.3) effect = 3.5;
      else if (ratio > 1.1) effect = 2.5;
      else effect = 1.5;
    }

    // Short high-intensity sessions
    if (tss > 0 && tss < 50) {
      effect = effect.clamp(1.0, 3.0);
    }

    return effect.clamp(1.0, 5.0);
  }

  static String classifyAerobic(double te) {
    if (te < 1.5) return 'Восстановление';
    if (te < 2.5) return 'Поддержание формы';
    if (te < 3.5) return 'Улучшение формы';
    if (te < 4.5) return 'Значительное улучшение';
    return 'Чрезмерная нагрузка';
  }

  static String classifyAnaerobic(double te) {
    if (te < 1.5) return 'Нет эффекта';
    if (te < 2.5) return 'Минимальный';
    if (te < 3.5) return 'Умеренный';
    if (te < 4.5) return 'Значительный';
    return 'Чрезмерный';
  }
}
