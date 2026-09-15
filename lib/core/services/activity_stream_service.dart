import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/di/service_locator.dart';

class ActivityStreamService {
  final ApiClient _apiClient = serviceLocator<ApiClient>();

  /// Possible identifiers for a GPS coordinate stream in the upstream payload.
  /// Endurain server uses stream_type=7 for lat/lon GPS data.
  static const List<dynamic> _gpsStreamTypeIds = [
    7, '7', 'gps', 'GPS', 'location', 'latlng', 'lat_lng', 'coordinate', 'coordinates',
  ];

  /// Possible field names for each coordinate in a waypoint.
  static const List<String> _latKeys = ['lat', 'latitude'];
  static const List<String> _lngKeys = ['lng', 'longitude', 'lon'];
  static const List<String> _altKeys = ['alt', 'altitude', 'elevation', 'ele'];
  static const List<String> _speedKeys = ['velocity_smooth', 'speed', 'velocity', 'spd'];
  static const List<String> _distKeys = ['dist', 'distance', 'distance_from_start'];
  static const List<String> _timeKeys = ['time', 'timestamp', 't', 'ts', 'elapsed'];

  Future<List<ActivityPoint>> getStreamPoints(int serverActivityId) async {
    try {
      final response = await _apiClient.get(
        '/api/v1/activities_streams/activity_id/$serverActivityId/all',
      );

      if (response.statusCode != 200) {
        debugPrint('ActivityStreamService: HTTP ${response.statusCode} '
            'for activity $serverActivityId. Body: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
        return [];
      }

      final dynamic decoded = json.decode(response.body);
      if (decoded is! List) {
        debugPrint('ActivityStreamService: payload is not a list (${decoded.runtimeType})');
        return [];
      }

      // Find the GPS stream among the available ones.
      final data = decoded;
      Map<String, dynamic>? gpsStream;
      for (final s in data) {
        if (s is! Map) continue;
        final t = s['stream_type'] ?? s['type'] ?? s['streamType'];
        if (t == null) continue;
        for (final id in _gpsStreamTypeIds) {
          if (t.toString().toLowerCase() == id.toString().toLowerCase()) {
            gpsStream = s.cast<String, dynamic>();
            break;
          }
        }
        if (gpsStream != null) break;
      }

      if (gpsStream == null) {
        debugPrint('ActivityStreamService: no GPS stream found. '
            'Available types: ${data.whereType<Map>().map((m) => m['stream_type'] ?? m['type']).toList()}');
        return [];
      }

      // The waypoints can be under several possible field names.
      final dynamic rawWaypoints = gpsStream['stream_waypoints'] ??
          gpsStream['waypoints'] ??
          gpsStream['points'] ??
          gpsStream['data'] ??
          gpsStream['values'];

      if (rawWaypoints is! List || rawWaypoints.isEmpty) {
        debugPrint('ActivityStreamService: GPS stream has no waypoints array');
        return [];
      }

      final List<ActivityPoint> out = [];
      double? prevDist;
      int index = 0;
      for (final w in rawWaypoints) {
        final point = _parseWaypoint(w, index, prevDist);
        if (point != null) {
          out.add(point);
          prevDist = point.distanceFromStartMeters;
        }
        index++;
      }

      debugPrint('ActivityStreamService: parsed ${out.length} / ${rawWaypoints.length} waypoints');
      return out;
    } catch (e, st) {
      debugPrint('ActivityStreamService: error fetching streams: $e\n$st');
      return [];
    }
  }

  /// Parse a single waypoint. Returns null for invalid entries.
  ActivityPoint? _parseWaypoint(dynamic w, int index, double? prevDist) {
    try {
      if (w is Map) {
        final lat = _readDouble(w, _latKeys);
        final lng = _readDouble(w, _lngKeys);
        if (lat == null || lng == null) return null;
        if (lat.isNaN || lng.isNaN || lat.abs() > 90 || lng.abs() > 180) return null;

        final ts = _readTimestamp(w) ?? DateTime.now();
        final dist = _readDouble(w, _distKeys) ?? _fallbackDistance(prevDist, index);
        final alt = _readDouble(w, _altKeys);
        final speed = _readDouble(w, _speedKeys);

        return ActivityPoint(
          activityId: 0,
          timestamp: ts,
          latitude: lat,
          longitude: lng,
          altitude: alt,
          speed: speed,
          distanceFromStartMeters: dist,
        );
      }
      if (w is List) {
        // Some serializers output [lat, lng, alt, dist, time, ...]
        if (w.length < 2) return null;
        final lat = _asDouble(w[0]);
        final lng = _asDouble(w[1]);
        if (lat == null || lng == null) return null;
        if (lat.isNaN || lng.isNaN || lat.abs() > 90 || lng.abs() > 180) return null;
        final alt = w.length > 2 ? _asDouble(w[2]) : null;
        final dist = w.length > 3
            ? (_asDouble(w[3]) ?? _fallbackDistance(prevDist, index))
            : _fallbackDistance(prevDist, index);
        final speed = w.length > 4 ? _asDouble(w[4]) : null;
        final ts = w.length > 5 ? _readTimestamp({'ts': w[5]}) ?? DateTime.now() : DateTime.now();
        return ActivityPoint(
          activityId: 0,
          timestamp: ts,
          latitude: lat,
          longitude: lng,
          altitude: alt,
          speed: speed,
          distanceFromStartMeters: dist,
        );
      }
    } catch (e) {
      debugPrint('ActivityStreamService: waypoint parse error: $e');
    }
    return null;
  }

  double? _readDouble(Map w, List<String> keys) {
    for (final k in keys) {
      if (w.containsKey(k)) {
        final v = _asDouble(w[k]);
        if (v != null) return v;
      }
    }
    return null;
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  DateTime? _readTimestamp(Map w) {
    for (final k in _timeKeys) {
      if (!w.containsKey(k)) continue;
      final v = w[k];
      if (v == null) continue;
      if (v is num) {
        // Heuristic: > 1e11 => milliseconds, else seconds.
        if (v > 1e11) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
        return DateTime.fromMillisecondsSinceEpoch((v.toDouble() * 1000).toInt());
      }
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
        final asNum = num.tryParse(v);
        if (asNum != null) {
          if (asNum > 1e11) return DateTime.fromMillisecondsSinceEpoch(asNum.toInt());
          return DateTime.fromMillisecondsSinceEpoch((asNum.toDouble() * 1000).toInt());
        }
      }
    }
    return null;
  }

  double _fallbackDistance(double? prev, int index) {
    // [comment removed - encoding corrupted]
    if (prev != null) return prev + 10.0;
    return index * 10.0;
  }
}
