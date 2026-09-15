import 'package:flutter/material.dart';

enum SleepStage {
  deep,
  light,
  rem,
  awake,
}

class SleepStageSegment {
  final SleepStage stage;
  final Duration start;
  final Duration end;

  const SleepStageSegment({
    required this.stage,
    required this.start,
    required this.end,
  });

  Duration get duration => end - start;
}

class SleepData {
  final DateTime date;
  final Duration totalSleep;
  final Duration deepSleep;
  final Duration lightSleep;
  final Duration remSleep;
  final Duration awakeTime;
  final int? sleepScore;
  final int? restHeartRate;
  final int? turnOverCount;
  final int? intoSleepCount;
  final int? lazyBedCount;
  final int? dreamTime;
  final int? sleepFeeling;
  final List<SleepStageSegment> stages;
  final DateTime? sleepStart;
  final DateTime? sleepEnd;

  const SleepData({
    required this.date,
    required this.totalSleep,
    required this.deepSleep,
    required this.lightSleep,
    required this.remSleep,
    required this.awakeTime,
    this.sleepScore,
    this.restHeartRate,
    this.turnOverCount,
    this.intoSleepCount,
    this.lazyBedCount,
    this.dreamTime,
    this.sleepFeeling,
    this.stages = const [],
    this.sleepStart,
    this.sleepEnd,
  });

  double get deepPct => totalSleep.inMinutes > 0 ? deepSleep.inMinutes / totalSleep.inMinutes : 0;
  double get lightPct => totalSleep.inMinutes > 0 ? lightSleep.inMinutes / totalSleep.inMinutes : 0;
  double get remPct => totalSleep.inMinutes > 0 ? remSleep.inMinutes / totalSleep.inMinutes : 0;

  String get totalFormatted => _formatDuration(totalSleep);
  String get deepFormatted => _formatDuration(deepSleep);
  String get lightFormatted => _formatDuration(lightSleep);
  String get remFormatted => _formatDuration(remSleep);

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}ч ${m}м';
    return '${m}м';
  }
}

class SleepCard extends StatelessWidget {
  final SleepData? data;

