import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zapfit/core/models/training_metrics.dart';
import 'package:zapfit/core/services/training_metrics_service.dart';
import 'package:zapfit/core/utils/acwr_calculator.dart';
import 'package:intl/intl.dart';

class TrainingMetricsCard extends StatefulWidget {
  const TrainingMetricsCard({super.key});

  @override
  State<TrainingMetricsCard> createState() => _TrainingMetricsCardState();
}

class _TrainingMetricsCardState extends State<TrainingMetricsCard> {
  TrainingMetrics? _metrics;
  List<Map<String, dynamic>> _formChart = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final metrics = await TrainingMetricsService.instance.calculateMetrics();
      final chart = await TrainingMetricsService.instance.getFormChart();
      if (mounted) setState(() { _metrics = metrics; _formChart = chart; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
    if (_metrics == null) return const SizedBox.shrink();

    final m = _metrics!;
    // === ZAPFIT metrics ===
    final acwr = AcwrCalculator.calculate(atl: m.atl, ctl: m.ctl);
    return Column(
      children: [
        // TSB, CTL, ATL карточки
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _metricTile(context, 'TSB', m.tsb.toStringAsFixed(1), m.formDescription, _tsbColor(m.tsb))),
              const SizedBox(width: 6),
              Expanded(child: _metricTile(context, 'CTL', m.ctl.toStringAsFixed(1), m.ctlDescription, Colors.blue)),
              const SizedBox(width: 6),
              Expanded(child: _metricTile(context, 'ATL', m.atl.toStringAsFixed(1), m.atlDescription, Colors.orange)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // TSS за сегодня + восстановление
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _metricTile(context, 'TSS', m.tssToday.toStringAsFixed(0), 'сегодня', Colors.purple)),
              const SizedBox(width: 6),
              Expanded(child: _metricTile(context, 'Восстановление', m.recoveryDays == 0 ? 'Готов' : '${m.recoveryDays} дн.', m.recoveryAdvice, m.recoveryDays == 0 ? Colors.green : Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // === ZAPFIT metrics ===
        if (m.ctl > 0)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _metricTile(context, 'ACWR', acwr.toStringAsFixed(2), AcwrCalculator.classify(acwr), _acwrColor(acwr))),
              ],
            ),
          ),
        const SizedBox(height: 6),
        // HR estimation
        if (m.estimatedRestingHr != null || m.estimatedMaxHr != null)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (m.estimatedRestingHr != null)
                  Expanded(child: _metricTile(context, 'Пульс покоя', '${m.estimatedRestingHr}', 'авто-оценка', Colors.teal)),
                if (m.estimatedRestingHr != null && m.estimatedMaxHr != null)
                  const SizedBox(width: 6),
                if (m.estimatedMaxHr != null)
                  Expanded(child: _metricTile(context, 'Макс. пульс', '${m.estimatedMaxHr}', 'авто-оценка', Colors.deepOrange)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        // График формы
        if (_formChart.isNotEmpty) _buildFormChart(theme),
        const SizedBox(height: 4),
        Text('Динамика формы (30 дней)', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }

  Widget _metricTile(BuildContext context, String label, String value, String desc, Color color) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: 10, color: theme.colorScheme.outline), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFormChart(ThemeData theme) {
    final ctlData = _formChart.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['ctl'] as double))).toList();
    final atlData = _formChart.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['atl'] as double))).toList();
    final tsbData = _formChart.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['tsb'] as double))).toList();

    final maxY = [...ctlData, ...atlData].map((s) => s.y).fold(0.0, max) * 1.2;
    final minY = tsbData.map((s) => s.y).fold(0.0, min) - 10;

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
                _legendDot(Colors.blue, 'CTL'),
                const SizedBox(width: 12),
                _legendDot(Colors.orange, 'ATL'),
                const SizedBox(width: 12),
                _legendDot(Colors.green, 'TSB'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY / 4).clamp(5, double.infinity),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      interval: 7,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= _formChart.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(DateFormat('dd.MM').format(_formChart[idx]['date'] as DateTime),
                            style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        );
                      },
                    )),
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                        style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    )),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(spots: ctlData, isCurved: true, color: Colors.blue, barWidth: 2, dotData: const FlDotData(show: false)),
                    LineChartBarData(spots: atlData, isCurved: true, color: Colors.orange, barWidth: 2, dotData: const FlDotData(show: false)),
                    LineChartBarData(spots: tsbData, isCurved: true, color: Colors.green, barWidth: 2, dotData: const FlDotData(show: false), belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withOpacity(0.05),
                    )),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final names = {0: 'CTL', 1: 'ATL', 2: 'TSB'};
                        return LineTooltipItem(
                          '${names[s.barIndex] ?? ''}: ${s.y.toStringAsFixed(1)}',
                          TextStyle(color: s.bar.color, fontSize: 11),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Color _tsbColor(double tsb) {
    if (tsb > 25) return Colors.blue;
    if (tsb > 5) return Colors.green;
    if (tsb > -10) return Colors.amber;
    if (tsb > -30) return Colors.orange;
    return Colors.red;
  }

  Color _acwrColor(double acwr) {
    if (acwr <= 0) return Colors.grey;
    if (acwr < 0.8) return Colors.blue;
    if (acwr <= 1.3) return Colors.green;
    if (acwr <= 1.5) return Colors.orange;
    return Colors.red;
  }
}
