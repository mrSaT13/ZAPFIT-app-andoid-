class GearRecord {
  final int id;
  final String nickname;
  final String? brand;
  final String? model;
  final int gearType;
  final double totalDistance;
  final double totalTime;
  final double initialKms;
  final bool active;
  final double? purchaseValue;
  final double? wheelDiameterCm;

  GearRecord({
    required this.id,
    required this.nickname,
    this.brand,
    this.model,
    required this.gearType,
    required this.totalDistance,
    required this.totalTime,
    this.initialKms = 0.0,
    required this.active,
    this.purchaseValue,
    this.wheelDiameterCm,
  });

  factory GearRecord.fromJson(Map<String, dynamic> json) {
    return GearRecord(
      id: (json['id'] as num).toInt(),
      nickname: (json['nickname'] as String?) ?? 'Без названия',
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      gearType: (json['gear_type'] as num?)?.toInt() ?? 1,
      totalDistance: (json['total_distance'] as num?)?.toDouble() ?? 0.0,
      totalTime: (json['total_time'] as num?)?.toDouble() ?? 0.0,
      initialKms: (json['initial_kms'] as num?)?.toDouble() ?? 0.0,
      active: (json['active'] as bool?) ?? true,
      purchaseValue: (json['purchase_value'] as num?)?.toDouble(),
      wheelDiameterCm: (json['wheel_diameter_cm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nickname': nickname,
    'brand': brand,
    'model': model,
    'gear_type': gearType,
    'initial_kms': initialKms,
    'active': active,
    if (purchaseValue != null) 'purchase_value': purchaseValue,
    if (wheelDiameterCm != null) 'wheel_diameter_cm': wheelDiameterCm,
  };

  GearRecord copyWith({
    int? id,
    String? nickname,
    String? brand,
    String? model,
    int? gearType,
    double? totalDistance,
    double? totalTime,
    double? initialKms,
    bool? active,
    double? purchaseValue,
    double? wheelDiameterCm,
  }) {
    return GearRecord(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      gearType: gearType ?? this.gearType,
      totalDistance: totalDistance ?? this.totalDistance,
      totalTime: totalTime ?? this.totalTime,
      initialKms: initialKms ?? this.initialKms,
      active: active ?? this.active,
      purchaseValue: purchaseValue ?? this.purchaseValue,
      wheelDiameterCm: wheelDiameterCm ?? this.wheelDiameterCm,
    );
  }

  double get displayMileageKm => (totalDistance / 1000) + initialKms;

  String get typeLabel {
    switch (gearType) {
      case 1: return 'Велосипед';
      case 2: return 'Кроссовки';
      case 3: return 'Гидрокостюм';
      case 4: return 'Ракетка';
      case 5: return 'Лыжи';
      case 6: return 'Сноуборд';
      case 7: return 'Виндсёрф';
      case 8: return 'Водный спорт';
      default: return 'Снаряжение';
    }
  }
}

class GearImage {
  final int id;
  final int gearId;
  final String imagePath;
  final String? imageUrl;
  final DateTime? createdAt;

  GearImage({
    required this.id,
    required this.gearId,
    required this.imagePath,
    this.imageUrl,
    this.createdAt,
  });

  factory GearImage.fromJson(Map<String, dynamic> json) {
    return GearImage(
      id: (json['id'] as num).toInt(),
      gearId: (json['gear_id'] as num).toInt(),
      imagePath: (json['image_path'] as String?) ?? '',
      imageUrl: json['image_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

enum IconName { bike, shoes, gear }

class GearDetail {
  final int id;
  final String nickname;
  final String? brand;
  final String? model;
  final int gearType;
  final bool active;
  final double totalDistance;
  final double totalTime;
  final double? initialKms;
  final double? purchaseValue;
  final double? wheelDiameterCm;
  final double totalComponentsCost;
  final DateTime? createdAt;
  final String? stravaGearId;
  final String? garminconnectGearId;

  GearDetail({
    required this.id,
    required this.nickname,
    this.brand,
    this.model,
    required this.gearType,
    required this.active,
    required this.totalDistance,
    required this.totalTime,
    this.initialKms,
    this.purchaseValue,
    this.wheelDiameterCm,
    required this.totalComponentsCost,
    this.createdAt,
    this.stravaGearId,
    this.garminconnectGearId,
  });

  factory GearDetail.fromJson(Map<String, dynamic> json) {
    return GearDetail(
      id: (json['id'] as num).toInt(),
      nickname: (json['nickname'] as String?) ?? 'Без названия',
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      gearType: (json['gear_type'] as num?)?.toInt() ?? 1,
      active: (json['active'] as bool?) ?? true,
      totalDistance: (json['total_distance'] as num?)?.toDouble() ?? 0.0,
      totalTime: (json['total_time'] as num?)?.toDouble() ?? 0.0,
      initialKms: (json['initial_kms'] as num?)?.toDouble(),
      purchaseValue: (json['purchase_value'] as num?)?.toDouble(),
      wheelDiameterCm: (json['wheel_diameter_cm'] as num?)?.toDouble(),
      totalComponentsCost: (json['total_components_cost'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      stravaGearId: json['strava_gear_id'] as String?,
      garminconnectGearId: json['garminconnect_gear_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nickname': nickname,
    'brand': brand,
    'model': model,
    'gear_type': gearType,
    'active': active,
    if (initialKms != null) 'initial_kms': initialKms,
    if (purchaseValue != null) 'purchase_value': purchaseValue,
    if (wheelDiameterCm != null) 'wheel_diameter_cm': wheelDiameterCm,
  };

  GearDetail copyWith({
    int? id,
    String? nickname,
    String? brand,
    String? model,
    int? gearType,
    bool? active,
    double? totalDistance,
    double? totalTime,
    double? initialKms,
    double? purchaseValue,
    double? wheelDiameterCm,
    double? totalComponentsCost,
    DateTime? createdAt,
    String? stravaGearId,
    String? garminconnectGearId,
  }) {
    return GearDetail(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      gearType: gearType ?? this.gearType,
      active: active ?? this.active,
      totalDistance: totalDistance ?? this.totalDistance,
      totalTime: totalTime ?? this.totalTime,
      initialKms: initialKms ?? this.initialKms,
      purchaseValue: purchaseValue ?? this.purchaseValue,
      wheelDiameterCm: wheelDiameterCm ?? this.wheelDiameterCm,
      totalComponentsCost: totalComponentsCost ?? this.totalComponentsCost,
      createdAt: createdAt ?? this.createdAt,
      stravaGearId: stravaGearId ?? this.stravaGearId,
      garminconnectGearId: garminconnectGearId ?? this.garminconnectGearId,
    );
  }

  double get displayMileageKm => (totalDistance / 1000) + (initialKms ?? 0.0);

  String get typeLabel {
    switch (gearType) {
      case 1: return 'Велосипед';
      case 2: return 'Кроссовки';
      case 3: return 'Гидрокостюм';
      case 4: return 'Ракетка';
      case 5: return 'Лыжи';
      case 6: return 'Сноуборд';
      case 7: return 'Виндсёрф';
      case 8: return 'Водный спорт';
      default: return 'Снаряжение';
    }
  }
}

class GearComponent {
  final int id;
  final int gearId;
  final String type;
  final String brand;
  final String model;
  final DateTime? purchaseDate;
  final DateTime? retiredDate;
  final bool active;
  final int? expectedKms;
  final double? purchaseValue;
  final double currentDistance;
  final double currentTime;

  GearComponent({
    required this.id,
    required this.gearId,
    required this.type,
    required this.brand,
    required this.model,
    this.purchaseDate,
    this.retiredDate,
    required this.active,
    this.expectedKms,
    this.purchaseValue,
    this.currentDistance = 0.0,
    this.currentTime = 0.0,
  });

  factory GearComponent.fromJson(Map<String, dynamic> json) {
    return GearComponent(
      id: (json['id'] as num).toInt(),
      gearId: (json['gear_id'] as num).toInt(),
      type: json['type'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      purchaseDate: json['purchase_date'] != null ? DateTime.tryParse(json['purchase_date'] as String) : null,
      retiredDate: json['retired_date'] != null ? DateTime.tryParse(json['retired_date'] as String) : null,
      active: (json['active'] as bool?) ?? false,
      expectedKms: (json['expected_kms'] as num?)?.toInt(),
      purchaseValue: (json['purchase_value'] as num?)?.toDouble(),
      currentDistance: (json['current_distance'] as num?)?.toDouble() ?? 0.0,
      currentTime: (json['current_time'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'gear_id': gearId,
    'type': type,
    'brand': brand,
    'model': model,
    'active': active,
    if (purchaseDate != null) 'purchase_date': purchaseDate!.toIso8601String(),
    if (retiredDate != null) 'retired_date': retiredDate!.toIso8601String(),
    if (expectedKms != null) 'expected_kms': expectedKms,
    if (purchaseValue != null) 'purchase_value': purchaseValue,
  };

  GearComponent copyWith({
    int? id,
    int? gearId,
    String? type,
    String? brand,
    String? model,
    DateTime? purchaseDate,
    DateTime? retiredDate,
    bool? active,
    int? expectedKms,
    double? purchaseValue,
    double? currentDistance,
    double? currentTime,
    bool clearRetiredDate = false,
  }) {
    return GearComponent(
      id: id ?? this.id,
      gearId: gearId ?? this.gearId,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      retiredDate: clearRetiredDate ? null : (retiredDate ?? this.retiredDate),
      active: active ?? this.active,
      expectedKms: expectedKms ?? this.expectedKms,
      purchaseValue: purchaseValue ?? this.purchaseValue,
      currentDistance: currentDistance ?? this.currentDistance,
      currentTime: currentTime ?? this.currentTime,
    );
  }

  double get currentDistanceKm => currentDistance / 1000.0;

  double get wearPercentage {
    if (expectedKms == null || expectedKms == 0) return 0.0;
    return (currentDistance / expectedKms!).clamp(0.0, 1.0);
  }

  bool get isOverdue => expectedKms != null && currentDistance > expectedKms!;
}

const Map<String, String> gearComponentTypeLabels = {
  'frame': 'Рама',
  'fork': 'Вилка',
  'handlebar': 'Руль',
  'stem': 'Вынос',
  'saddle': 'Седло',
  'seatpost': 'Подседельный штырь',
  'pedals': 'Педали',
  'crankset': 'Система',
  'chain': 'Цепь',
  'cassette': 'Кассета',
  'front_tire': 'Переднее колесо',
  'back_tire': 'Заднее колесо',
  'front_wheel': 'Переднее колесо',
  'back_wheel': 'Заднее колесо',
  'front_break_pads': 'Передние тормозные колодки',
  'back_break_pads': 'Задние тормозные колодки',
  'front_break_rotor': 'Передний ротор',
  'back_break_rotor': 'Задний ротор',
  'front_break_oil': 'Переднее тормозное масло',
  'back_break_oil': 'Заднее тормозное масло',
  'front_derailleur': 'Передний переключатель',
  'rear_derailleur': 'Задний переключатель',
  'front_shifter': 'Передний манеток',
  'rear_shifter': 'Задний манеток',
  'bottom_bracket': 'Каретка',
  'headset': 'Рулевая колонка',
  'grips': 'Грипсы',
  'handlebar_tape': 'Обмотка руля',
  'cleats': 'Клипсы',
  'insoles': 'Стельки',
  'laces': 'Шнурки',
  'strings': 'Струны',
  'overgrip': 'Намотка',
  'basegrip': 'Базовая намотка',
  'bumpers': 'Бамперы',
  'grommets': 'Громмиты',
  'front_tube': 'Передняя камера',
  'back_tube': 'Задняя камера',
  'front_tubeless_sealant': 'Герметик передний',
  'back_tubeless_sealant': 'Герметик задний',
  'front_tubeless_rim_tape': 'Лента обода передняя',
  'back_tubeless_rim_tape': 'Лента обода задняя',
  'front_wheel_valve': 'Вентиль передний',
  'back_wheel_valve': 'Вентиль задний',
  'bottle_cage': 'Держатель бутылки',
  'computer_mount': 'Крепление компьютера',
  'crank_left_power_meter': 'Левый крank-пOWER',
  'crank_right_power_meter': 'Правый крank-POWER',
  'crankset_power_meter': 'ПOWER на системе',
  'pedals_left_power_meter': 'Левая пEDALь POWER',
  'pedals_right_power_meter': 'Правая пEDALь POWER',
  'pedals_power_meter': 'ПEDALи POWER',
  // Ski components
  'bindings': 'Крепления',
  'boots': 'Ботинки',
  'poles': 'Палки',
  'helmet': 'Шлем',
  'goggles': 'Очки',
  'ski_brakes': 'Тормоза',
  'skins': 'Смазки',
  'deviation_skins': 'Отклоняющие смазки',
};
