class GearReplacement {
  final int id;
  final DateTime timestamp;
  final String oldComponentType;
  final String oldComponentBrand;
  final String oldComponentModel;
  final double oldComponentDistance;
  final String? comment;
  final double? purchaseValue;

  GearReplacement({
    required this.id,
    required this.timestamp,
    required this.oldComponentType,
    required this.oldComponentBrand,
    required this.oldComponentModel,
    required this.oldComponentDistance,
    this.comment,
    this.purchaseValue,
  });

  factory GearReplacement.fromJson(Map<String, dynamic> json) {
    return GearReplacement(
      id: json['id'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      oldComponentType: json['old_component_type'] as String,
      oldComponentBrand: json['old_component_brand'] as String,
      oldComponentModel: json['old_component_model'] as String,
      oldComponentDistance: (json['old_component_distance'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] as String?,
      purchaseValue: (json['purchase_value'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'old_component_type': oldComponentType,
        'old_component_brand': oldComponentBrand,
        'old_component_model': oldComponentModel,
        'old_component_distance': oldComponentDistance,
        'comment': comment,
        'purchase_value': purchaseValue,
      };
}