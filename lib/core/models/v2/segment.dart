import 'package:isar/isar.dart';

@collection
class Segment {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String remoteId;

  late String name;

  /// Polyline representation of the path
  late String pathPolyline;

  double? bestTimeSeconds;
  DateTime? bestDate;

  int attempts = 0;

  // Metadata for matching
  double startLat = 0;
  double startLng = 0;
  double endLat = 0;
  double endLng = 0;
  
  double distanceMeters = 0;
}
