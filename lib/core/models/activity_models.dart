import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class ActivityPoint {
  final int? id;
  final int activityId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? accuracy;
  final double distanceFromStartMeters;
  final int? heartRate;
  final int? cadence;
  final double? power;

  ActivityPoint({
    this.id,
    required this.activityId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.accuracy,
    required this.distanceFromStartMeters,
    this.heartRate,
    this.cadence,
    this.power,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'activity_id': activityId,
      'timestamp_ms': timestamp.millisecondsSinceEpoch,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'accuracy': accuracy,
      'distance_from_start': distanceFromStartMeters,
      'heart_rate': heartRate,
      'cadence': cadence,
      'power': power,
    };
  }

  factory ActivityPoint.fromMap(Map<String, Object?> map) {
    num toNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }
    double? toNullableDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    int? toNullableInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }
    return ActivityPoint(
      id: map['id'] as int?,
      activityId: toNum(map['activity_id']).toInt(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(toNum(map['timestamp_ms']).toInt()),
      latitude: toNum(map['latitude']).toDouble(),
      longitude: toNum(map['longitude']).toDouble(),
      altitude: toNullableDouble(map['altitude']),
      speed: toNullableDouble(map['speed']),
      accuracy: toNullableDouble(map['accuracy']),
      distanceFromStartMeters: toNum(map['distance_from_start']).toDouble(),
      heartRate: toNullableInt(map['heart_rate']),
      cadence: toNullableInt(map['cadence']),
      power: toNullableDouble(map['power']),
    );
  }

  ActivityPoint copyWith({
    int? id,
    int? activityId,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? altitude,
    double? speed,
    double? accuracy,
    double? distanceFromStartMeters,
    int? heartRate,
    int? cadence,
    double? power,
  }) {
    return ActivityPoint(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      distanceFromStartMeters: distanceFromStartMeters ?? this.distanceFromStartMeters,
      heartRate: heartRate ?? this.heartRate,
      cadence: cadence ?? this.cadence,
      power: power ?? this.power,
    );
  }
}

enum ActivityKind {
  run(1, 'Бег'),
  trailRun(2, 'Трейлраннинг'),
  trackRun(34, 'Бег по стадиону'),
  treadmillRun(40, 'Беговая дорожка'),
  virtualRun(3, 'Виртуальный бег'),
  roadCycling(4, 'Велосипед (шоссе)'),
  gravelCycling(5, 'Гревел'),
  mtbCycling(6, 'Маунтинбайк'),
  commutingCycling(27, 'Велопоездка на работу'),
  mixedSurfaceCycling(29, 'Смешанное покрытие (вело)'),
  virtualCycling(7, 'Виртуальный велоспорт'),
  indoorCycling(28, 'Велотренажер'),
  eBikeCycling(35, 'Электровелосипед'),
  eBikeMountainCycling(36, 'Электро-МТБ'),
  indoorSwimming(8, 'Плавание в бассейне'),
  openWaterSwimming(9, 'Плавание на открытой воде'),
  generalWorkout(10, 'Общая тренировка'),
  walk(11, 'Ходьба'),
  indoorWalk(31, 'Ходьба в помещении'),
  hike(12, 'Поход'),
  rowing(13, 'Гребля'),
  yoga(14, 'Йога'),
  alpineSki(15, 'Горные лыжи'),
  nordicSki(16, 'Беговые лыжи'),
  snowboard(17, 'Сноуборд'),
  iceSkate(37, 'Коньки'),
  transition(18, 'Транзитная зона'),
  strengthTraining(19, 'Силовая тренировка'),
  crossfit(20, 'Кроссфит'),
  tennis(21, 'Теннис'),
  tableTennis(22, 'Настольный теннис'),
  badminton(23, 'Бадминтон'),
  squash(24, 'Сквош'),
  racquetball(25, 'Ракетбол'),
  pickleball(26, 'Пиклбол'),
  padel(39, 'Падел'),
  windsurf(30, 'Виндсерфинг'),
  standUpPaddling(32, 'Сапбординг'),
  surf(33, 'Серфинг'),
  soccer(38, 'Футбол'),
  cardioTraining(41, 'Кардио'),
  kayaking(42, 'Каякинг'),
  sailing(43, 'Парусный спорт'),
  snowShoeing(44, 'Снегоступы'),
  inlineSkating(45, 'Роликовые коньки'),
  hiit(46, 'HIIT');