  const SleepCard({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                Icon(Icons.bedtime, color: Colors.indigo[300], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Сон',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (data?.sleepScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _scoreColor(data!.sleepScore!).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${data!.sleepScore}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _scoreColor(data!.sleepScore!),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (data == null || data!.totalSleep.inMinutes == 0) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.bedtime_outlined, size: 40, color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                      const SizedBox(height: 8),
                      Text(
                        'Данные сна пока нет',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Circular sleep score gauge
              if (data!.sleepScore != null) ...[
                Center(
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                            value: data!.sleepScore! / 100,
                            strokeWidth: 7,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(_scoreColor(data!.sleepScore!)),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${data!.sleepScore}',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _scoreColor(data!.sleepScore!))),
                            const Text('балл', style: TextStyle(fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Quality recommendation text
                Center(
                  child: Text(
                    _qualityText(data!.sleepScore!),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _scoreColor(data!.sleepScore!),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Total sleep with time range
              Row(
                children: [
                  Text(
                    data!.totalFormatted,
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (data!.sleepStart != null && data!.sleepEnd != null)
                    Text(
                      '${_timeFmt(data!.sleepStart!)} – ${_timeFmt(data!.sleepEnd!)}',
                      style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Sleep stages bar
              _StagesBar(data: data!),
              const SizedBox(height: 8),
              // Stage details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StageDetail(label: 'Глубокий', value: data!.deepFormatted, color: const Color(0xFF5C6BC0)),
                  _StageDetail(label: 'Лёгкий', value: data!.lightFormatted, color: const Color(0xFF9FA8DA)),
                  _StageDetail(label: 'REM', value: data!.remFormatted, color: const Color(0xFF7E57C2)),
                  if (data!.awakeTime.inMinutes > 0)
                    _StageDetail(label: 'Бодрств.', value: SleepData._formatDuration(data!.awakeTime), color: theme.colorScheme.outline),
                ],
              ),
              const SizedBox(height: 12),
              // Details row
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (data!.restHeartRate != null)
                    _DetailChip(icon: Icons.favorite_border, label: 'Покой: ${data!.restHeartRate}'),
                  if (data!.turnOverCount != null && data!.turnOverCount! > 0)
                    _DetailChip(icon: Icons.cached, label: 'Перевороты: ${data!.turnOverCount}'),
                  if (data!.intoSleepCount != null && data!.intoSleepCount! > 0)
                    _DetailChip(icon: Icons.login, label: 'Подъёмы: ${data!.intoSleepCount}'),
                  if (data!.dreamTime != null && data!.dreamTime! > 0)
                    _DetailChip(icon: Icons.cloud, label: 'Сновидения: ${data!.dreamTime}м'),
                ],
              ),
              const SizedBox(height: 8),
              // Hypnogram
              if (data!.stages.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: _Hypnogram(stages: data!.stages),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _qualityText(int score) {
    if (score >= 90) return 'Отлично — выспались';
    if (score >= 75) return 'Хорошо — нормальный сон';
    if (score >= 60) return 'Удовлетворительно';
    if (score >= 40) return 'Плохо — рекомендуется отдых';
    return 'Критично — нужно выспаться';
  }

  String _timeFmt(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StagesBar extends StatelessWidget {
  final SleepData data;
  const _StagesBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.totalSleep.inMinutes;
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            if (data.deepSleep.inMinutes > 0)
              Expanded(
                flex: data.deepSleep.inMinutes,
                child: Container(color: const Color(0xFF5C6BC0)),
              ),
            if (data.lightSleep.inMinutes > 0)
              Expanded(
                flex: data.lightSleep.inMinutes,
                child: Container(color: const Color(0xFF9FA8DA)),
              ),
            if (data.remSleep.inMinutes > 0)
              Expanded(
                flex: data.remSleep.inMinutes,
                child: Container(color: const Color(0xFF7E57C2)),
              ),
          ],
        ),
      ),
    );
  }
}

class _StageDetail extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StageDetail({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}

class _Hypnogram extends StatelessWidget {
  final List<SleepStageSegment> stages;
  const _Hypnogram({required this.stages});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _HypnogramPainter(stages: stages),
    );
  }
}

class _HypnogramPainter extends CustomPainter {
  final List<SleepStageSegment> stages;
  _HypnogramPainter({required this.stages});

  static const _stageColors = {
    SleepStage.deep: Color(0xFF5C6BC0),
    SleepStage.light: Color(0xFF9FA8DA),
    SleepStage.rem: Color(0xFF7E57C2),
    SleepStage.awake: Color(0xFFE0E0E0),
  };

  static const _stageHeights = {
    SleepStage.deep: 0.2,
    SleepStage.light: 0.5,
    SleepStage.rem: 0.8,
    SleepStage.awake: 1.0,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (stages.isEmpty) return;

    final totalMs = stages.last.end.inMilliseconds - stages.first.start.inMilliseconds;
    if (totalMs <= 0) return;

    final path = Path();
    double? lastY;

    for (final stage in stages) {
      final x1 = size.width * (stage.start.inMilliseconds - stages.first.start.inMilliseconds) / totalMs;
      final x2 = size.width * (stage.end.inMilliseconds - stages.first.start.inMilliseconds) / totalMs;
      final y = size.height * (1 - (_stageHeights[stage.stage] ?? 0.5));

      if (lastY != null) {
        // Vertical line to new stage
        path.moveTo(x1, lastY);
        path.lineTo(x1, y);
      }
      // Horizontal line for stage duration
      path.moveTo(x1, y);
      path.lineTo(x2, y);
      lastY = y;
    }

    // Draw colored segments
    for (final stage in stages) {
      final x1 = size.width * (stage.start.inMilliseconds - stages.first.start.inMilliseconds) / totalMs;
      final x2 = size.width * (stage.end.inMilliseconds - stages.first.start.inMilliseconds) / totalMs;
      final y = size.height * (1 - (_stageHeights[stage.stage] ?? 0.5));

      canvas.drawLine(
        Offset(x1, y),
        Offset(x2, y),
        Paint()
          ..color = _stageColors[stage.stage] ?? Colors.grey
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HypnogramPainter oldDelegate) => oldDelegate.stages != stages;
}
