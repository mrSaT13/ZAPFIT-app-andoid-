enum MuscleLevel { low, normal, high }
enum BoneLevel { low, normal, high }
enum WaterLevel { low, normal, high }
enum VisceralFatLevel { low, normal, slightlyHigher, high }
enum BodyScoreGrade { poor, fair, normal, good, excellent }

class BodyCompositionResult {
  final double bodyFatPercentage;
  final String bodyFatLabel;
  final int bodyFatLevel;
  final double muscleMassKg;
  final double boneMassKg;
  final double bodyWaterPercentage;
  final int visceralFatLevel;
  final int bodyShapeType;
  final int bodyScore;
  final BodyScoreGrade bodyScoreGrade;
  final String bodyScoreLabel;
  final MuscleLevel muscleLevel;
  final String muscleLabel;
  final BoneLevel boneLevel;
  final String boneLabel;
  final WaterLevel waterLevel;
  final String waterLabel;
  final VisceralFatLevel visceralFatGrade;
  final String visceralFatLabel;
  final int bmr;
  final String bmrLabel;

  const BodyCompositionResult({
    required this.bodyFatPercentage,
    this.bodyFatLabel = '',
    this.bodyFatLevel = 2,
    required this.muscleMassKg,
    required this.boneMassKg,
    required this.bodyWaterPercentage,
    required this.visceralFatLevel,
    required this.bodyShapeType,
    required this.bodyScore,
    required this.bodyScoreGrade,
    required this.bodyScoreLabel,
    required this.muscleLevel,
    required this.muscleLabel,
    required this.boneLevel,
    required this.boneLabel,
    required this.waterLevel,
    required this.waterLabel,
    required this.visceralFatGrade,
    required this.visceralFatLabel,
    this.bmr = 0,
    this.bmrLabel = '',
  });
}

class BodyCompositionCalculator {
  BodyCompositionCalculator._();

