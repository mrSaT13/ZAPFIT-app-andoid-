import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/constants/map_constants.dart';

class ActivityShareCard extends StatefulWidget {
  final ActivityRecord activity;
  final List<ActivityPoint> points;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final double? avgSpeed;
  final double? maxSpeed;
  final double? totalAscent;
  final int? movingTimeSeconds;
  final int? pausedTimeSeconds;
  final double? estimatedCalories;

  const ActivityShareCard({
    super.key,
    required this.activity,
    required this.points,
    this.avgHeartRate,
    this.maxHeartRate,
    this.avgSpeed,
    this.maxSpeed,
    this.totalAscent,
    this.movingTimeSeconds,
    this.pausedTimeSeconds,
    this.estimatedCalories,
  });

  @override
  State<ActivityShareCard> createState() => _ActivityShareCardState();
}

class _ActivityShareCardState extends State<ActivityShareCard> {
  final GlobalKey _repaintKey = GlobalKey();

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return "${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
    }
    return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  String _formatPace(double speedKmh) {
    if (speedKmh <= 0) return '--:--';
    final paceSeconds = 3600 / speedKmh;
    final m = (paceSeconds / 60).floor();
    final s = (paceSeconds % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distanceKm = widget.activity.distanceMeters / 1000;
    final duration = widget.activity.durationSeconds;
    final avgSpeed = widget.avgSpeed ?? (duration > 0 ? (distanceKm / (duration / 3600)) : 0.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поделиться результатом'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareCard,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            RepaintBoundary(
              key: _repaintKey,
              child: _buildCard(theme, distanceKm, avgSpeed),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _shareCard,
                    icon: const Icon(Icons.share),
                    label: const Text('Поделиться'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, double distanceKm, double avgSpeed) {
    final polylinePoints = widget.points
        .where((p) => p.latitude != 0 && p.longitude != 0)
        .map((p) => ll.LatLng(p.latitude, p.longitude))
        .toList();

    final center = polylinePoints.isNotEmpty
        ? polylinePoints.last
        : const ll.LatLng(MapConstants.defaultLatitude, MapConstants.defaultLongitude);

    final startDate = widget.activity.startedAt;
    final dateStr = '${startDate.day}.${startDate.month.toString().padLeft(2, '0')}.${startDate.year}';
    final timeStr = '${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}';

    return Container(
      width: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
          ],
          stops: [0.0, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              height: 180,
              width: 360,
              child: polylinePoints.isNotEmpty
                  ? FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 14,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: MapConstants.userAgent,
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: polylinePoints,
                              color: Colors.white,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      ],
                    )
                  : Container(
                      color: const Color(0xFF16213E),
                      child: const Center(
                        child: Icon(Icons.map_outlined, color: Colors.white54, size: 48),
                      ),
                    ),
            ),
          ),

          // Activity info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.activity.kind.labelRu,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$dateStr · $timeStr',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Big distance
                Center(
                  child: Column(
                    children: [
                      Text(
                        distanceKm.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'километров',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Stats grid
                _buildStatsRow(avgSpeed),
                const SizedBox(height: 16),

                // Heart rate if available
                if (widget.avgHeartRate != null && widget.avgHeartRate! > 0) ...[
                  _buildHeartRateRow(),
                  const SizedBox(height: 16),
                ],

                // Bottom brand
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/logo/logo.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ZAPFIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    if (widget.estimatedCalories != null && widget.estimatedCalories! > 0)
                      Text(
                        '${widget.estimatedCalories!.round()} ккал',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(double avgSpeed) {
    final duration = widget.activity.durationSeconds;
    final avgPace = _formatPace(avgSpeed);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _shareStat(_formatDuration(duration), 'Время'),
        _shareStat(avgSpeed.toStringAsFixed(1), 'км/ч'),
        _shareStat(avgPace, 'мин/км'),
        if (widget.maxSpeed != null && widget.maxSpeed! > 0)
          _shareStat(widget.maxSpeed!.toStringAsFixed(1), 'макс км/ч'),
      ],
    );
  }

  Widget _buildHeartRateRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (widget.avgHeartRate != null)
          _shareStat('${widget.avgHeartRate}', 'ср. пульс'),
        if (widget.maxHeartRate != null)
          _shareStat('${widget.maxHeartRate}', 'макс пульс'),
        if (widget.totalAscent != null && widget.totalAscent! > 0)
          _shareStat('+${widget.totalAscent!.toInt()}', 'набор м'),
      ],
    );
  }

  Widget _shareStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Future<void> _shareCard() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/zapfit_share.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Мой результат: ${(widget.activity.distanceMeters / 1000).toStringAsFixed(2)} км за ${_formatDuration(widget.activity.durationSeconds)}',
      );
    } catch (e) {
      debugPrint('Share card error: $e');
    }
  }
}
