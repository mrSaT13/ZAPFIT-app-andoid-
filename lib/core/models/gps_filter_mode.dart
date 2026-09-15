enum GpsFilterMode { auto, normal, strict }

GpsFilterMode gpsFilterModeFromStorage(String? raw) {
  switch (raw) {
    case 'normal':
      return GpsFilterMode.normal;
    case 'strict':
      return GpsFilterMode.strict;
    case 'auto':
    default:
      return GpsFilterMode.auto;
  }
}

String gpsFilterModeToStorage(GpsFilterMode mode) {
  switch (mode) {
    case GpsFilterMode.auto:
      return 'auto';
    case GpsFilterMode.normal:
      return 'normal';
    case GpsFilterMode.strict:
      return 'strict';
  }
}
