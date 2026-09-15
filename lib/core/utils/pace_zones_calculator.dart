class PaceZonesCalculator {
  PaceZonesCalculator._();

  /// Calculate 5-zone pace ranges based on threshold pace (sec/km)
  /// Zones: Recovery, Easy, Tempo, Threshold, VO2max
  static Map<String, String> calculateZones(double thresholdPaceSecPerKm) {
    if (thresholdPaceSecPerKm <= 0) return {};
    return {
      'Z1 Восстановление': _formatPace(thresholdPaceSecPerKm * 1.25),
      'Z2 Лёгкий': _formatPace(thresholdPaceSecPerKm * 1.15),
      'Z3 Темповый': _formatPace(thresholdPaceSecPerKm * 1.05),
      'Z4 Пороговый': _formatPace(thresholdPaceSecPerKm * 0.98),
      'Z5 Максимум': _formatPace(thresholdPaceSecPerKm * 0.90),
    };
  }

  /// Calculate 5-zone heart rate ranges based on max HR
  static Map<String, String> calculateHrZones(int maxHr) {
    if (maxHr <= 0) return {};
    return {
      'Z1': '${(maxHr * 0.50).round()}–${(maxHr * 0.60).round()} bpm',
      'Z2': '${(maxHr * 0.60).round()}–${(maxHr * 0.70).round()} bpm',
      'Z3': '${(maxHr * 0.70).round()}–${(maxHr * 0.80).round()} bpm',
      'Z4': '${(maxHr * 0.80).round()}–${(maxHr * 0.90).round()} bpm',
      'Z5': '${(maxHr * 0.90).round()}–${maxHr} bpm',
    };
  }

  static String _formatPace(double secPerKm) {
    if (secPerKm <= 0) return '--:--';
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
