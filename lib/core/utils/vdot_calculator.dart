/// VDOT Calculator (Jack Daniels' Running Formula).
/// Estimates VO2max and equivalent performance from race results.
///
/// Key concept: VDOT is the linking variable between race performance and
/// training paces. Higher VDOT = faster at all distances.
///
/// Reference: "Daniels' Running Formula" by Jack Daniels.
class VdotCalculator {
  VdotCalculator._();

  /// VDOT table: VDOT value → [best pace for 1500m, 3k, 5k, 10k, Half, Marathon] in sec/km
  /// These are the "equivalent performances" at each VDOT level.
  static final List<_VdotRow> _vdotTable = [
    _VdotRow(30, 384, 405, 426, 450, 480, 504),
    _VdotRow(31, 375, 396, 417, 441, 471, 495),
    _VdotRow(32, 367, 388, 408, 432, 462, 486),
    _VdotRow(33, 359, 380, 400, 423, 453, 477),
    _VdotRow(34, 351, 372, 392, 415, 445, 469),
    _VdotRow(35, 344, 364, 384, 407, 437, 461),
    _VdotRow(36, 337, 357, 377, 400, 430, 453),
    _VdotRow(37, 330, 350, 370, 393, 423, 446),
    _VdotRow(38, 324, 343, 363, 386, 416, 439),
    _VdotRow(39, 318, 337, 357, 380, 410, 433),
    _VdotRow(40, 312, 331, 351, 374, 404, 427),
    _VdotRow(41, 307, 326, 345, 368, 398, 421),
    _VdotRow(42, 302, 320, 340, 363, 393, 415),
    _VdotRow(43, 297, 315, 335, 358, 388, 410),
    _VdotRow(44, 292, 310, 330, 353, 382, 405),
    _VdotRow(45, 288, 306, 325, 348, 377, 400),
    _VdotRow(46, 284, 302, 321, 344, 373, 396),
    _VdotRow(47, 280, 298, 317, 340, 369, 392),
    _VdotRow(48, 276, 294, 313, 336, 365, 388),
    _VdotRow(49, 272, 290, 309, 332, 361, 384),
    _VdotRow(50, 269, 287, 306, 329, 357, 380),
    _VdotRow(51, 265, 283, 302, 325, 353, 376),
    _VdotRow(52, 262, 280, 298, 321, 349, 373),
    _VdotRow(53, 259, 277, 295, 318, 346, 369),
    _VdotRow(54, 256, 274, 292, 315, 343, 366),
    _VdotRow(55, 253, 271, 289, 312, 340, 363),
    _VdotRow(56, 250, 268, 286, 309, 337, 360),
    _VdotRow(57, 248, 265, 283, 306, 334, 357),
    _VdotRow(58, 245, 263, 280, 303, 331, 354),
    _VdotRow(59, 243, 260, 277, 300, 328, 351),
    _VdotRow(60, 240, 258, 275, 298, 326, 349),
    _VdotRow(61, 238, 255, 272, 295, 323, 346),
    _VdotRow(62, 236, 253, 270, 293, 321, 344),
    _VdotRow(63, 234, 251, 268, 291, 319, 342),
    _VdotRow(64, 232, 249, 266, 289, 317, 340),
    _VdotRow(65, 230, 247, 264, 287, 315, 338),
    _VdotRow(66, 228, 245, 262, 285, 313, 336),
    _VdotRow(67, 226, 243, 260, 283, 311, 334),
    _VdotRow(68, 224, 241, 258, 281, 309, 332),
    _VdotRow(69, 222, 239, 256, 279, 307, 330),
    _VdotRow(70, 221, 237, 254, 277, 305, 328),
    _VdotRow(71, 219, 235, 252, 275, 303, 326),
    _VdotRow(72, 217, 234, 251, 274, 302, 325),
    _VdotRow(73, 216, 232, 249, 272, 300, 323),
    _VdotRow(74, 214, 230, 247, 270, 298, 321),
    _VdotRow(75, 213, 229, 246, 269, 297, 320),
  ];

