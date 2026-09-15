class CssCalculator {
  CssCalculator._();

  /// Calculate Critical Swim Speed from best 50m and 400m times
  /// CSS = (distance2 - distance1) / (time2 - time1)
  static double calculate({
    required double time400Seconds,
    required double time50Seconds,
  }) {
    if (time400Seconds <= time50Seconds) return 0;
    return (400 - 50) / (time400Seconds - time50Seconds); // meters per second
  }

  static String formatCss(double mps) {
    if (mps <= 0) return '--:--';
    // Convert m/s to min/100m
    final secPer100m = 100 / mps;
    final m = secPer100m ~/ 60;
    final s = (secPer100m % 60).round();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} /100м';
  }
}
