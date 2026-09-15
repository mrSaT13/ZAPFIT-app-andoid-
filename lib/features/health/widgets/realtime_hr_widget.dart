import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/services/bluetooth_sensor_service.dart';

/// Real-time heart rate display widget for BLE-connected devices.
/// Shows current HR, HR zone, and a simple live graph.
class RealtimeHrWidget extends StatefulWidget {
  final bool showGraph;
  final bool compact;

  const RealtimeHrWidget({
    super.key,
    this.showGraph = true,
    this.compact = false,
  });

  @override
  State<RealtimeHrWidget> createState() => _RealtimeHrWidgetState();
}

class _RealtimeHrWidgetState extends State<RealtimeHrWidget> {
  int? _currentBpm;
  StreamSubscription<int>? _hrSub;
  final List<int> _recentHr = [];

  @override
  void initState() {
    super.initState();
    _hrSub = serviceLocator<BluetoothSensorService>().heartRate.listen((bpm) {
      if (mounted) {
        setState(() {
          _currentBpm = bpm;
          _recentHr.add(bpm);
          if (_recentHr.length > 60) _recentHr.removeAt(0);
        });
      }
    });
  }

  @override
  void dispose() {
    _hrSub?.cancel();
    super.dispose();
  }

  Color _hrColor(int bpm) {
    if (bpm < 60) return Colors.blue;
    if (bpm < 100) return Colors.green;
    if (bpm < 140) return Colors.orange;
    if (bpm < 170) return Colors.deepOrange;
    return Colors.red;
  }

  String _hrZone(int bpm) {
    if (bpm < 60) return 'Отдых';
    if (bpm < 100) return 'Жировая';
    if (bpm < 140) return 'Аэробная';
    if (bpm < 170) return 'Анаэробная';
    return 'Макс.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _currentBpm != null ? _hrColor(_currentBpm!) : Colors.grey;

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            _currentBpm != null ? '$_currentBpm' : '--',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
          Text(' bpm', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: color, size: 20),
                const SizedBox(width: 8),
                const Text('Пульс в реальном времени', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentBpm != null ? _hrZone(_currentBpm!) : 'Нет данных',
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // BPM display
            Center(
              child: Column(
                children: [
                  Text(
                    _currentBpm != null ? '$_currentBpm' : '--',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    'уд/мин',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (widget.showGraph && _recentHr.length >= 2) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _HrGraphPainter(
                    data: _recentHr,
                    color: color,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Zone bar
            _buildZoneBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneBar() {
    final zones = [
      ('Отдых', 0.0, 60, Colors.blue),
      ('Жировая', 60, 100, Colors.green),
      ('Аэробная', 100, 140, Colors.orange),
      ('Анаэробная', 140, 170, Colors.deepOrange),
      ('Макс.', 170, 220, Colors.red),
    ];

    final bpm = _currentBpm ?? 0;

    return Column(
      children: [
        Row(
          children: zones.map((z) {
            final isActive = bpm >= z.$2 && bpm < z.$3;
            return Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isActive ? z.$4 : z.$4.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: zones.map((z) => Text(
            z.$1,
            style: TextStyle(fontSize: 8, color: Colors.grey.shade500),
          )).toList(),
        ),
      ],
    );
  }
}

class _HrGraphPainter extends CustomPainter {
  final List<int> data;
  final Color color;

  _HrGraphPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final minVal = data.reduce((a, b) => a < b ? a : b).toDouble();
    final maxVal = data.reduce((a, b) => a > b ? a : b).toDouble();
    final range = (maxVal - minVal).clamp(1, 200).toDouble();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minVal) / range * size.height * 0.8) - size.height * 0.1;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HrGraphPainter old) => true;
}
