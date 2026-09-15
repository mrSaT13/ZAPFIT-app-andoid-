class ActivityMedia {
  final int? id;
  final int activityId;
  final String mediaPath;
  final int mediaType; // 1: Image, 2: Video
  final double? latitude;
  final double? longitude;
  final DateTime? takenAt;
  final String? caption;

  ActivityMedia({
    this.id,
    required this.activityId,
    required this.mediaPath,
    required this.mediaType,
    this.latitude,
    this.longitude,
    this.takenAt,
    this.caption,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'activity_id': activityId,
      'media_path': mediaPath,
      'media_type': mediaType,
      'latitude': latitude,
      'longitude': longitude,
      'taken_at_ms': takenAt?.millisecondsSinceEpoch,
      'caption': caption,
    };
  }

  factory ActivityMedia.fromMap(Map<String, Object?> map) {
    return ActivityMedia(
      id: map['id'] as int?,
      activityId: (map['activity_id'] as num?)?.toInt() ?? 0,
      mediaPath: (map['media_path'] as String?) ?? '',
      mediaType: (map['media_type'] as num?)?.toInt() ?? 1,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      takenAt: map['taken_at_ms'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['taken_at_ms'] as num).toInt())
          : null,
      caption: map['caption'] as String?,
    );
  }

  factory ActivityMedia.fromJson(Map<String, dynamic> json) {
    return ActivityMedia(
      id: (json['id'] as num?)?.toInt(),
      activityId: (json['activity_id'] as num).toInt(),
      mediaPath: (json['media_path'] as String?) ?? '',
      mediaType: (json['media_type'] as num?)?.toInt() ?? 1,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      takenAt: json['taken_at'] != null ? DateTime.tryParse(json['taken_at'].toString()) : null,
      caption: json['caption'] as String?,
    );
  }

  ActivityMedia copyWith({
    int? id,
    int? activityId,
    String? mediaPath,
    int? mediaType,
    double? latitude,
    double? longitude,
    DateTime? takenAt,
    String? caption,
    bool clearLatitude = false,
    bool clearLongitude = false,
  }) {
    return ActivityMedia(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaType: mediaType ?? this.mediaType,
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      takenAt: takenAt ?? this.takenAt,
      caption: caption ?? this.caption,
    );
  }
}
