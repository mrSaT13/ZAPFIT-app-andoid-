import 'package:isar/isar.dart';

@collection
class UserProfile {
  Id id = Isar.autoIncrement;

  double? weight;
  int? age;
  String? gender;
  
  int? restingHR;
  int? maxHR;
  
  double? ftp; // Functional Threshold Power
  double? vo2max;

  @enumerated
  var units = UnitSystem.metric;
}

enum UnitSystem { metric, imperial }
