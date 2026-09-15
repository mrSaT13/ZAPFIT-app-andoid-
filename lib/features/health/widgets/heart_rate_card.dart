import 'package:flutter/material.dart';
import 'package:zapfit/core/models/hr_zones.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';

class HeartRateCard extends StatelessWidget {
  final int? currentBpm;
  final int? restingBpm;
  final int? maxBpm;
  final List<HeartRatePoint> todayPoints;

  const HeartRateCard({
    super.key,
    this.currentBpm,
    this.restingBpm,
    this.maxBpm,
    this.todayPoints = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsController.instance;
    final age = settings.userAge ?? 25;
    final zones = HeartRateZones.fromAge(age);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.red[400], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Пульс',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (currentBpm != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currentBpm',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : zones.getZone(currentBpm!).color.computeLuminance() > 0.5
                              ? Colors.black87
                              : zones.getZone(currentBpm!).color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'уд/мин',
                      style: TextStyle(
                        fontSize: 18,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: zones.getZone(currentBpm!).color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      zones.getZone(currentBpm!).nameRu,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: zones.getZone(currentBpm!).color.computeLuminance() > 0.5
                            ? Colors.black87
                            : zones.getZone(currentBpm!).color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ] else ...[
              Text(
                'Нет данных',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 8),
            ],
            // Min / Resting / Max row
            Row(
              children: [
                _StatItem(
                  label: 'Мин',
                  value: todayPoints.isNotEmpty
                      ? '${todayPoints.map((p) => p.bpm).reduce((a, b) => a < b ? a : b)}'
                      : '—',
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _StatItem(
                  label: 'Покой',
                  value: restingBpm != null ? '$restingBpm' : '—',
                  color: Colors.green,
                ),
                const SizedBox(width: 16),
                _StatItem(
                  label: 'Макс',
                  value: todayPoints.isNotEmpty
                      ? '${todayPoints.map((p) => p.bpm).reduce((a, b) => a > b ? a : b)}'
                      : (maxBpm != null ? '$maxBpm' : '—'),
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Chart
            if (todayPoints.isNotEmpty)
              SizedBox(
                height: 80,
                child: _HrChart(points: todayPoints, zones: zones),
              )
            else
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'График за сегодня появится после тренировки',
                    style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class HeartRatePoint {
  final DateTime time;
  final int bpm;

  const HeartRatePoint({required this.time, required this.bpm});
}

class _HrChart extends StatelessWidget {
  final List<HeartRatePoint> points;
  final HeartRateZones zones;

  const _HrChart({required this.points, required this.zones});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.length < 2) return const SizedBox.shrink();

    final maxBpm = zones.maxHeartRate;
    final minBpm = points.map((p) => p.bpm).reduce((a, b) => a < b ? a : b);
    final range = (maxBpm - minBpm).toDouble().clamp(1.0, double.infinity);

    return CustomPaint(
      size: Size.infinite,
      painter: _HrChartPainter(
        points: points,
        zones: zones,
        maxBpm: maxBpm,
        minBpm: minBpm,
        textColor: theme.colorScheme.outline,
      ),
    );
  }
}

class _HrChartPainter extends CustomPainter {
  final List<HeartRatePoint> points;
  final HeartRateZones zones;
  final int maxBpm;
  final int minBpm;
  final Color textColor;

  _HrChartPainter({
    required this.points,
    required this.zones,
    required this.maxBpm,
    required this.minBpm,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final width = size.width;
    final height = size.height;
    final padding = const EdgeInsets.only(left: 2, right: 2, top: 4, bottom: 16);
    final chartWidth = width - padding.left - padding.right;
    final chartHeight = height - padding.top - padding.bottom;

    final range = (maxBpm - minBpm).toDouble().clamp(1.0, double.infinity);
    final startTime = points.first.time;
    final endTime = points.last.time;
    final timeRange = endTime.difference(startTime).inMilliseconds.toDouble().clamp(1.0, double.infinity);

    // Draw zone backgrounds
    for (final zone in zones.zones) {
      final y1 = padding.top + chartHeight * (1 - (zone.maxBpm - minBpm) / range);
      final y2 = padding.top + chartHeight * (1 - (zone.minBpm - minBpm) / range);
      final rect = Rect.fromLTRB(padding.left, y1.clamp(padding.top, padding.top + chartHeight), width - padding.right, y2.clamp(padding.top, padding.top + chartHeight));
      canvas.drawRect(rect, Paint()..color = zone.color.withValues(alpha: 0.08));
    }

    // Draw HR line
    final linePaint = Paint()
      ..color = Colors.red[400]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = padding.left + chartWidth * (points[i].time.difference(startTime).inMilliseconds / timeRange);
      final y = padding.top + chartHeight * (1 - (points[i].bpm - minBpm) / range);
      if (i == 0) {
        path.moveTo(x, y.clamp(padding.top, padding.top + chartHeight));
      } else {
        path.lineTo(x, y.clamp(padding.top, padding.top + chartHeight));
      }
    }
    canvas.drawPath(path, linePaint);

    // Draw fill under line
    final fillPath = Path.from(path);
    fillPath.lineTo(padding.left + chartWidth, padding.top + chartHeight);
    fillPath.lineTo(padding.left, padding.top + chartHeight);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = Colors.red[400]!.withValues(alpha: 0.1));

    // Draw time labels (every 4 hours)
    final labelPaint = Paint()..color = textColor.withValues(alpha: 0.6);
    final labelStyle = TextStyle(color: textColor, fontSize: 10);
    for (int h = 0; h <= 24; h += 4) {
      final labelTime = DateTime(startTime.year, startTime.month, startTime.day, h);
      if (labelTime.isBefore(startTime) || labelTime.isAfter(endTime)) continue;
      final x = padding.left + chartWidth * (labelTime.difference(startTime).inMilliseconds / timeRange);
      final tp = TextPainter(
        text: TextSpan(text: '${h.toString().padLeft(2, '0')}:00', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, height - padding.bottom + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _HrChartPainter oldDelegate) => oldDelegate.points != points;
}