  static BodyCompositionResult calculate({
    required double weightKg,
    required double heightCm,
    required int age,
    required int gender, // 0=female, 1=male
  }) {
    final bmi = weightKg / ((heightCm / 100) * (heightCm / 100));
    final isMale = gender == 1;

    // Body fat % (US Navy simplified / BMI-based)
    double bodyFat = _estimateBodyFat(bmi: bmi, age: age, male: isMale);

    // Body fat label
    String bfLabel;
    int bfLevel;
    if (bodyFat < (isMale ? 11 : 21)) { bfLabel = 'Очень низкий'; bfLevel = 0; }
    else if (bodyFat < (isMale ? 22 : 33)) { bfLabel = 'Норма'; bfLevel = 2; }
    else if (bodyFat < (isMale ? 26 : 37)) { bfLabel = 'Чуть выше'; bfLevel = 3; }
    else { bfLabel = 'Высокий'; bfLevel = 4; }

    // Muscle mass
    double musclePct = isMale ? 42.0 : 36.0;
    if (age > 40) musclePct -= (age - 40) * 0.3;
    final muscleMassKg = weightKg * musclePct / 100;

    // Bone mass
    double bonePct = isMale ? 3.5 : 3.0;
    final boneMassKg = weightKg * bonePct / 100;

    // Body water %
    double waterPct = isMale ? 60.0 : 55.0;
    waterPct -= bodyFat * 0.7;
    waterPct = waterPct.clamp(35.0, 75.0);

    // Visceral fat level (1-12)
    int visceralLevel = (bodyFat / 3.0 + (isMale ? 3 : 2)).round().clamp(1, 12);

    // Body shape
    int bodyShape = isMale ? 3 : 2;

    // BMR (Mifflin-St Jeor)
    final bmr = (10 * weightKg + 6.25 * heightCm - 5 * age + (isMale ? 5 : -161)).round();
    final bmrLabel = 'Метаболизм в покое';

    // Body score (0-100)
    int bodyScore = 70;
    if (bmi >= 18.5 && bmi < 25) bodyScore += 15;
    else if (bmi >= 25) bodyScore -= (bmi - 25).round() * 3;
    if (bodyFat < (isMale ? 25 : 32)) bodyScore += 10;
    bodyScore = bodyScore.clamp(0, 100);

    BodyScoreGrade grade;
    String gradeLabel;
    if (bodyScore >= 90) { grade = BodyScoreGrade.excellent; gradeLabel = 'Отлично'; }
    else if (bodyScore >= 75) { grade = BodyScoreGrade.good; gradeLabel = 'Хорошо'; }
    else if (bodyScore >= 55) { grade = BodyScoreGrade.normal; gradeLabel = 'Норма'; }
    else if (bodyScore >= 35) { grade = BodyScoreGrade.fair; gradeLabel = 'Удовл.'; }
    else { grade = BodyScoreGrade.poor; gradeLabel = 'Плохо'; }

    // Muscle level
    MuscleLevel mLevel;
    String mLabel;
    if (musclePct < (isMale ? 38 : 32)) { mLevel = MuscleLevel.low; mLabel = 'Ниже нормы'; }
    else if (musclePct > (isMale ? 46 : 40)) { mLevel = MuscleLevel.high; mLabel = 'Выше нормы'; }
    else { mLevel = MuscleLevel.normal; mLabel = 'Норма'; }

    // Bone level
    BoneLevel bLevel = BoneLevel.normal;
    String bLabel = 'Норма';

    // Water level
    WaterLevel wLevel;
    String wLabel;
    if (waterPct < (isMale ? 55 : 50)) { wLevel = WaterLevel.low; wLabel = 'Ниже нормы'; }
    else if (waterPct > (isMale ? 65 : 60)) { wLevel = WaterLevel.high; wLabel = 'Выше нормы'; }
    else { wLevel = WaterLevel.normal; wLabel = 'Норма'; }

    // Visceral fat grade
    VisceralFatLevel vGrade;
    String vLabel;
    if (visceralLevel <= 9) { vGrade = VisceralFatLevel.normal; vLabel = 'Норма'; }
    else if (visceralLevel <= 11) { vGrade = VisceralFatLevel.slightlyHigher; vLabel = 'Чуть выше нормы'; }
    else { vGrade = VisceralFatLevel.high; vLabel = 'Высокий'; }

    return BodyCompositionResult(
      bodyFatPercentage: bodyFat,
      bodyFatLabel: bfLabel,
      bodyFatLevel: bfLevel,
      muscleMassKg: muscleMassKg,
      boneMassKg: boneMassKg,
      bodyWaterPercentage: waterPct,
      visceralFatLevel: visceralLevel,
      bodyShapeType: bodyShape,
      bodyScore: bodyScore,
      bodyScoreGrade: grade,
      bodyScoreLabel: gradeLabel,
      muscleLevel: mLevel,
      muscleLabel: mLabel,
      boneLevel: bLevel,
      boneLabel: bLabel,
      waterLevel: wLevel,
      waterLabel: wLabel,
      visceralFatGrade: vGrade,
      visceralFatLabel: vLabel,
      bmr: bmr,
      bmrLabel: bmrLabel,
    );
  }

  static double _estimateBodyFat({
    required double bmi,
    required int age,
    required bool male,
  }) {
    // BMI-based body fat estimation (Deurenberg formula)
    // BF% = 1.2 × BMI + 0.23 × Age − 10.8 × Sex − 5.4
    double bf = 1.2 * bmi + 0.23 * age - (male ? 10.8 : 0) - 5.4;
    return bf.clamp(3.0, 60.0);
  }

  static String bodyShapeTypeName(int type) {
    switch (type) {
      case 0: return 'Яблоко';
      case 1: return 'Груша';
      case 2: return 'Песочные часы';
      case 3: return 'Прямоугольник';
      default: return 'Неизвестно';
    }
  }
}
