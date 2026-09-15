import 'dart:math';
import 'package:flutter/material.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/core/utils/sleep_score_calculator.dart';
import 'package:zapfit/features/health/widgets/sleep_card.dart';
import 'package:intl/intl.dart';

class SleepDetailScreen extends StatelessWidget {
  final SleepRecord record;
  final List<HeartRateRecord> heartRateRecords;

  const SleepDetailScreen({
    super.key,
    required this.record,
    this.heartRateRecords = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surfaceContainerHighest;
    final scoreResult = SleepScoreCalculator.calculate(
      totalSleepSeconds: record.totalSleepSeconds,
      deepSleepSeconds: record.deepSleepSeconds,
      lightSleepSeconds: record.lightSleepSeconds,
      remSleepSeconds: record.remSleepSeconds,
      awakeSleepSeconds: record.awakeSleepSeconds,
    );

    final sleepStart = record.sleepStartTime ?? record.date.subtract(Duration(seconds: record.totalSleepSeconds));
    final sleepEnd = record.sleepEndTime ?? record.date;
    final stages = _buildStages(record);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('d MMMM yyyy', 'ru').format(record.date)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildScoreHeader(context, scoreResult),
          const SizedBox(height: 16),
          _buildHypnogramCard(context, stages, sleepStart, sleepEnd, cardColor),
          const SizedBox(height: 12),
          _buildStagesBreakdown(context, record, cardColor),
          const SizedBox(height: 12),
          _buildTimeInfoCard(context, sleepStart, sleepEnd, cardColor),
          const SizedBox(height: 12),
          _buildHrCard(context, sleepStart, sleepEnd, cardColor),
          const SizedBox(height: 12),
          _buildDetailsGrid(context, record, cardColor),
        ],
      ),
    );
  }

  List<SleepStageSegment> _buildStages(SleepRecord record) {
    final stages = <SleepStageSegment>[];
    int offset = 0;
    final deepMin = record.deepSleepSeconds ~/ 60;
    final lightMin = record.lightSleepSeconds ~/ 60;
    final remMin = record.remSleepSeconds ~/ 60;
    final awakeMin = record.awakeSleepSeconds ~/ 60;

    if (deepMin > 0) {
      stages.add(SleepStageSegment(
        stage: SleepStage.deep,
        start: Duration(minutes: offset),
        end: Duration(minutes: offset + deepMin),
      ));
      offset += deepMin;
    }
    if (lightMin > 0) {
      stages.add(SleepStageSegment(
        stage: SleepStage.light,
        start: Duration(minutes: offset),
        end: Duration(minutes: offset + lightMin),
      ));
      offset += lightMin;
    }
    if (remMin > 0) {
      stages.add(SleepStageSegment(
        stage: SleepStage.rem,
        start: Duration(minutes: offset),
        end: Duration(minutes: offset + remMin),
      ));
      offset += remMin;
    }
    if (awakeMin > 0) {
      stages.add(SleepStageSegment(
        stage: SleepStage.awake,
        start: Duration(minutes: offset),
        end: Duration(minutes: offset + awakeMin),
      ));
    }
    return stages;
  }

  Widget _buildScoreHeader(BuildContext context, SleepScoreResult scoreResult) {
    final theme = Theme.of(context);
    final scoreColor = _scoreColor(scoreResult.score);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: scoreResult.score / 100,
                      strokeWidth: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${scoreResult.score}',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        'балл',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              scoreResult.qualityLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scoreColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHypnogramCard(BuildContext context, List<SleepStageSegment> stages, DateTime sleepStart, DateTime sleepEnd, Color cardColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Гипнограмма',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: stages.isEmpty
                  ? Center(
                      child: Text(
                        'Нет данных',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline),
                      ),
                    )
                  : CustomPaint(
                      size: Size.infinite,
                      painter: _HypnogramPainter(stages: stages),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TimeLabel(time: DateFormat('HH:mm').format(sleepStart)),
                _TimeLabel(time: DateFormat('HH:mm').format(sleepEnd)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _LegendDot(color: const Color(0xFF5C6BC0), label: 'Глубокий'),
                _LegendDot(color: const Color(0xFF9FA8DA), label: 'Лёгкий'),
                _LegendDot(color: const Color(0xFF7E57C2), label: 'REM'),
                _LegendDot(color: Theme.of(context).colorScheme.outline, label: 'Бодрств.'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStagesBreakdown(BuildContext context, SleepRecord record, Color cardColor) {
    final total = record.totalSleepSeconds;
    if (total == 0) return const SizedBox.shrink();

    final deepPct = (record.deepSleepSeconds / total * 100).round();
    final lightPct = (record.lightSleepSeconds / total * 100).round();
    final remPct = (record.remSleepSeconds / total * 100).round();
    final awakePct = total > 0 ? (record.awakeSleepSeconds / total * 100).round() : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Фазы сна',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _StageBar(
              label: 'Глубокий',
              seconds: record.deepSleepSeconds,
              percentage: deepPct,
              color: const Color(0xFF5C6BC0),
            ),
            const SizedBox(height: 8),
            _StageBar(
              label: 'Лёгкий',
              seconds: record.lightSleepSeconds,
              percentage: lightPct,
              color: const Color(0xFF9FA8DA),
            ),
            const SizedBox(height: 8),
            _StageBar(
              label: 'REM',
              seconds: record.remSleepSeconds,
              percentage: remPct,
              color: const Color(0xFF7E57C2),
            ),
            if (record.awakeSleepSeconds > 0) ...[
              const SizedBox(height: 8),
              _StageBar(
                label: 'Бодрств.',
                seconds: record.awakeSleepSeconds,
                percentage: awakePct,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfoCard(BuildContext context, DateTime sleepStart, DateTime sleepEnd, Color cardColor) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Icon(Icons.bedtime, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(sleepStart),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Засыпание',
                    style: TextStyle(color: theme.colorScheme.outline, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: theme.dividerColor,
            ),
            Expanded(
              child: Column(
                children: [
                  Icon(Icons.alarm, color: theme.colorScheme.tertiary, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(sleepEnd),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Пробуждение',
                    style: TextStyle(color: theme.colorScheme.outline, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHrCard(BuildContext context, DateTime sleepStart, DateTime sleepEnd, Color cardColor) {
    final theme = Theme.of(context);
    final hrRecords = heartRateRecords
        .where((r) =>
            r.timestamp.isAfter(sleepStart) &&
            r.timestamp.isBefore(sleepEnd))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Пульс во сне',
              style: TextStyle(
                color: theme.colorScheme.outline,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            if (hrRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Нет данных за это время',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 80,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _HrChartPainter(
                    records: hrRecords,
                    sleepStart: sleepStart,
                    sleepEnd: sleepEnd,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final avgHr = hrRecords.map((r) => r.bpm).reduce((a, b) => a + b) / hrRecords.length;
                  final minHr = hrRecords.map((r) => r.bpm).reduce(min);
                  final maxHr = hrRecords.map((r) => r.bpm).reduce(max);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _HrStat(label: 'Мин', value: '${minHr.round()}', color: const Color(0xFF4CAF50)),
                      _HrStat(label: 'Сред', value: '${avgHr.round()}', color: theme.colorScheme.tertiary),
                      _HrStat(label: 'Макс', value: '${maxHr.round()}', color: const Color(0xFFFF5722)),
                      _HrStat(label: 'Записей', value: '${hrRecords.length}', color: theme.colorScheme.outline),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsGrid(BuildContext context, SleepRecord record, Color cardColor) {
    final items = <_DetailItemData>[];
    if (record.restHeartRate != null) {
      items.add(_DetailItemData(icon: Icons.favorite, label: 'Покой HR', value: '${record.restHeartRate}'));
    }
    if (record.avgHeartRate != null) {
      items.add(_DetailItemData(icon: Icons.show_chart, label: 'Средний HR', value: '${record.avgHeartRate}'));
    }
    if (record.turnOverCount != null && record.turnOverCount! > 0) {
      items.add(_DetailItemData(icon: Icons.cached, label: 'Перевороты', value: '${record.turnOverCount}'));
    }
    if (record.intoSleepCount != null && record.intoSleepCount! > 0) {
      items.add(_DetailItemData(icon: Icons.login, label: 'Пробуждения', value: '${record.intoSleepCount}'));
    }
    if (record.dreamTime != null && record.dreamTime! > 0) {
      items.add(_DetailItemData(icon: Icons.cloud, label: 'Сновидения', value: '${record.dreamTime}м'));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Детали',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items.map((item) => _DetailItem(
                icon: item.icon,
                label: item.label,
                value: item.value,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFFFC107);
    return const Color(0xFFFF5722);
  }
}

class _DetailItemData {
  final IconData icon;
  final String label;
  final String value;
  const _DetailItemData({required this.icon, required this.label, required this.value});
}

class _TimeLabel extends StatelessWidget {
  final String time;
  const _TimeLabel({required this.time});

  @override
  Widget build(BuildContext context) {
    return Text(
      time,
      style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 11),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 10),
        ),
      ],
    );
  }
}

class _StageBar extends StatelessWidget {
  final String label;
  final int seconds;
  final int percentage;
  final Color color;

  const _StageBar({
    required this.label,
    required this.seconds,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final timeStr = h > 0 ? '${h}ч ${m}м' : '${m}м';
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(timeStr, style: TextStyle(fontSize: 12, color: theme.colorScheme.outline), textAlign: TextAlign.right),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text('$percentage%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

class _HrStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HrStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 10)),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 9)),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
        ],
      ),
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
    SleepStage.awake: Color(0xFF9E9E9E),
  };

  static const _stageHeights = {
    SleepStage.deep: 0.15,
    SleepStage.light: 0.5,
    SleepStage.rem: 0.85,
    SleepStage.awake: 1.0,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (stages.isEmpty) return;
    final totalMs = stages.last.end.inMilliseconds - stages.first.start.inMilliseconds;
    if (totalMs <= 0) return;

    for (final stage in stages) {
      final x1 = size.width * (stage.start.inMilliseconds - stages.first.start.inMilliseconds) / totalMs;
      final x2 = size.width * (stage.end.inMilliseconds - stages.first.start.inMilliseconds) / totalMs;
      final y = size.height * (1 - (_stageHeights[stage.stage] ?? 0.5));

      canvas.drawRect(
        Rect.fromLTWH(x1, y - 2, max(x2 - x1, 1), 4),
        Paint()
          ..color = _stageColors[stage.stage] ?? Colors.grey
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HypnogramPainter oldDelegate) => oldDelegate.stages != stages;
}

class _HrChartPainter extends CustomPainter {
  final List<HeartRateRecord> records;
  final DateTime sleepStart;
  final DateTime sleepEnd;

  _HrChartPainter({
    required this.records,
    required this.sleepStart,
    required this.sleepEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;

    final totalMs = sleepEnd.millisecondsSinceEpoch - sleepStart.millisecondsSinceEpoch;
    if (totalMs <= 0) return;

    final minBpm = records.map((r) => r.bpm).reduce(min).toDouble();
    final maxBpm = records.map((r) => r.bpm).reduce(max).toDouble();
    final range = (maxBpm - minBpm).clamp(30.0, 100.0);

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < records.length; i++) {
      final x = size.width * (records[i].timestamp.millisecondsSinceEpoch - sleepStart.millisecondsSinceEpoch) / totalMs;
      final y = size.height * (1 - (records[i].bpm - minBpm) / range);

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

    canvas.drawPath(
      fillPath,
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.redAccent.withValues(alpha: 0.2),
          Colors.redAccent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HrChartPainter oldDelegate) =>
      oldDelegate.records != records ||
      oldDelegate.sleepStart != sleepStart ||
      oldDelegate.sleepEnd != sleepEnd;
}
