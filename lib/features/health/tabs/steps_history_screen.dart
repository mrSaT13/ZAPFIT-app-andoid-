import 'package:flutter/material.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class StepsHistoryScreen extends StatefulWidget {
  final List<StepsRecord> records;
  const StepsHistoryScreen({super.key, required this.records});

  @override
  State<StepsHistoryScreen> createState() => _StepsHistoryScreenState();
}

class _StepsHistoryScreenState extends State<StepsHistoryScreen> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  late List<StepsRecord> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.records;
  }

  void _applyFilter() {
    setState(() {
      _filtered = widget.records.where((r) {
        if (_dateFrom != null && r.date.isBefore(_dateFrom!)) return false;
        if (_dateTo != null && r.date.isAfter(_dateTo!.add(const Duration(days: 1)))) return false;
        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSteps = _filtered.fold<int>(0, (sum, r) => sum + r.steps);
    final avgSteps = _filtered.isNotEmpty ? totalSteps ~/ _filtered.length : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('История шагов'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          if (_dateFrom != null || _dateTo != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _dateFrom = null;
                  _dateTo = null;
                  _filtered = widget.records;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _summaryCard(theme, 'Всего', '$totalSteps', Icons.directions_walk),
                const SizedBox(width: 8),
                _summaryCard(theme, 'Среднее', '$avgSteps', Icons.trending_up),
                const SizedBox(width: 8),
                _summaryCard(theme, 'Дней', '${_filtered.length}', Icons.calendar_today),
              ],
            ),
          ),
          // Chart
          if (_filtered.length >= 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 120,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _filtered.map((r) => r.steps.toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= _filtered.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateFormat('dd.MM').format(_filtered[idx].date),
                                style: const TextStyle(fontSize: 8, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: _filtered.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.steps.toDouble(),
                            color: theme.colorScheme.primary,
                            width: 12,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Filter chips
          if (_dateFrom != null || _dateTo != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_dateFrom != null)
                    Chip(
                      label: Text('От: ${DateFormat('dd.MM.yyyy').format(_dateFrom!)}'),
                      onDeleted: () {
                        _dateFrom = null;
                        _applyFilter();
                      },
                    ),
                  if (_dateFrom != null && _dateTo != null) const SizedBox(width: 8),
                  if (_dateTo != null)
                    Chip(
                      label: Text('До: ${DateFormat('dd.MM.yyyy').format(_dateTo!)}'),
                      onDeleted: () {
                        _dateTo = null;
                        _applyFilter();
                      },
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Records list
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('Нет данных за выбранный период'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final r = _filtered[index];
                      final distKm = (r.distanceMeters ?? r.estimatedDistanceMeters) / 1000;
                      final cal = r.calories ?? r.estimatedCalories;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          leading: const Icon(Icons.directions_walk, color: Colors.green, size: 20),
                          title: Text('${r.steps} шагов', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${DateFormat('dd.MM.yyyy, EEEE', 'ru').format(r.date)}  •  ${distKm.toStringAsFixed(1)} км  •  ${cal.toStringAsFixed(0)} ккал',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Icon(
                            r.isSynced ? Icons.cloud_done : Icons.cloud_upload_outlined,
                            color: r.isSynced ? Colors.green : Colors.orange,
                            size: 14,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(ThemeData theme, String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() async {
    final pickedFrom = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ru'),
    );
    if (pickedFrom == null || !mounted) return;
    final pickedTo = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? DateTime.now(),
      firstDate: pickedFrom,
      lastDate: DateTime.now(),
      locale: const Locale('ru'),
    );
    if (pickedTo == null) return;
    setState(() {
      _dateFrom = pickedFrom;
      _dateTo = pickedTo;
    });
    _applyFilter();
  }
}
