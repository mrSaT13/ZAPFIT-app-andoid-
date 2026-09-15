import 'package:flutter/material.dart';
import 'package:zapfit/core/models/activity_models.dart';

class ActivityCalendarSheet extends StatefulWidget {
  final List<ActivityRecord> activities;
  const ActivityCalendarSheet({super.key, required this.activities});

  @override
  State<ActivityCalendarSheet> createState() => _ActivityCalendarSheetState();
}

class _ActivityCalendarSheetState extends State<ActivityCalendarSheet> {
  late int _selectedYear;
  late List<int> _availableYears;

  @override
  void initState() {
    super.initState();
    _availableYears = widget.activities
        .map((a) => a.startedAt.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (_availableYears.isEmpty) _availableYears = [DateTime.now().year];
    _selectedYear = _availableYears.first;
  }

  Map<DateTime, double> _getActivityMap() {
    final map = <DateTime, double>{};
    for (final a in widget.activities) {
      if (a.startedAt.year != _selectedYear) continue;
      final day = DateTime(a.startedAt.year, a.startedAt.month, a.startedAt.day);
      map[day] = (map[day] ?? 0) + a.distanceMeters;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final activityMap = _getActivityMap();
    final totalKm = activityMap.values.fold(0.0, (a, b) => a + b) / 1000;
    final totalDays = activityMap.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$totalDays дней активностей · ${totalKm.toStringAsFixed(1)} км',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              if (_availableYears.length > 1)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableYears.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final year = _availableYears[index];
                      return ChoiceChip(
                        label: Text('$year'),
                        selected: year == _selectedYear,
                        onSelected: (_) => setState(() => _selectedYear = year),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),

              _buildCalendarGrid(activityMap),
              const SizedBox(height: 20),

              _buildLegend(),
              const SizedBox(height: 20),

              _buildMonthlyStats(activityMap),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarGrid(Map<DateTime, double> activityMap) {
    final now = DateTime.now();
    final endOfYear = DateTime(_selectedYear, 12, 31);
    final today = DateTime(now.year, now.month, now.day);

    var currentDay = DateTime(_selectedYear, 1, 1);
    while (currentDay.weekday != DateTime.monday) {
      currentDay = currentDay.subtract(const Duration(days: 1));
    }

    final maxKm = activityMap.values.isEmpty
        ? 1.0
        : activityMap.values.reduce((a, b) => a > b ? a : b);

    final weeks = <List<DateTime>>[];
    while (currentDay.isBefore(endOfYear) || currentDay.isAtSameMomentAs(_endOfDay(endOfYear))) {
      final week = <DateTime>[];
      for (int d = 0; d < 7; d++) {
        week.add(currentDay);
        currentDay = currentDay.add(const Duration(days: 1));
      }
      weeks.add(week);
      if (currentDay.isAfter(_endOfDay(endOfYear))) break;
    }

    final monthLabels = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
    final dayLabels = ['Пн', '', 'Ср', '', 'Пт', '', ''];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 24),
            ...weeks.map((week) {
              final firstDay = week.first;
              final showLabel = firstDay.day <= 7;
              return Expanded(
                child: showLabel
                    ? Text(monthLabels[firstDay.month - 1], style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center)
                    : const SizedBox.shrink(),
              );
            }),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: dayLabels.map((label) => SizedBox(
                width: 20, height: 13,
                child: Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey)),
              )).toList(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                children: List.generate(7, (dayIndex) {
                  return Row(
                    children: weeks.map((week) {
                      if (dayIndex >= week.length) return const Expanded(child: SizedBox(height: 11));
                      final day = week[dayIndex];
                      final isCurrentYear = day.year == _selectedYear;
                      final isFuture = day.isAfter(today);
                      final km = activityMap[DateTime(day.year, day.month, day.day)] ?? 0;
                      final intensity = km > 0 ? (km / maxKm).clamp(0.2, 1.0) : 0.0;

                      Color cellColor;
                      if (!isCurrentYear || isFuture) {
                        cellColor = Colors.grey.shade200;
                      } else if (km == 0) {
                        cellColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
                      } else {
                        cellColor = Color.lerp(Colors.green.shade200, Colors.green.shade700, intensity)!;
                      }

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(1),
                          child: Tooltip(
                            message: km > 0
                                ? '${day.day}.${day.month}: ${km.toStringAsFixed(0)} м'
                                : '${day.day}.${day.month}',
                            child: Container(
                              height: 11,
                              decoration: BoxDecoration(
                                color: cellColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

  Widget _buildLegend() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Меньше', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(width: 4),
        ...List.generate(5, (i) {
          final intensity = i / 4;
          return Container(
            width: 11, height: 11,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: i == 0
                  ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
                  : Color.lerp(Colors.green.shade200, Colors.green.shade700, intensity),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        const SizedBox(width: 4),
        Text('Больше', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildMonthlyStats(Map<DateTime, double> activityMap) {
    final monthNames = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxMonthKm = 500.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Прогресс по месяцам', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...List.generate(12, (m) {
          double km = 0;
          for (final e in activityMap.entries) {
            if (e.key.month == m + 1) km += e.value;
          }
          final progress = (km / 1000 / maxMonthKm).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(width: 30, child: Text(monthNames[m], style: const TextStyle(fontSize: 12, color: Colors.grey))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 14,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        km > 0 ? Colors.green.shade400 : Colors.transparent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: Text(
                    '${(km / 1000).toStringAsFixed(1)} км',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
