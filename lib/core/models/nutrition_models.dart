/// Models for the nutrition diary (meal logs, Open Food Facts products,
/// daily summary). Payload keys mirror the server's FastAPI schemas
/// (`MealLogBase`, `OffSearchResult`, `NutritionSummary`) exactly.
class MealLog {
  /// Server id (`null` until the record was pushed, or when offline).
  final int? id;

  /// Local sqflite row id (`meal_logs.local_id`); null for server-only rows.
  final int? localId;

  /// `YYYY-MM-DD` calendar day, same format the server stores.
  final String date;

  /// `breakfast` | `lunch` | `dinner` | `snack`.
  final String mealType;

  final String productName;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;

  /// Portion weight in grams (optional; values below are per portion).
  final double? portionG;

  /// Open Food Facts barcode when the entry came from a product lookup.
  final String? offBarcode;

  /// Whether the row is confirmed on the server (local cache flag).
  final bool synced;

  /// Local tombstone: deleted offline, deletion still queued for the server.
  final bool pendingDelete;

  const MealLog({
    this.id,
    this.localId,
    required this.date,
    required this.mealType,
    required this.productName,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.portionG,
    this.offBarcode,
    this.synced = true,
    this.pendingDelete = false,
  });

  factory MealLog.fromJson(Map<String, dynamic> json) {
    return MealLog(
      id: (json['id'] as num?)?.toInt(),
      date: json['date'] as String? ?? '',
      mealType: json['meal_type'] as String? ?? 'snack',
      productName: json['product_name'] as String? ?? '',
      calories: (json['calories'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      portionG: (json['portion_g'] as num?)?.toDouble(),
      offBarcode: json['off_barcode'] as String?,
    );
  }

  /// Body for `POST /nutrition` and `PUT /nutrition/{id}` (MealLogCreate).
  Map<String, dynamic> toPayload() {
    final result = <String, dynamic>{
      'date': date,
      'meal_type': mealType,
      'product_name': productName.length > 250
          ? productName.substring(0, 250)
          : productName,
    };
    if (calories != null) result['calories'] = calories;
    if (protein != null) result['protein'] = protein;
    if (carbs != null) result['carbs'] = carbs;
    if (fat != null) result['fat'] = fat;
    if (portionG != null) result['portion_g'] = portionG;
    if (offBarcode != null && offBarcode!.isNotEmpty) {
      result['off_barcode'] = offBarcode;
    }
    return result;
  }

  MealLog copyWith({
    int? id,
    int? localId,
    String? date,
    String? mealType,
    String? productName,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? portionG,
    String? offBarcode,
    bool? synced,
    bool clearPortion = false,
    bool clearBarcode = false,
  }) {
    return MealLog(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      productName: productName ?? this.productName,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      portionG: clearPortion ? null : (portionG ?? this.portionG),
      offBarcode: clearBarcode ? null : (offBarcode ?? this.offBarcode),
      synced: synced ?? this.synced,
    );
  }
}

/// A product from the server's Open Food Facts proxy (`/nutrition/off/*`).
class OffProduct {
  final String barcode;
  final String productName;
  final String? brands;
  final double? calories100g;
  final double? protein100g;
  final double? carbs100g;
  final double? fat100g;
  final String? imageUrl;

  const OffProduct({
    required this.barcode,
    required this.productName,
    this.brands,
    this.calories100g,
    this.protein100g,
    this.carbs100g,
    this.fat100g,
    this.imageUrl,
  });

  factory OffProduct.fromJson(Map<String, dynamic> json) {
    return OffProduct(
      barcode: json['barcode'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      brands: json['brands'] as String?,
      calories100g: (json['calories_100g'] as num?)?.toDouble(),
      protein100g: (json['proteins_100g'] as num?)?.toDouble(),
      carbs100g: (json['carbs_100g'] as num?)?.toDouble(),
      fat100g: (json['fat_100g'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String?,
    );
  }
}

/// One day's totals from `GET /nutrition/summary?date=`.
class NutritionSummary {
  final String date;
  final double intakeCalories;
  final double intakeProtein;
  final double intakeCarbs;
  final double intakeFat;
  final double? burnedCalories;
  final double? netCalories;

  const NutritionSummary({
    required this.date,
    required this.intakeCalories,
    required this.intakeProtein,
    required this.intakeCarbs,
    required this.intakeFat,
    this.burnedCalories,
    this.netCalories,
  });

  factory NutritionSummary.fromJson(Map<String, dynamic> json) {
    return NutritionSummary(
      date: json['date'] as String? ?? '',
      intakeCalories: (json['intake_calories'] as num?)?.toDouble() ?? 0,
      intakeProtein: (json['intake_protein'] as num?)?.toDouble() ?? 0,
      intakeCarbs: (json['intake_carbs'] as num?)?.toDouble() ?? 0,
      intakeFat: (json['intake_fat'] as num?)?.toDouble() ?? 0,
      burnedCalories: (json['burned_calories'] as num?)?.toDouble(),
      netCalories: (json['net_calories'] as num?)?.toDouble(),
    );
  }
}

class NutritionAiStatus {
  final bool enabled;
  final bool configured;
  final String? model;

  const NutritionAiStatus(
      {required this.enabled, required this.configured, this.model,});

  factory NutritionAiStatus.fromJson(Map<String, dynamic> json) {
    return NutritionAiStatus(
      enabled: json['enabled'] as bool? ?? false,
      configured: json['configured'] as bool? ?? false,
      model: json['model'] as String?,
    );
  }
}
