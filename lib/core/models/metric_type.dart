import 'package:endurain/l10n/app_localizations.dart';

enum MetricType {
  distance,
  duration,
  speed,
  avgSpeed,
  pace,
  avgPace,
  elevation,
  heartRate,
  cadence,
  none; // Represents an empty slot

  String label(AppLocalizations l10n) {
    switch (this) {
      case MetricType.distance:
        return l10n.trackingDistance;
      case MetricType.duration:
        return l10n.trackingDuration;
      case MetricType.speed:
        return l10n.trackingCurrentSpeed;
      case MetricType.avgSpeed:
        return 'Avg Speed'; // TODO: Localize
      case MetricType.pace:
        return 'Pace'; // TODO: Localize
      case MetricType.avgPace:
        return 'Avg Pace'; // TODO: Localize
      case MetricType.elevation:
        return l10n.trackingElevationGain;
      case MetricType.heartRate:
        return 'Heart Rate'; // TODO: Localize
      case MetricType.cadence:
        return 'Cadence'; // TODO: Localize
      case MetricType.none:
        return '';
    }
  }
}
