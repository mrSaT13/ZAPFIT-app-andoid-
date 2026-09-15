import 'package:isar/isar.dart';

@collection
class SensorProfile {
  Id id = Isar.autoIncrement;

  late String name;
  
  @enumerated
  late SensorType type;

  String? macAddress; // For Android
  String? deviceId;   // For iOS (UUID)

  late DateTime lastConnected;
  
  String? calibrationData; // JSON string or specific fields

  // Connection settings
  bool autoConnect = true;
}

enum SensorType { heartRate, power, cadence, speed, temperature, gears }
