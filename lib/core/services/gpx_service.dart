import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';
import 'package:geolocator/geolocator.dart';

class ImportProgress {
  final int total;
  final int current;
  final String fileName;

  ImportProgress({required this.total, required this.current, required this.fileName});
  double get progress => total > 0 ? current / total : 0;
}

class GpxService {
  final LocalActivityRepository _repository = LocalActivityRepository.instance;

  Future<File> exportActivity(int activityId, {bool isTcx = false}) async {
    final activity = await _repository.getActivity(activityId);
    if (activity == null) throw StateError('Activity not found');

    final points = await _repository.getPoints(activityId);
    final content = isTcx ? _buildTcx(activity, points) : _buildGpx(activity, points);

    final dir = await getTemporaryDirectory();
    final safeTitle = activity.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final ext = isTcx ? 'tcx' : 'gpx';
    final file = File(p.join(dir.path, '$safeTitle.$ext'));
    await file.writeAsString(content);
    return file;
  }

  Future<void> exportAndShareActivity(int activityId) async {
    final gpxFile = await exportActivity(activityId, isTcx: false);
    final tcxFile = await exportActivity(activityId, isTcx: true);
    
    await Share.shareXFiles(
      [XFile(gpxFile.path), XFile(tcxFile.path)],
      text: 'Тренировка ZAPFIT: ${gpxFile.path.split(Platform.pathSeparator).last}',
    );
  }

  Future<List<int>> importMultipleFromPicker({void Function(ImportProgress)? onProgress}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['gpx', 'tcx', 'fit'],
    );
    if (result == null || result.files.isEmpty) return [];
    
    List<int> importedIds = [];
    int total = result.files.length;
    
