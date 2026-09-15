import 'dart:math';

/// Riegel Race Time Predictor.
/// Formula: T2 = T1 × (D2/D1)^1.06
/// where T1 = known race time, D1 = known distance, D2 = target distance
/// The exponent 1.06 accounts for fatigue over longer distances.
class RiegelPredictor {
  RiegelPredictor._();

  /// Standard race distances in meters
  static const Map<String, double> standardDistances = {
    '1 км': 1000,
    '1.5 км': 1500,
    '3 км': 3000,
    '5 км': 5000,
    '10 км': 10000,
    'Полумарафон': 21097.5,
    'Марафон': 42195,
  };

  static const double _exponent = 1.06;

  /// Predict time for a target distance based on a known race result.
  static double predict({
    required double timeSeconds,
    required double knownDistanceMeters,
    required double targetDistanceMeters,
  }) {
    if (timeSeconds <= 0 || knownDistanceMeters <= 0 || targetDistanceMeters <= 0) {
      return 0;
    }
    return timeSeconds * pow(targetDistanceMeters / knownDistanceMeters, _exponent);
  }

  /// Predict times for all standard distances from a known result.
  static Map<String, double> predictAll({
    required double timeSeconds,
    required double knownDistanceMeters,
  }) {
    final results = <String, double>{};
    for (final entry in standardDistances.entries) {
      if ((entry.value - knownDistanceMeters).abs() < 100) continue;
      results[entry.key] = predict(
        timeSeconds: timeSeconds,
        knownDistanceMeters: knownDistanceMeters,
        targetDistanceMeters: entry.value,
      );
    }
    return results;
  }

  /// Format seconds to "H:MM:SS" or "MM:SS" string.
  static String formatTime(double seconds) {
    if (seconds <= 0) return '--:--';
    final totalSeconds = seconds.round();
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Parse pace string "MM:SS" to seconds per kilometer.
  static double parsePace(String pace) {
    final parts = pace.split(':');
    if (parts.length != 2) return 0;
    final min = int.tryParse(parts[0]) ?? 0;
    final sec = int.tryParse(parts[1]) ?? 0;
    return (min * 60 + sec).toDouble();
  }
}
