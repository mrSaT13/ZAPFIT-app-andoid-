import 'package:isar/isar.dart';

@collection
class Activity {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  // [comment removed - encoding corrupted]

  @enumerated
  late ActivityType type;

  late DateTime startTime;
  DateTime? endTime;

  // [comment removed - encoding corrupted]
  double distanceMeters = 0;
  double elevationGainMeters = 0;
  double calories = 0;

  // [comment removed - encoding corrupted]
  int? avgHeartRate;
  int? maxHeartRate;

  // [comment removed - encoding corrupted]
  double? avgSpeedKmh;
  double? maxSpeedKmh;

  // [comment removed - encoding corrupted]
  List<double>? powerData;
  List<int>? cadenceData;
  List<int>? gearsData;
  List<double>? tempData;

  String? routeId;
  String? notes;
  List<String> tags = [];

  // [comment removed - encoding corrupted]
  double? trimp; // Training Impulse
  double? aerobicTrainingEffect;
  double? anaerobicTrainingEffect;

  // [comment removed - encoding corrupted]
  var trackPoints = IsarLinks<TrackPoint>();

  @Index()
  bool isSynced = false;

  int get durationSeconds => endTime?.difference(startTime).inSeconds ?? 0;
}

@collection
class TrackPoint {
  Id id = Isar.autoIncrement;
  
  late DateTime timestamp;
  late double latitude;
  late double longitude;
  double? altitude;
  
  // [comment removed - encoding corrupted]
  double? speed;
  int? heartRate;
  int? power;
  int? cadence;
  double? temperature;
  int? gear;
}

enum ActivityType { bike, run, walk, hike, custom }