    for (int i = 0; i < total; i++) {
      final file = result.files[i];
      final path = file.path;
      if (path == null) continue;
      
      onProgress?.call(ImportProgress(total: total, current: i + 1, fileName: file.name));
      
      try {
        int id;
        if (path.toLowerCase().endsWith('.fit')) {
          id = await importFitFromPath(path);
        } else if (path.toLowerCase().endsWith('.tcx')) {
          id = await importTcxFromPath(path);
        } else {
          id = await importFromPath(path);
        }
        importedIds.add(id);
      } catch (e) {
        print('Error importing $path: $e');
      }
    }
    return importedIds;
  }

  Future<int?> importFromPicker() async {
    final ids = await importMultipleFromPicker();
    return ids.isNotEmpty ? ids.first : null;
  }

  Future<int> importFitFromPath(String filePath) async {
    final apiClient = ApiClient();
    final endpoint = AppSettingsController.instance.uploadEndpoint;
    final response = await apiClient.uploadFile(endpoint, filePath, 'file');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError('Server returned ${response.statusCode} for FIT import');
    }

    final dynamic decoded = json.decode(await response.stream.bytesToString());
    final List<dynamic> result = decoded is List ? decoded : [decoded];
    if (result.isEmpty) throw StateError('Server returned empty result for FIT import');

    final serverData = result[0] as Map<String, dynamic>;
    final serverActivity = ActivityRecord.fromServerJson(serverData);

    final activityId = await _repository.upsertActivity(
      serverActivity.copyWith(
        source: ActivitySource.fitImport,
        uploadStatus: UploadStatus.uploaded,
        notes: '[fit-import] ${serverActivity.notes ?? ''}'.trim(),
      ),
    );

    return activityId;
  }

  Future<int> importFromPath(String filePath) async {
    final text = await File(filePath).readAsString();
    final doc = XmlDocument.parse(text);
    
    final trkElement = doc.findAllElements('trk').firstOrNull;
    final originalTrkName = trkElement?.findElements('name').firstOrNull?.innerText.trim() ?? '';
    // Prefer <trk><name>, fallback to <metadata><desc> (Sports Tracker "Аэробная длительная"), then filename
    String rawName = originalTrkName;
    if (rawName.isEmpty || rawName.toLowerCase().startsWith('sportstracker-')) {
      final metaDesc = doc.findAllElements('metadata').firstOrNull?.findElements('desc').firstOrNull?.innerText.trim() ??
                       doc.findAllElements('desc').firstOrNull?.innerText.trim();
      if (metaDesc != null && metaDesc.isNotEmpty) rawName = metaDesc;
    }
    final name = rawName.isNotEmpty ? rawName : p.basenameWithoutExtension(filePath);
    // For kind detection use BOTH original trk name and final name (so RollerSkiing not lost when we fallback to desc)
    final kindSource = '${originalTrkName} $name'.toLowerCase();
    
    final trackPointElements = doc.findAllElements('trkpt').toList();
    if (trackPointElements.isEmpty) throw StateError('No track points in GPX');

    ActivityKind kind = ActivityKind.run;
    final nameLower = kindSource;
    
    if (nameLower.contains('велосипед') || nameLower.contains('cycling') || nameLower.contains('bike') || nameLower.contains('вело')) {
      kind = ActivityKind.roadCycling;
    } else if (nameLower.contains('лыжероллер') || nameLower.contains('roller') || nameLower.contains('rollerski')) {
      kind = ActivityKind.nordicSki;
    } else if (nameLower.contains('лыж') || nameLower.contains('nordic') || nameLower.contains('ski')) {
      kind = ActivityKind.nordicSki;
    } else if (nameLower.contains('горные') || nameLower.contains('alpine') || nameLower.contains('сноуборд') || nameLower.contains('snowboard')) {
      kind = ActivityKind.alpineSki;
    } else if (nameLower.contains('ходьба') || nameLower.contains('walk')) {
      kind = ActivityKind.walk;
    } else if (nameLower.contains('поход') || nameLower.contains('hike')) {
      kind = ActivityKind.hike;
    } else if (nameLower.contains('ролик') || nameLower.contains('inline')) {
      kind = ActivityKind.inlineSkating;
    }

    // First pass: parse raw points and compute distance/startedAt without DB
    // so upsert gets correct distance (64km) and dedup via title+time works
    final rawPoints = <Map<String, dynamic>>[];
    double totalDist = 0.0;
    double? prevLat;
    double? prevLon;
    DateTime? firstTs;
    DateTime? lastTs;
    DateTime? prevTs;
    for (final element in trackPointElements) {
      final lat = double.tryParse(element.getAttribute('lat') ?? '');
      final lon = double.tryParse(element.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;
      final ele = double.tryParse(element.findElements('ele').firstOrNull?.innerText ?? '');
      final timeStr = element.findElements('time').firstOrNull?.innerText;
      DateTime ts;
      if (timeStr != null) {
        ts = DateTime.tryParse(timeStr)?.toLocal() ?? (prevTs != null ? prevTs.add(const Duration(seconds: 1)) : DateTime.now());
      } else {
        ts = prevTs != null ? prevTs.add(const Duration(seconds: 1)) : DateTime.now();
      }
      if (firstTs == null) firstTs = ts;
      lastTs = ts;
      if (prevLat != null && prevLon != null) {
        totalDist += distanceInMeters(prevLat, prevLon, lat, lon);
      }
      rawPoints.add({'lat': lat, 'lon': lon, 'ele': ele, 'ts': ts, 'dist': totalDist, 'elem': element});
      prevLat = lat;
      prevLon = lon;
      prevTs = ts;
    }
    if (rawPoints.isEmpty) throw StateError('No valid track points');
    final startedAt = firstTs ?? DateTime.now();
    final endedAt = lastTs ?? startedAt;
    final durationSec = endedAt.difference(startedAt).inSeconds;

    final activityId = await _repository.upsertActivity(
      ActivityRecord(
        title: name,
        kind: kind,
        startedAt: startedAt,
        endedAt: endedAt,
        distanceMeters: totalDist,
        durationSeconds: durationSec,
        notes: '[imported]',
        source: ActivitySource.gpxImport,
      ),
    );

    List<ActivityPoint> pointsToSave = [];
    ActivityPoint? previous;
    // Reuse rawPoints to build ActivityPoint list (dist already computed)
    for (final raw in rawPoints) {
      final lat = raw['lat'] as double;
      final lon = raw['lon'] as double;
      final ele = raw['ele'] as double?;
      final timestamp = raw['ts'] as DateTime;
      final dist = raw['dist'] as double;
      final element = raw['elem'] as XmlElement;

      double? speed;
      final speedElem = element.findElements('speed').firstOrNull ?? 
                        element.findAllElements('ns3:speed').firstOrNull ??
                        element.findAllElements('gpxtpx:speed').firstOrNull;
      
      if (speedElem != null) {
        speed = double.tryParse(speedElem.innerText);
      }

      int? hr;
      final hrElem = element.findAllElements('gpxtpx:hr').firstOrNull ??
                      element.findAllElements('ns3:hr').firstOrNull ??
                      element.findAllElements('hr').firstOrNull;
      if (hrElem != null) {
        hr = int.tryParse(hrElem.innerText);
      }

      final point = ActivityPoint(
        activityId: activityId, 
        timestamp: timestamp, 
        latitude: lat, 
        longitude: lon, 
        altitude: ele, 
        speed: speed, 
        distanceFromStartMeters: dist,
        heartRate: hr,
      );
      pointsToSave.add(point);
      previous = point;
    }
    
    // Clear old points if this was a re-import (dedup hit) to avoid duplicates
    final existingPoints = await _repository.getPoints(activityId);
    if (existingPoints.isNotEmpty) {
      await _repository.deletePointsForActivity(activityId);
    }
    await _repository.addPointsBatch(pointsToSave);
    
    if (previous != null) {
      final activity = await _repository.getActivity(activityId);
      if (activity != null) {
        // Compute avg/max HR from imported points
        int? avgHr;
        int? maxHr;
        final hrValues = pointsToSave
            .where((p) => p.heartRate != null && p.heartRate! > 0)
            .map((p) => p.heartRate!)
            .toList();
        if (hrValues.isNotEmpty) {
          avgHr = (hrValues.reduce((a, b) => a + b) / hrValues.length).round();
          maxHr = hrValues.reduce(math.max);
        }
        await _repository.updateActivity(activity.copyWith(
          distanceMeters: totalDist,
          endedAt: previous.timestamp,
          durationSeconds: previous.timestamp.difference(startedAt).inSeconds,
          avgHeartRate: avgHr,
          maxHeartRate: maxHr,
        ));
      }
    }
    
    return activityId;
  }

  Future<int> importTcxFromPath(String filePath) async {
    final text = await File(filePath).readAsString();
    final doc = XmlDocument.parse(text);
    final trackPoints = doc.findAllElements('Trackpoint');
    if (trackPoints.isEmpty) throw StateError('No track points in TCX');

    final firstTimeRaw = trackPoints.first.findElements('Time').firstOrNull?.innerText;
    final startedAt = firstTimeRaw == null ? DateTime.now() : DateTime.tryParse(firstTimeRaw)?.toLocal() ?? DateTime.now();

    final activityId = await _repository.upsertActivity(
      ActivityRecord(title: p.basenameWithoutExtension(filePath), kind: ActivityKind.run, startedAt: startedAt, notes: '[imported]', source: ActivitySource.gpxImport),
    );

    List<ActivityPoint> pointsToSave = [];
    ActivityPoint? previous;
    var distance = 0.0;
    
    for (final element in trackPoints) {
      final pos = element.findElements('Position').firstOrNull;
      if (pos == null) continue;

      final lat = double.tryParse(pos.findElements('LatitudeDegrees').firstOrNull?.innerText ?? '');
      final lon = double.tryParse(pos.findElements('LongitudeDegrees').firstOrNull?.innerText ?? '');
      if (lat == null || lon == null) continue;

      final ele = double.tryParse(element.findElements('AltitudeMeters').firstOrNull?.innerText ?? '');
      final rawTs = element.findElements('Time').firstOrNull?.innerText;
      final timestamp = rawTs != null ? (DateTime.tryParse(rawTs)?.toLocal() ?? DateTime.now()) : DateTime.now();

      int? hr;
      final hrElem = element.findElements('HeartRateBpm').firstOrNull?.findElements('Value').firstOrNull;
      if (hrElem != null) {
        hr = int.tryParse(hrElem.innerText);
      }

      int? cadence;
      final cadElem = element.findElements('Cadence').firstOrNull;
      if (cadElem != null) {
        cadence = int.tryParse(cadElem.innerText);
      }

      if (previous != null) {
        distance += distanceInMeters(previous.latitude, previous.longitude, lat, lon);
      }

      final point = ActivityPoint(
        activityId: activityId, 
        timestamp: timestamp, 
        latitude: lat, 
        longitude: lon, 
        altitude: ele, 
        distanceFromStartMeters: distance,
        heartRate: hr,
        cadence: cadence,
      );
      pointsToSave.add(point);
      previous = point;
    }

    await _repository.addPointsBatch(pointsToSave);

    if (previous != null) {
      final activity = await _repository.getActivity(activityId);
      if (activity != null) {
        // Compute avg/max HR from imported points
        int? avgHr;
        int? maxHr;
        final hrValues = pointsToSave
            .where((p) => p.heartRate != null && p.heartRate! > 0)
            .map((p) => p.heartRate!)
            .toList();
        if (hrValues.isNotEmpty) {
          avgHr = (hrValues.reduce((a, b) => a + b) / hrValues.length).round();
          maxHr = hrValues.reduce(math.max);
        }
        await _repository.updateActivity(activity.copyWith(
          distanceMeters: distance,
          endedAt: previous.timestamp,
          durationSeconds: previous.timestamp.difference(startedAt).inSeconds,
          avgHeartRate: avgHr,
          maxHeartRate: maxHr,
        ));
      }
    }

    return activityId;
  }

  String _buildGpx(ActivityRecord activity, List<ActivityPoint> points) {
    double maxSpeed = 0.0;
    int movingTime = 0;
    if (points.isNotEmpty) {
      maxSpeed = points.map((p) => p.speed ?? 0.0).reduce(math.max);
      for (int i = 1; i < points.length; i++) {
        if ((points[i].speed ?? 0) > 0.5) {
          movingTime += points[i].timestamp.difference(points[i-1].timestamp).inSeconds;
        }
      }
    }

    final builder = StringBuffer();
    builder.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    builder.writeln('<gpx version="1.1" creator="ZAPFIT"');
    builder.writeln('  xmlns="http://www.topografix.com/GPX/1/1"');
    builder.writeln('  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"');
    builder.writeln('  xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v2"');
    builder.writeln('  xmlns:gpxtrkx="http://www.garmin.com/xmlschemas/TrackStatsExtension/v1">');

    builder.writeln('  <trk>');
    builder.writeln('    <name><![CDATA[${activity.title}]]></name>');
    builder.writeln('    <type>${_gpxActivityTypeName(activity.kind)}</type>');
    builder.writeln('    <extensions>');
    builder.writeln('      <gpxtrkx:TrackStatsExtension>');
    builder.writeln('        <gpxtrkx:Distance>${activity.distanceMeters.toStringAsFixed(2)}</gpxtrkx:Distance>');
    builder.writeln('        <gpxtrkx:TimerTime>${activity.durationSeconds}</gpxtrkx:TimerTime>');
    builder.writeln('        <gpxtrkx:MovingTime>$movingTime</gpxtrkx:MovingTime>');
    builder.writeln('        <gpxtrkx:MaxSpeed>${maxSpeed.toStringAsFixed(2)}</gpxtrkx:MaxSpeed>');
    builder.writeln('      </gpxtrkx:TrackStatsExtension>');
    builder.writeln('    </extensions>');
    builder.writeln('    <trkseg>');

    for (final point in points) {
      builder.writeln('      <trkpt lat="${point.latitude}" lon="${point.longitude}">');
      if (point.altitude != null) builder.writeln('        <ele>${point.altitude!.toStringAsFixed(1)}</ele>');
      builder.writeln('        <time>${point.timestamp.toUtc().toIso8601String()}</time>');
      builder.writeln('        <extensions>');
      builder.writeln('          <gpxtpx:TrackPointExtension>');
      if (point.heartRate != null) builder.writeln('            <gpxtpx:hr>${point.heartRate}</gpxtpx:hr>');
      if (point.cadence != null) builder.writeln('            <gpxtpx:cad>${point.cadence}</gpxtpx:cad>');
      builder.writeln('            <gpxtpx:speed>${(point.speed ?? 0).toStringAsFixed(2)}</gpxtpx:speed>');
      builder.writeln('          </gpxtpx:TrackPointExtension>');
      builder.writeln('        </extensions>');
      builder.writeln('      </trkpt>');
    }

    builder.writeln('    </trkseg>');
    builder.writeln('  </trk>');
    builder.writeln('</gpx>');
    return builder.toString();
  }

  /// Маппинг enum ActivityKind.name → строковое имя, которое сервер
  /// распознаёт через define_activity_type / ACTIVITY_NAME_TO_ID.
  String _gpxActivityTypeName(ActivityKind kind) {
    switch (kind) {
      case ActivityKind.run: return 'running';
      case ActivityKind.trailRun: return 'trail_running';
      case ActivityKind.trackRun: return 'track_running';
      case ActivityKind.treadmillRun: return 'treadmill';
      case ActivityKind.virtualRun: return 'virtual_running';
      case ActivityKind.roadCycling: return 'cycling';
      case ActivityKind.gravelCycling: return 'gravel_ride';
      case ActivityKind.mtbCycling: return 'mountain_bike_ride';
      case ActivityKind.commutingCycling: return 'commuting_ride';
      case ActivityKind.mixedSurfaceCycling: return 'mixed_surface_ride';
      case ActivityKind.virtualCycling: return 'virtual_ride';
      case ActivityKind.indoorCycling: return 'indoor_ride';
      case ActivityKind.eBikeCycling: return 'e_bike_ride';
      case ActivityKind.eBikeMountainCycling: return 'e_bike_mountain_ride';
      case ActivityKind.indoorSwimming: return 'lap_swimming';
      case ActivityKind.openWaterSwimming: return 'open_water_swimming';
      case ActivityKind.generalWorkout: return 'workout';
      case ActivityKind.walk: return 'walking';
      case ActivityKind.indoorWalk: return 'indoor_walking';
      case ActivityKind.hike: return 'hiking';
      case ActivityKind.rowing: return 'rowing';
      case ActivityKind.yoga: return 'yoga';
      case ActivityKind.alpineSki: return 'alpine_ski';
      case ActivityKind.nordicSki: return 'nordic_ski';
      case ActivityKind.snowboard: return 'snowboard';
      case ActivityKind.iceSkate: return 'ice_skate';
      case ActivityKind.transition: return 'transition';
      case ActivityKind.strengthTraining: return 'strength_training';
      case ActivityKind.crossfit: return 'crossfit';
      case ActivityKind.tennis: return 'tennis';
      case ActivityKind.tableTennis: return 'table_tennis';
      case ActivityKind.badminton: return 'badminton';
      case ActivityKind.squash: return 'squash';
      case ActivityKind.racquetball: return 'racquetball';
      case ActivityKind.pickleball: return 'pickleball';
      case ActivityKind.padel: return 'padel';
      case ActivityKind.windsurf: return 'windsurf';
      case ActivityKind.standUpPaddling: return 'stand_up_paddling';
      case ActivityKind.surf: return 'surf';
      case ActivityKind.soccer: return 'soccer';
      case ActivityKind.cardioTraining: return 'cardio_training';
      case ActivityKind.kayaking: return 'kayaking';
      case ActivityKind.sailing: return 'sailing';
      case ActivityKind.snowShoeing: return 'snow_shoeing';
      case ActivityKind.inlineSkating: return 'inline_skating';
      case ActivityKind.hiit: return 'hiit';
    }
  }

  /// Вид спорта для TCX-файла (CDATA-строка Garmin).
  String _tcxActivitySport(ActivityKind kind) {
    switch (kind) {
      case ActivityKind.roadCycling:
      case ActivityKind.gravelCycling:
      case ActivityKind.mtbCycling:
      case ActivityKind.commutingCycling:
      case ActivityKind.mixedSurfaceCycling:
      case ActivityKind.virtualCycling:
      case ActivityKind.indoorCycling:
      case ActivityKind.eBikeCycling:
      case ActivityKind.eBikeMountainCycling:
        return 'Biking';
      case ActivityKind.alpineSki:
      case ActivityKind.nordicSki:
      case ActivityKind.snowboard:
        return 'Skiing';
      case ActivityKind.rowing:
        return 'Rowing';
      case ActivityKind.kayaking:
        return 'Kayaking';
      default:
        return 'Running';
    }
  }

  String _buildTcx(ActivityRecord activity, List<ActivityPoint> points) {
    final builder = StringBuffer();
    builder.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    builder.writeln('<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">');
    builder.writeln('  <Activities>');
    builder.writeln('    <Activity Sport="${_tcxActivitySport(activity.kind)}">');
    builder.writeln('      <Id>${activity.startedAt.toUtc().toIso8601String()}</Id>');
    builder.writeln('      <Lap StartTime="${activity.startedAt.toUtc().toIso8601String()}">');
    builder.writeln('        <TotalTimeSeconds>${activity.durationSeconds}</TotalTimeSeconds>');
    builder.writeln('        <DistanceMeters>${activity.distanceMeters}</DistanceMeters>');
    if (activity.maxHeartRate != null) {
      builder.writeln('        <MaximumHeartRateBpm><Value>${activity.maxHeartRate}</Value></MaximumHeartRateBpm>');
    }
    if (activity.avgHeartRate != null) {
      builder.writeln('        <AverageHeartRateBpm><Value>${activity.avgHeartRate}</Value></AverageHeartRateBpm>');
    }
    builder.writeln('        <Intensity>Active</Intensity>');
    builder.writeln('        <TriggerMethod>Manual</TriggerMethod>');
    builder.writeln('        <Track>');

    for (final point in points) {
      builder.writeln('          <Trackpoint>');
      builder.writeln('            <Time>${point.timestamp.toUtc().toIso8601String()}</Time>');
      builder.writeln('            <Position>');
      builder.writeln('              <LatitudeDegrees>${point.latitude}</LatitudeDegrees>');
      builder.writeln('              <LongitudeDegrees>${point.longitude}</LongitudeDegrees>');
      builder.writeln('            </Position>');
      if (point.altitude != null) builder.writeln('            <AltitudeMeters>${point.altitude}</AltitudeMeters>');
      builder.writeln('            <DistanceMeters>${point.distanceFromStartMeters}</DistanceMeters>');
      if (point.heartRate != null) {
        builder.writeln('            <HeartRateBpm><Value>${point.heartRate}</Value></HeartRateBpm>');
      }
      if (point.cadence != null) {
        builder.writeln('            <Cadence>${point.cadence}</Cadence>');
      }
      if (point.speed != null || point.power != null) {
        builder.writeln('            <Extensions>');
        builder.writeln('              <TPX xmlns="http://www.garmin.com/xmlschemas/ActivityExtension/v2">');
        if (point.speed != null) builder.writeln('                <Speed>${point.speed}</Speed>');
        if (point.power != null) builder.writeln('                <Watts>${point.power!.round()}</Watts>');
        builder.writeln('              </TPX>');
        builder.writeln('            </Extensions>');
      }
      builder.writeln('          </Trackpoint>');
    }

    builder.writeln('        </Track>');
    builder.writeln('      </Lap>');
    builder.writeln('    </Activity>');
    builder.writeln('  </Activities>');
    builder.writeln('</TrainingCenterDatabase>');
    return builder.toString();
  }
}
