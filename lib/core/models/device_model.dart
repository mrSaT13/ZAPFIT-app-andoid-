enum DeviceCategory {
  smartBand,
  smartWatch,
  heartRateMonitor,
  cyclingSensor,
  smartScale,
  other,
}

enum DeviceBrand {
  xiaomi,
  amazfit,
  huawei,
  garmin,
  polar,
  wahoo,
  generic,
  unknown,
}

extension DeviceBrandLabel on DeviceBrand {
  String get label {
    switch (this) {
      case DeviceBrand.xiaomi:
        return 'Xiaomi';
      case DeviceBrand.amazfit:
        return 'Amazfit';
      case DeviceBrand.huawei:
        return 'Huawei';
      case DeviceBrand.garmin:
        return 'Garmin';
      case DeviceBrand.polar:
        return 'Polar';
      case DeviceBrand.wahoo:
        return 'Wahoo';
      case DeviceBrand.generic:
        return 'Generic';
      case DeviceBrand.unknown:
        return '';
    }
  }
}

class TrackedDevice {
  final String id;
  final String name;
  final DeviceCategory category;
  final DeviceBrand brand;
  final int? batteryLevel;
  final DateTime? lastSeen;
  final bool isConnected;
  final Map<String, dynamic> capabilities;
  final String? firmwareVersion;
  final int? rssi;
  final String? coordinatorId;

  const TrackedDevice({
    required this.id,
    required this.name,
    this.category = DeviceCategory.other,
    this.brand = DeviceBrand.unknown,
    this.batteryLevel,
    this.lastSeen,
    this.isConnected = false,
    this.capabilities = const {},
    this.firmwareVersion,
    this.rssi,
    this.coordinatorId,
  });

  TrackedDevice copyWith({
    String? id,
    String? name,
    DeviceCategory? category,
    DeviceBrand? brand,
    int? batteryLevel,
    DateTime? lastSeen,
    bool? isConnected,
    Map<String, dynamic>? capabilities,
    String? firmwareVersion,
    int? rssi,
    String? coordinatorId,
  }) {
    return TrackedDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastSeen: lastSeen ?? this.lastSeen,
      isConnected: isConnected ?? this.isConnected,
      capabilities: capabilities ?? this.capabilities,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      rssi: rssi ?? this.rssi,
      coordinatorId: coordinatorId ?? this.coordinatorId,
    );
  }

  String get categoryLabel {
    switch (category) {
      case DeviceCategory.smartBand:
        return 'Фитнес-браслет';
      case DeviceCategory.smartWatch:
        return 'Умные часы';
      case DeviceCategory.heartRateMonitor:
        return 'Пульсометр';
      case DeviceCategory.cyclingSensor:
        return 'Велосипедный датчик';
      case DeviceCategory.smartScale:
        return 'Умные весы';
      case DeviceCategory.other:
        return 'Устройство';
    }
  }

  String get brandLabel {
    switch (brand) {
      case DeviceBrand.xiaomi:
        return 'Xiaomi';
      case DeviceBrand.amazfit:
        return 'Amazfit';
      case DeviceBrand.huawei:
        return 'Huawei';
      case DeviceBrand.garmin:
        return 'Garmin';
      case DeviceBrand.polar:
        return 'Polar';
      case DeviceBrand.wahoo:
        return 'Wahoo';
      case DeviceBrand.generic:
        return 'Generic';
      case DeviceBrand.unknown:
        return '';
    }
  }

  static DeviceBrand detectBrand(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('mi band') || lower.contains('mi smart') || lower.contains('redmi')) {
      return DeviceBrand.xiaomi;
    }
    if (lower.contains('amazfit') || lower.contains('gtr') || lower.contains('gts') || lower.contains('bip') || lower.contains('t-rex')) {
      return DeviceBrand.amazfit;
    }
    if (lower.contains('huawei') || lower.contains('honor band') || lower.contains('honor watch')) {
      return DeviceBrand.huawei;
    }
    if (lower.contains('garmin')) {
      return DeviceBrand.garmin;
    }
    if (lower.contains('polar')) {
      return DeviceBrand.polar;
    }
    if (lower.contains('wahoo')) {
      return DeviceBrand.wahoo;
    }
    if (lower.contains('pebble') || lower.contains('rebble')) {
      return DeviceBrand.generic; // No dedicated brand for Pebble
    }
    if (lower.contains('pinetime') || lower.contains('infinitime') || lower.contains('pine64')) {
      return DeviceBrand.generic;
    }
    if (lower.contains('bangle') || lower.contains('js')) {
      return DeviceBrand.generic;
    }
    return DeviceBrand.unknown;
  }

  static DeviceCategory detectCategory(String name, List<String> serviceUuidStrings) {
    final lower = name.toLowerCase();

    for (final uuid in serviceUuidStrings) {
      final id = uuid.toLowerCase().replaceAll('-', '');
      if (id == '180d') return DeviceCategory.heartRateMonitor;
      if (id == '1816') return DeviceCategory.cyclingSensor;
      if (id == '1818') return DeviceCategory.cyclingSensor;
    }

    if (lower.contains('band') || lower.contains('bracelet') || lower.contains('smart band')) {
      return DeviceCategory.smartBand;
    }
    if (lower.contains('watch') || lower.contains('clock') || lower.contains('gtr') || lower.contains('gts')) {
      return DeviceCategory.smartWatch;
    }
    if (lower.contains('hr') || lower.contains('heart') || lower.contains('pulse') || lower.contains('h10') || lower.contains('h9') || lower.contains('h7') || lower.contains('tickr')) {
      return DeviceCategory.heartRateMonitor;
    }
    if (lower.contains('scale') || lower.contains('weight') || lower.contains('body')) {
      return DeviceCategory.smartScale;
    }
    if (lower.contains('cadence') || lower.contains('speed') || lower.contains('power') || lower.contains('cycling')) {
      return DeviceCategory.cyclingSensor;
    }
    if (lower.contains('bip') || lower.contains('t-rex') || lower.contains('pace')) {
      return DeviceCategory.smartWatch;
    }

    return DeviceCategory.other;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.index,
      'brand': brand.index,
      'battery_level': batteryLevel,
      'last_seen': lastSeen?.toIso8601String(),
      'capabilities': capabilities,
      'firmware_version': firmwareVersion,
      'coordinator_id': coordinatorId,
    };
  }

  factory TrackedDevice.fromJson(Map<String, dynamic> json) {
    return TrackedDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      category: DeviceCategory.values[json['category'] as int? ?? DeviceCategory.other.index],
      brand: DeviceBrand.values[json['brand'] as int? ?? DeviceBrand.unknown.index],
      batteryLevel: json['battery_level'] as int?,
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen'] as String) : null,
      capabilities: (json['capabilities'] as Map<String, dynamic>?) ?? {},
      firmwareVersion: json['firmware_version'] as String?,
      coordinatorId: json['coordinator_id'] as String?,
    );
  }
}