  final int value;
  final String labelRu;
  const ActivityKind(this.value, this.labelRu);

  static ActivityKind fromValue(int val) {
    return ActivityKind.values.firstWhere((e) => e.value == val, orElse: () => ActivityKind.run);
  }

  static ActivityKind fromName(String name) {
    return ActivityKind.values.firstWhere((e) => e.name == name, orElse: () => ActivityKind.run);
  }
}

enum UploadStatus { pending, uploaded, failed }

/// Source of activity: where it came from
enum ActivitySource { local, gpxImport, fitImport, healthConnect, serverSync }

class ActivityRecord {
  final int? id;
  final int? serverId;
  final int? userId;
  final String title;
  final ActivityKind kind;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double distanceMeters;
  final int durationSeconds;
  final String notes;
  final String? photoPath;
  final String? thumbnailUrl;
  final UploadStatus uploadStatus;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final int? gearId;
  final int visibility;
  final String? userName;
  final String? userPhotoUrl;
  final ActivitySource source;

  // ZAPFIT fitness metrics (nullable — absent in legacy server)
  final double? vo2max;
  final int? tss;
  final int? hrTss;
  final int? trimp;
  final double? intensityFactor;
  final double? aerobicTe;
  final double? anaerobicTe;
  final double? epoc;
  final int? sufferScore;
  final double? efficiencyFactor;

  const ActivityRecord({
    this.id,
    this.serverId,
    this.userId,
    required this.title,
    required this.kind,
    required this.startedAt,
    this.endedAt,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.notes = '',
    this.photoPath,
    this.thumbnailUrl,
    this.uploadStatus = UploadStatus.pending,
    this.avgHeartRate,
    this.maxHeartRate,
    this.gearId,
    this.visibility = 1,
    this.userName,
    this.userPhotoUrl,
    this.source = ActivitySource.local,
    this.vo2max,
    this.tss,
    this.hrTss,
    this.trimp,
    this.intensityFactor,
    this.aerobicTe,
    this.anaerobicTe,
    this.epoc,
    this.sufferScore,
    this.efficiencyFactor,
  });

  bool get isFinished => endedAt != null;

