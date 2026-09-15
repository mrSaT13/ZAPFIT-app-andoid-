class TrackPoint {
  TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitudeMeters,
    this.heartRate,
    this.cadence,
  }) {
    _validateLatitude(latitude);
    _validateLongitude(longitude);
    _validateAltitude(altitudeMeters);
  }

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitudeMeters;
  final int? heartRate;
  final int? cadence;

  TrackPoint copyWith({
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? altitudeMeters,
    int? heartRate,
    int? cadence,
    bool clearAltitude = false,
  }) {
    return TrackPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      altitudeMeters: clearAltitude
          ? null
          : (altitudeMeters ?? this.altitudeMeters),
      heartRate: heartRate ?? this.heartRate,
      cadence: cadence ?? this.cadence,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'altitudeMeters': altitudeMeters,
      'heartRate': heartRate,
      'cadence': cadence,
    };
  }

  factory TrackPoint.fromJson(Map<String, dynamic> json) {
    return TrackPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble(),
      heartRate: (json['heartRate'] as num?)?.toInt(),
      cadence: (json['cadence'] as num?)?.toInt(),
    );
  }

  static void _validateLatitude(double value) {
    if (value < -90 || value > 90) {
      throw ArgumentError.value(value, 'latitude', 'Latitude out of bounds');
    }
  }

  static void _validateLongitude(double value) {
    if (value < -180 || value > 180) {
      throw ArgumentError.value(value, 'longitude', 'Longitude out of bounds');
    }
  }

  static void _validateAltitude(double? value) {
    if (value == null) return;
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        'altitudeMeters',
        'Altitude must be finite',
      );
    }
  }
}

enum ActivityType { run, ride, walk }

enum UploadStatus { pending, uploading, uploaded, failed }

ActivityType activityTypeFromJson(String raw) {
  switch (raw) {
    case 'run':
      return ActivityType.run;
    case 'ride':
      return ActivityType.ride;
    case 'walk':
      return ActivityType.walk;
  }
  throw ArgumentError.value(raw, 'raw', 'Unsupported activity type');
}

String activityTypeToJson(ActivityType type) {
  switch (type) {
    case ActivityType.run:
      return 'run';
    case ActivityType.ride:
      return 'ride';
    case ActivityType.walk:
      return 'walk';
  }
}

