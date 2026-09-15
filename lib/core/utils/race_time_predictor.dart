import 'dart:math';

class RaceTimePredictor {
  RaceTimePredictor._();

  /// Predict race time using Riegel formula
  /// T2 = T1 × (D2/D1)^1.06
  static Duration predict({
    required Duration time1,
    required double distance1Km,
    required double distance2Km,
  }) {
    if (distance1Km <= 0 || distance2Km <= 0 || time1.inSeconds <= 0) {
      return Duration.zero;
    }
    final seconds = time1.inSeconds * pow(distance2Km / distance1Km, 1.06);
    return Duration(seconds: seconds.round());
  }

  /// Predict all distances from 10km time
  static Map<String, Duration> predictAll(Duration time10k) {
    if (time10k.inSeconds <= 0) return {};
    return {
      '5 км': predict(time1: time10k, distance1Km: 10, distance2Km: 5),
      '10 км': time10k,
      'Полумарафон': predict(time1: time10k, distance1Km: 10, distance2Km: 21.0975),
      'Марафон': predict(time1: time10k, distance1Km: 10, distance2Km: 42.195),
    };
  }

  static String formatTime(Duration d) {
    if (d.inSeconds <= 0) return '--:--';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
