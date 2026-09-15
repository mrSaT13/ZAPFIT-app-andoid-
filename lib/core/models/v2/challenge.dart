import 'package:isar/isar.dart';

@collection
class Challenge {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String remoteId;

  late String name;
  late String description;

  @enumerated
  late ChallengeType type;

  late double goalValue;
  double currentValue = 0;

  late DateTime startDate;
  late DateTime endDate;

  bool isCompleted = false;

  double get progress => (currentValue / goalValue).clamp(0.0, 1.0);
}

enum ChallengeType { 
  distance, 
  duration, 
  elevation, 
  calories, 
  activityCount 
}
