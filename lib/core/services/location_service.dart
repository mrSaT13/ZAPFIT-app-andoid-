import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationAccuracy _mapAccuracy(String accuracyMode) {
    switch (accuracyMode) {
      case 'lowest':
        return LocationAccuracy.lowest;
      case 'low':
        return LocationAccuracy.low;
      case 'balanced':
        return LocationAccuracy.medium;
      case 'high':
      default:
        return LocationAccuracy.high;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  /// Get current position
  /// Returns null if permission is denied or location service is disabled
  Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get position stream for continuous tracking - FIXED for Samsung Android 12 offline bug
  /// Old working build (Xiaomi Android 8, 8.3(22)) used LocationSettings with distanceFilter only.
  /// New build introduced AndroidSettings(intervalDuration+timeLimit:10) which timeouts on Samsung
  /// when stationary/no internet -> stream completes -> watchdog gap -> 0.06km instead of 4.12km.
  /// Also Samsung needs smaller distanceFilter for cycling (4.7m/s) with Kalman smoothing (~3.7m).
  Stream<Position> getPositionStream({
    String accuracyMode = 'high',
    int distanceFilterMeters = 3,
    int intervalSeconds = 1,
    String? activityKind,
  }) {
    int effectiveFilter = distanceFilterMeters;
    if (activityKind != null &&
        (activityKind == 'walk' ||
            activityKind == 'indoorWalk' ||
            activityKind == 'hike' ||
            activityKind == 'run' ||
            activityKind == 'trailRun')) {
      effectiveFilter = distanceFilterMeters.clamp(0, 1);
    } else if (activityKind != null &&
        (activityKind == 'roadCycling' ||
            activityKind == 'gravelCycling' ||
            activityKind == 'mtbCycling' ||
            activityKind == 'eBikeCycling')) {
      effectiveFilter = distanceFilterMeters.clamp(0, 2);
    }
    // Use LocationSettings for broad Android 8-14 compatibility, no timeLimit
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: _mapAccuracy(accuracyMode),
        distanceFilter: effectiveFilter,
      ),
    );
  }

  /// Get device heading/bearing (0-360 degrees, 0 = North)
  /// Returns null if heading is unavailable
  Future<double?> getHeading() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null && position.timestamp.difference(DateTime.now()).inMinutes.abs() < 1) {
        return position.heading;
      }
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 5));
      return current.heading;
    } catch (e) {
      return null;
    }
  }

  /// Open app settings (useful when permission is permanently denied)
  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }

  /// Android 12+ precise location check (fixes Samsung approximate location bug)
  /// If user granted only approximate (coarse), GPS will be city-level -> 0.06km bug
  Future<bool> isPreciseLocationGranted() async {
    try {
      final acc = await Geolocator.getLocationAccuracy();
      // LocationAccuracyStatus: precise vs reduced
      return acc.toString().contains('precise');
    } catch (_) {
      return true; // assume precise if API not available (Android <12)
    }
  }
}