  ActivityRecord copyWith({
    int? id,
    int? serverId,
    int? userId,
    String? title,
    ActivityKind? kind,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    double? distanceMeters,
    int? durationSeconds,
    String? notes,
    String? photoPath,
    String? thumbnailUrl,
    UploadStatus? uploadStatus,
    int? avgHeartRate,
    int? maxHeartRate,
    int? gearId,
    int? visibility,
    String? userName,
    String? userPhotoUrl,
    ActivitySource? source,
    double? vo2max,
    int? tss,
    int? hrTss,
    int? trimp,
    double? intensityFactor,
    double? aerobicTe,
    double? anaerobicTe,
    double? epoc,
    int? sufferScore,
    double? efficiencyFactor,
  }) {
    return ActivityRecord(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      gearId: gearId ?? this.gearId,
      visibility: visibility ?? this.visibility,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      source: source ?? this.source,
      vo2max: vo2max ?? this.vo2max,
      tss: tss ?? this.tss,
      hrTss: hrTss ?? this.hrTss,
      trimp: trimp ?? this.trimp,
      intensityFactor: intensityFactor ?? this.intensityFactor,
      aerobicTe: aerobicTe ?? this.aerobicTe,
      anaerobicTe: anaerobicTe ?? this.anaerobicTe,
      epoc: epoc ?? this.epoc,
      sufferScore: sufferScore ?? this.sufferScore,
      efficiencyFactor: efficiencyFactor ?? this.efficiencyFactor,
    );
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'id': id,
      'server_id': serverId,
      'user_id': userId,
      'title': title,
      'kind': kind.name,
      'started_at_ms': startedAt.millisecondsSinceEpoch,
      'ended_at_ms': endedAt?.millisecondsSinceEpoch,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'notes': notes,
      'photo_path': photoPath,
      'thumbnail_url': thumbnailUrl,
      'upload_status': uploadStatus.name,
      'avg_heart_rate': avgHeartRate,
      'max_heart_rate': maxHeartRate,
      'gear_id': gearId,
      'visibility': visibility,
      'user_name': userName,
      'user_photo_url': userPhotoUrl,
      'source': source.name,
    };
    if (vo2max != null) map['vo2max'] = vo2max;
    if (tss != null) map['tss'] = tss;
    if (hrTss != null) map['hr_tss'] = hrTss;
    if (trimp != null) map['trimp'] = trimp;
    if (intensityFactor != null) map['intensity_factor'] = intensityFactor;
    if (aerobicTe != null) map['aerobic_te'] = aerobicTe;
    if (anaerobicTe != null) map['anaerobic_te'] = anaerobicTe;
    if (epoc != null) map['epoc'] = epoc;
    if (sufferScore != null) map['suffer_score'] = sufferScore;
    if (efficiencyFactor != null) map['efficiency_factor'] = efficiencyFactor;
    return map;
  }

  factory ActivityRecord.fromMap(Map<String, Object?> map) {
    final rawKind = map['kind'] as String?;
    final kind = ActivityKind.values.firstWhere(
      (value) => value.name == rawKind,
      orElse: () => ActivityKind.run,
    );
    final rawUploadStatus = map['upload_status'] as String?;
    final uploadStatus = UploadStatus.values.firstWhere(
      (value) => value.name == rawUploadStatus,
      orElse: () => UploadStatus.pending,
    );

    return ActivityRecord(
      id: map['id'] as int?,
      serverId: map['server_id'] as int?,
      userId: map['user_id'] as int?,
      title: map['title'] as String? ?? 'Activity',
      kind: kind,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at_ms'] as int),
      endedAt: map['ended_at_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['ended_at_ms'] as int),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
      notes: map['notes'] as String? ?? '',
      photoPath: map['photo_path'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      uploadStatus: uploadStatus,
      avgHeartRate: map['avg_heart_rate'] as int?,
      maxHeartRate: map['max_heart_rate'] as int?,
      gearId: map['gear_id'] as int?,
      visibility: map['visibility'] as int? ?? 1,
      userName: map['user_name'] as String?,
      userPhotoUrl: map['user_photo_url'] as String?,
      source: ActivitySource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => ActivitySource.local,
      ),
      // ZAPFIT fitness metrics (nullable)
      vo2max: (map['vo2max'] as num?)?.toDouble(),
      tss: map['tss'] as int?,
      hrTss: map['hr_tss'] as int?,
      trimp: map['trimp'] as int?,
      intensityFactor: (map['intensity_factor'] as num?)?.toDouble(),
      aerobicTe: (map['aerobic_te'] as num?)?.toDouble(),
      anaerobicTe: (map['anaerobic_te'] as num?)?.toDouble(),
      epoc: (map['epoc'] as num?)?.toDouble(),
      sufferScore: map['suffer_score'] as int?,
      efficiencyFactor: (map['efficiency_factor'] as num?)?.toDouble(),
    );
  }

  factory ActivityRecord.fromServerJson(Map<String, dynamic> json) {
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    double? toDoubleNullable(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    try {
      final sId = toInt(json['id']);
      final uId = toInt(json['user_id']);
      final title = json['name']?.toString() ?? json['title']?.toString() ?? 'Activity';
      final typeId = toInt(json['activity_type']) ?? 1;

      final startTimeStr = json['start_time']?.toString() ?? json['started_at']?.toString();
      final startTime = startTimeStr != null ? DateTime.tryParse(startTimeStr) ?? DateTime.now() : DateTime.now();

      final endTimeStr = json['end_time']?.toString() ?? json['ended_at']?.toString();
      final endTime = endTimeStr != null ? DateTime.tryParse(endTimeStr) : null;

      final avgHr = toInt(json['average_hr'] ?? json['average_heart_rate'] ?? json['avg_hr'] ?? json['average_hr_bpm']);
      final maxHr = toInt(json['max_hr'] ?? json['max_heart_rate'] ?? json['max_hr_bpm']);

      String? uName = json['user_name']?.toString();
      String? uPhoto = json['user_photo_url']?.toString() ?? json['user_photo']?.toString();
      
      if (json['user'] is Map) {
        final userData = json['user'] as Map<String, dynamic>;
        uName ??= userData['name']?.toString() ?? userData['username']?.toString();
        uPhoto ??= userData['photo_path']?.toString() ?? userData['photo_url']?.toString();
      }

      return ActivityRecord(
        serverId: sId,
        userId: uId,
        title: title,
        kind: ActivityKind.fromValue(typeId == 0 ? 1 : typeId),
        startedAt: startTime,
        endedAt: endTime,
        distanceMeters: toDouble(json['distance'] ?? json['distance_meters']),
        durationSeconds: toInt(json['total_timer_time'] ?? json['duration_seconds']) ?? 0,
        thumbnailUrl: json['map_thumbnail_path']?.toString() ?? json['thumbnail_url']?.toString(),
        uploadStatus: UploadStatus.uploaded,
        avgHeartRate: avgHr,
        maxHeartRate: maxHr,
        gearId: toInt(json['gear_id']),
        visibility: toInt(json['visibility']) ?? 1,
        userName: uName,
        userPhotoUrl: uPhoto,
        notes: json['description']?.toString() ?? json['notes']?.toString() ?? '',
        source: ActivitySource.serverSync,
        // ZAPFIT fitness metrics (nullable — absent in legacy server)
        vo2max: toDoubleNullable(json['vo2max']),
        tss: toInt(json['tss']),
        hrTss: toInt(json['hr_tss']),
        trimp: toInt(json['trimp']),
        intensityFactor: toDoubleNullable(json['intensity_factor']),
        aerobicTe: toDoubleNullable(json['aerobic_te']),
        anaerobicTe: toDoubleNullable(json['anaerobic_te']),
        epoc: toDoubleNullable(json['epoc']),
        sufferScore: toInt(json['suffer_score']),
        efficiencyFactor: toDoubleNullable(json['efficiency_factor']),
      );
    } catch (e) {
      debugPrint('ActivityRecord.fromServerJson Error: $e');
      rethrow;
    }
  }
}

class TrackingSnapshot {
  final bool isRecording;
  final bool isPaused;
  final int? activityId;
  final ActivityKind? kind;
  final DateTime? startedAt;
  final double distanceMeters;
  final int elapsedSeconds;
  final int pointsCount;
  final int? currentHeartRate;
  final int? currentCadence;

  const TrackingSnapshot({
    required this.isRecording,
    required this.isPaused,
    required this.activityId,
    required this.kind,
    required this.startedAt,
    required this.distanceMeters,
    required this.elapsedSeconds,
    required this.pointsCount,
    this.currentHeartRate,
    this.currentCadence,
  });

  static const empty = TrackingSnapshot(
    isRecording: false,
    isPaused: false,
    activityId: null,
    kind: null,
    startedAt: null,
    distanceMeters: 0,
    elapsedSeconds: 0,
    pointsCount: 0,
  );
}

double distanceInMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _toRadians(double degree) {
  return degree * (math.pi / 180.0);
}