class Activity {
  Activity({
    required this.id,
    required this.activityType,
    this.activityTypeId,
    required this.startedAt,
    this.endedAt,
    this.name,
    this.uploaded = false,
    UploadStatus? uploadStatus,
    required this.distanceMeters,
    Map<String, dynamic>? qualityMetrics,
    required List<TrackPoint> trackPoints,
  }) : uploadStatus = uploadStatus ?? ( (uploaded) ? UploadStatus.uploaded : UploadStatus.pending ),
       trackPoints = List<TrackPoint>.unmodifiable(trackPoints),
       qualityMetrics = qualityMetrics == null
           ? null
           : Map<String, dynamic>.unmodifiable(
               Map<String, dynamic>.from(qualityMetrics),
             ) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Activity id cannot be empty');
    }
    if (distanceMeters < 0) {
      throw ArgumentError.value(
        distanceMeters,
        'distanceMeters',
        'Distance cannot be negative',
      );
    }
    if (endedAt != null && endedAt!.isBefore(startedAt)) {
      throw ArgumentError.value(
        endedAt,
        'endedAt',
        'endedAt cannot be before startedAt',
      );
    }
    if (name != null && name!.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Activity name cannot be blank');
    }
  }

  final String id;
  final ActivityType activityType;
  final int? activityTypeId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? name;
  final bool uploaded;
  final double distanceMeters;
  final Map<String, dynamic>? qualityMetrics;
  final List<TrackPoint> trackPoints;
  static const double _elevationDeltaNoiseThresholdMeters = 1.5;
  final UploadStatus uploadStatus;

  int get durationSeconds {
    final end = endedAt;
    if (end == null) return 0;
    return end.difference(startedAt).inSeconds;
  }

  double? get averagePaceSecondsPerKm {
    if (distanceMeters <= 0 || durationSeconds <= 0) return null;
    final distanceKm = distanceMeters / 1000;
    if (distanceKm <= 0) return null;
    return durationSeconds / distanceKm;
  }

  double? get averageSpeedKmh {
    if (distanceMeters <= 0 || durationSeconds <= 0) return null;
    final metersPerSecond = distanceMeters / durationSeconds;
    if (!metersPerSecond.isFinite || metersPerSecond <= 0) return null;
    return metersPerSecond * 3.6;
  }

  double? get averageHeartRateBpm {
    if (trackPoints.isNotEmpty) {
      final values = trackPoints
          .map((p) => p.heartRate)
          .whereType<int>()
          .where((value) => value > 0)
          .toList();
      if (values.isNotEmpty) {
        final total = values.fold<int>(0, (sum, value) => sum + value);
        return total / values.length;
      }
    }
    return _metricAsDouble('avg_heart_rate_bpm');
  }

  double? get averageCadenceRpm {
    if (trackPoints.isNotEmpty) {
      final values = trackPoints
          .map((p) => p.cadence)
          .whereType<int>()
          .where((value) => value > 0)
          .toList();
      if (values.isNotEmpty) {
        final total = values.fold<int>(0, (sum, value) => sum + value);
        return total / values.length;
      }
    }
    return _metricAsDouble('avg_cadence_rpm');
  }

  double get elevationGainMeters {
    final metricGain =
        _metricAsDouble('filtered_elevation_gain_meters') ??
        _metricAsDouble('elevation_gain_meters');
    if (metricGain != null) return metricGain;
    if (trackPoints.length < 2) return 0;
    var gain = 0.0;
    for (var i = 1; i < trackPoints.length; i++) {
      final previous = trackPoints[i - 1].altitudeMeters;
      final current = trackPoints[i].altitudeMeters;
      if (previous == null || current == null) continue;
      final delta = current - previous;
      if (delta >= _elevationDeltaNoiseThresholdMeters) {
        gain += delta;
      }
    }
    return gain;
  }

  double get elevationLossMeters {
    final metricLoss =
        _metricAsDouble('filtered_elevation_loss_meters') ??
        _metricAsDouble('elevation_loss_meters');
    if (metricLoss != null) return metricLoss;
    if (trackPoints.length < 2) return 0;
    var loss = 0.0;
    for (var i = 1; i < trackPoints.length; i++) {
      final previous = trackPoints[i - 1].altitudeMeters;
      final current = trackPoints[i].altitudeMeters;
      if (previous == null || current == null) continue;
      final delta = current - previous;
      if (delta <= -_elevationDeltaNoiseThresholdMeters) {
        loss += -delta;
      }
    }
    return loss;
  }

  bool get isInProgress => endedAt == null;
  bool get isCompleted => endedAt != null;

  Activity copyWith({
    String? id,
    ActivityType? activityType,
    int? activityTypeId,
    bool clearActivityTypeId = false,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    String? name,
    bool clearName = false,
    bool? uploaded,
    UploadStatus? uploadStatus,
    double? distanceMeters,
    Map<String, dynamic>? qualityMetrics,
    bool clearQualityMetrics = false,
    List<TrackPoint>? trackPoints,
  }) {
    return Activity(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      activityTypeId: clearActivityTypeId
          ? null
          : (activityTypeId ?? this.activityTypeId),
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      name: clearName ? null : (name ?? this.name),
      uploaded: uploaded ?? this.uploaded,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      qualityMetrics: clearQualityMetrics
          ? null
          : (qualityMetrics ?? this.qualityMetrics),
      trackPoints: trackPoints ?? this.trackPoints,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityType': activityTypeToJson(activityType),
      'activityTypeId': activityTypeId,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'name': name,
      'uploaded': uploaded,
      'uploadStatus': uploadStatus.toString().split('.').last,
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'qualityMetrics': qualityMetrics,
      'trackPoints': trackPoints.map((point) => point.toJson()).toList(),
    };
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    final points = (json['trackPoints'] as List<dynamic>? ?? [])
        .map((raw) => TrackPoint.fromJson(raw as Map<String, dynamic>))
        .toList();

    return Activity(
      id: json['id'] as String,
      activityType: activityTypeFromJson(json['activityType'] as String),
      activityTypeId: (json['activityTypeId'] as num?)?.toInt(),
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      name: json['name'] as String?,
      uploaded: json['uploaded'] as bool? ?? false,
      uploadStatus: (() {
        final raw = json['uploadStatus'] as String?;
        if (raw == null) {
          return (json['uploaded'] as bool? ?? false)
              ? UploadStatus.uploaded
              : UploadStatus.pending;
        }
        switch (raw) {
          case 'pending':
            return UploadStatus.pending;
          case 'uploading':
            return UploadStatus.uploading;
          case 'uploaded':
            return UploadStatus.uploaded;
          case 'failed':
            return UploadStatus.failed;
          default:
            return UploadStatus.pending;
        }
      })(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      qualityMetrics: json['qualityMetrics'] == null
          ? null
          : Map<String, dynamic>.from(
              json['qualityMetrics'] as Map<dynamic, dynamic>,
            ),
      trackPoints: points,
    );
  }

  double? _metricAsDouble(String key) {
    final metrics = qualityMetrics;
    if (metrics == null) return null;
    final raw = metrics[key];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }
}
