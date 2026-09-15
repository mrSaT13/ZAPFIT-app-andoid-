import 'dart:math' as math;

/// Простой Kalman для GPS: сглаживает lat/lon, отбрасывает выбросы.
/// Идея из доработки карты_gps / фоновое_отслеживание (TrackrecordDao, GPSSignalIndicator).
class GpsKalmanFilter {
  double? _lat;
  double? _lon;
  double _variance = -1;
  final double _q; // process noise

  GpsKalmanFilter({double q = 0.5}) : _q = q;

  /// Возвращает отфильтрованную позицию или null если выброс (>3 сигм).
  /// accuracy в метрах используется как measurement noise.
  ({double lat, double lon})? filter(double lat, double lon, double accuracy) {
    final mNoise = (accuracy <= 0 ? 10.0 : accuracy) / 3.0;
    final measurementVariance = mNoise * mNoise;

    if (_variance < 0) {
      _lat = lat;
      _lon = lon;
      _variance = measurementVariance;
      return (lat: lat, lon: lon);
    }

    // предсказание
    _variance += _q;

    // обновление
    final k = _variance / (_variance + measurementVariance);
    final dLat = lat - _lat!;
    final dLon = lon - _lon!;
    final dist = _haversineMeters(_lat!, _lon!, lat, lon);
    // выброс: адаптивный порог с учётом accuracy
    // Android 12 without internet may give large accuracy spikes; use +50 like old working build
    if (dist > accuracy * 3 + 50) {
      // не обновляем состояние, но увеличиваем variance
      _variance = math.min(_variance * 1.5, 10000);
      return null;
    }

    _lat = _lat! + k * dLat;
    _lon = _lon! + k * dLon;
    _variance = (1 - k) * _variance;

    return (lat: _lat!, lon: _lon!);
  }

  void reset() {
    _lat = null;
    _lon = null;
    _variance = -1;
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}