  /// Distance categories (indices into the pace array):
  /// 0=1500m, 1=3k, 2=5k, 3=10k, 4=Half, 5=Marathon
  static const List<double> _distancesMeters = [1500, 3000, 5000, 10000, 21097.5, 42195];

  /// Known race distances for input matching
  static const Map<String, int> _distanceMap = {
    '1500': 0,
    '3000': 1,
    '5000': 2,
    '10000': 3,
    '21097': 4,
    '21098': 4,
    '42195': 5,
  };

  /// Estimate VDOT from a race result.
  /// [timeSeconds] — race time in seconds
  /// [distanceMeters] — race distance in meters
  /// Returns VDOT value (30-75 range).
  static double estimateVdot({
    required double timeSeconds,
    required double distanceMeters,
  }) {
    if (timeSeconds <= 0) return 0;

    final paceSecPerKm = timeSeconds / (distanceMeters / 1000);

    // Interpolate from VDOT table
    for (int i = 0; i < _vdotTable.length - 1; i++) {
      final row = _vdotTable[i];
      final nextRow = _vdotTable[i + 1];
      final distIdx = _closestDistanceIndex(distanceMeters);
      if (distIdx < 0) return 0;

      final pace1 = row.paces[distIdx];
      final pace2 = nextRow.paces[distIdx];

      // Table is sorted by pace (descending = faster)
      if (paceSecPerKm >= pace2 && paceSecPerKm <= pace1) {
        // Linear interpolation
        final t = (paceSecPerKm - pace1) / (pace2 - pace1);
        return row.vdot + t * (nextRow.vdot - row.vdot);
      }
    }

    // Beyond table range
    if (paceSecPerKm <= _vdotTable.last.paces[_closestDistanceIndex(distanceMeters)]) {
      return 75.0;
    }
    return 30.0;
  }

  /// Get equivalent performances for a given VDOT.
  /// Returns map of distance label → time in seconds.
  static Map<String, double> equivalentPerformances(double vdot) {
    final results = <String, double>{};
    final distLabels = ['1.5 км', '3 км', '5 км', '10 км', 'Полумарафон', 'Марафон'];

    for (int i = 0; i < _vdotTable.length - 1; i++) {
      final row = _vdotTable[i];
      final nextRow = _vdotTable[i + 1];

      if (vdot >= row.vdot && vdot <= nextRow.vdot) {
        final t = (vdot - row.vdot) / (nextRow.vdot - row.vdot);
        for (int d = 0; d < distLabels.length; d++) {
          final pace = row.paces[d] + t * (nextRow.paces[d] - row.paces[d]);
          final distM = _distancesMeters[d];
          results[distLabels[d]] = pace * (distM / 1000);
        }
        break;
      }
    }

    return results;
  }

  /// Get training paces for a given VDOT.
  /// Returns map of zone name → pace in sec/km.
  static Map<String, double> trainingPaces(double vdot) {
    // Training paces as ratio of equivalent marathon pace
    final equivs = equivalentPerformances(vdot);
    final marathonPace = equivs['Марафон'];
    if (marathonPace == null || marathonPace <= 0) return {};

    final marathonSecPerKm = marathonPace / 42.195;

    return {
      'Восстановительная': marathonSecPerKm * 1.10,
      'Марафон': marathonSecPerKm,
      'Пороговая': marathonSecPerKm * 0.94,
      'Интервальная': marathonSecPerKm * 0.875,
      'Повторения': marathonSecPerKm * 0.80,
    };
  }

  static int _closestDistanceIndex(double meters) {
    int best = 0;
    double bestDiff = double.infinity;
    for (int i = 0; i < _distancesMeters.length; i++) {
      final diff = (meters - _distancesMeters[i]).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  static String formatPace(double secPerKm) {
    if (secPerKm <= 0) return '--:--';
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _VdotRow {
  final int vdot;
  final List<int> paces; // sec/km for [1500m, 3k, 5k, 10k, Half, Marathon]
  _VdotRow(this.vdot, int p0, int p1, int p2, int p3, int p4, int p5)
      : paces = <int>[p0, p1, p2, p3, p4, p5];
}
