import 'package:endurain/core/models/activity.dart';
import 'package:injectable/injectable.dart';

@singleton
class GpxExporter {
  String export(Activity activity) {
    final normalizedPoints = _normalizeTrackPointsForExport(activity);
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="Endurain Mobile" xmlns="http://www.topografix.com/GPX/1/1" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1">',
      )
      ..writeln('  <trk>')
      ..writeln('    <name>${_escapeXml(_buildActivityName(activity))}</name>')
      ..writeln('    <type>${activityTypeToJson(activity.activityType)}</type>')
      ..writeln('    <trkseg>');

    for (final point in normalizedPoints) {
      _validatePoint(point);
      final time = point.timestamp.toUtc().toIso8601String();
      final elevation = point.altitudeMeters;
      final elevationNode = elevation == null
          ? ''
          : '<ele>${elevation.toStringAsFixed(2)}</ele>';
      final hr = point.heartRate;
      final cadence = point.cadence;
      String extensionNode = '';
      if ((hr != null && hr > 0) || (cadence != null && cadence > 0)) {
        final hrNode = (hr != null && hr > 0)
            ? '<gpxtpx:hr>$hr</gpxtpx:hr>'
            : '';
        final cadenceNode = (cadence != null && cadence > 0)
            ? '<gpxtpx:cad>$cadence</gpxtpx:cad>'
            : '';
        extensionNode =
            '<extensions><gpxtpx:TrackPointExtension>$hrNode$cadenceNode</gpxtpx:TrackPointExtension></extensions>';
      }
      buffer.writeln(
        '      <trkpt lat="${point.latitude}" lon="${point.longitude}">$elevationNode<time>$time</time>$extensionNode</trkpt>',
      );
    }

    buffer
      ..writeln('    </trkseg>')
      ..writeln('  </trk>')
      ..writeln('</gpx>');

    return buffer.toString();
  }

  List<TrackPoint> _normalizeTrackPointsForExport(Activity activity) {
    final points = List<TrackPoint>.from(activity.trackPoints);
    if (points.isEmpty) return points;
    final start = activity.startedAt;
    final end = activity.endedAt;
    final first = points.first;
    if (first.timestamp.isAfter(start)) {
      points.insert(0, first.copyWith(timestamp: start));
    }
    if (end != null) {
      final last = points.last;
      if (last.timestamp.isBefore(end)) {
        points.add(last.copyWith(timestamp: end));
      }
    }
    return points;
  }

  String _buildActivityName(Activity activity) {
    if (activity.name != null && activity.name!.trim().isNotEmpty) {
      return activity.name!.trim();
    }
    final label = switch (activity.activityType) {
      ActivityType.run => 'Run',
      ActivityType.ride => 'Ride',
      ActivityType.walk => 'Walk',
    };
    final local = activity.startedAt.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$label $year-$month-$day $hour:$minute';
  }

  String buildExportFilename(Activity activity, {int maxBaseLength = 80}) {
    final local = activity.startedAt.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final date = '$year-$month-$day';
    final time = '$hour-$minute';
    final type = _sanitizeSegment(_activityTypeLabel(activity.activityType));
    final name = _sanitizeSegment(activity.name?.trim() ?? '');
    final prefix = '${date}_${time}_$type';
    if (name.isEmpty) return '$prefix.gpx';

    final availableForName = maxBaseLength - '${prefix}_'.length;
    final clippedName = availableForName <= 0
        ? ''
        : name.substring(
            0,
            name.length > availableForName ? availableForName : name.length,
          );
    final base = clippedName.isEmpty ? prefix : '${prefix}_$clippedName';
    return '$base.gpx';
  }

  String _activityTypeLabel(ActivityType type) {
    return switch (type) {
      ActivityType.run => 'Run',
      ActivityType.ride => 'Ride',
      ActivityType.walk => 'Walk',
    };
  }

  void _validatePoint(TrackPoint point) {
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude < -90 ||
        point.latitude > 90 ||
        point.longitude < -180 ||
        point.longitude > 180 ||
        (point.altitudeMeters != null && !point.altitudeMeters!.isFinite)) {
      throw const FormatException('Invalid track point coordinates for GPX');
    }
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _sanitizeSegment(String input) {
    if (input.isEmpty) return '';
    final umlautNormalized = input
        .replaceAll('Ä', 'Ae')
        .replaceAll('Ö', 'Oe')
        .replaceAll('Ü', 'Ue')
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
    final punctuationNormalized = umlautNormalized
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^A-Za-z0-9\-_]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[-_]+|[-_]+$'), '');
    return punctuationNormalized;
  }
}
