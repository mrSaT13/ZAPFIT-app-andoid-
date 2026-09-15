class GearPhoto {
  final int? id;
  final int gearId;
  final String filePath;
  final DateTime createdAt;
  final int? serverId;
  final bool synced;

  GearPhoto({
    this.id,
    required this.gearId,
    required this.filePath,
    DateTime? createdAt,
    this.serverId,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isServerCached => serverId != null;

  Map<String, dynamic> toDbMap() => {
    if (id != null) 'id': id,
    'gear_id': gearId,
    'file_path': filePath,
    'created_at': createdAt.toIso8601String(),
    if (serverId != null) 'server_id': serverId,
    'synced': synced ? 1 : 0,
  };

  factory GearPhoto.fromDbMap(Map<String, dynamic> map) => GearPhoto(
    id: map['id'] as int?,
    gearId: map['gear_id'] as int,
    filePath: map['file_path'] as String,
    createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    serverId: map['server_id'] as int?,
    synced: (map['synced'] as int? ?? 0) == 1,
  );

  GearPhoto copyWith({
    int? id,
    int? gearId,
    String? filePath,
    DateTime? createdAt,
    int? serverId,
    bool? synced,
  }) {
    return GearPhoto(
      id: id ?? this.id,
      gearId: gearId ?? this.gearId,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      serverId: serverId ?? this.serverId,
      synced: synced ?? this.synced,
    );
  }
}
