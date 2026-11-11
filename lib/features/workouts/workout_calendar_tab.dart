import 'package:flutter/material.dart';

import 'package:endurain/core/services/workouts_local_repository.dart';
import 'package:endurain/core/services/catalog_service.dart';
import 'package:endurain/core/models/workouts_models.dart';
import 'package:endurain/features/workouts/live_session_screen.dart';
import 'package:endurain/features/workouts/workout_calendar_service.dart';

/// «Календарь» tab in Workouts: monthly grid with dots (blue = scheduled
/// plan, green = completed session), a "next workout" card on top with a
/// Start button, and a per-day entry list with deletion.
class WorkoutCalendarTab extends StatefulWidget {
  const WorkoutCalendarTab({super.key, required this.plans});

  final List<WorkoutPlan> plans;

  @override
  State<WorkoutCalendarTab> createState() => _WorkoutCalendarTabState();
}

class _WorkoutCalendarTabState extends State<WorkoutCalendarTab> {
  final WorkoutsLocalRepository _local = WorkoutsLocalRepository.instance;
  final WorkoutCalendarService _calendar = WorkoutCalendarService.instance;

  DateTime _month = DateTime.now();
  List<Map<String, dynamic>> _schedule = [];
  Set<String> _sessionDates = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final first = DateTime(_month.year, _month.month, 1);
    final last = DateTime(_month.year, _month.month + 1, 0);
    try {
      final rows = await _local.listSchedule(
        dateFrom: _fmt(first),
        dateTo: _fmt(last),
      );
      // выполненные сессии — все времена, не только текущего месяца
      final sessions = await _local.listSessions();
      setState(() {
        _schedule = rows;
        _sessionDates = sessions.map((s) => s.date).toSet();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtHuman(String iso) {
    final parts = iso.split('-');
    const months = ['', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${int.parse(parts[2])} ${months[int.parse(parts[1])]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _nextWorkoutCard(theme),
          const SizedBox(height: 12),
          _monthHeader(theme),
          _grid(theme),
          const SizedBox(height: 8),
          _dayList(theme),
        ],
      ),
    );
  }

  // ---- next workout card ----

  Widget _nextWorkoutCard(ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _local.nextScheduled(),
      builder: (ctx, snap) {
        final next = snap.data;
        if (next == null) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.event_available,
                    color: theme.colorScheme.outline, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Тренировки не запланированы.\nОткройте план → «Запланировать».',
                    style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
                  ),
                ),
              ]),
            ),
          );
        }
        final planName = next['plan_name'] as String? ?? '';
        final date = next['date'] as String? ?? '';
        final planId = next['plan_id'] as int?;
        final plan = widget.plans
            .where((p) => p.id != null && p.id == planId)
            .cast<WorkoutPlan?>()
            .firstWhere((_) => true, orElse: () => null);
        return Card(
          elevation: 0,
          color: theme.colorScheme.primaryContainer.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.event,
                  color: theme.colorScheme.primary, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(planName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Следующая тренировка · ${_fmtHuman(date)}',
                        style: TextStyle(
                            color: theme.colorScheme.outline, fontSize: 12)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: plan == null ? null : () => _start(plan),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Начать'),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _start(WorkoutPlan plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LiveSessionScreen(plan: plan)),
    );
    await _load();
  }

  // ---- month grid ----

  Widget _monthHeader(ThemeData theme) {
    const months = ['', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
        'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: () => setState(() {
          _month = DateTime(_month.year, _month.month - 1, 1);
          _load();
        }),
      ),
      Expanded(
        child: Text(
          '${months[_month.month]} ${_month.year}',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: () => setState(() {
          _month = DateTime(_month.year, _month.month + 1, 1);
          _load();
        }),
      ),
    ]);
  }

  Widget _grid(ThemeData theme) {
    final today = DateTime.now();
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // пн = 0
    final firstWeekday = (first.weekday - 1) % 7;
    final cells = <int?>[
      for (var i = 0; i < firstWeekday; i++) null,
      for (var d = 1; d <= daysInMonth; d++) d,
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        child: Column(children: [
          Row(children: [
            for (final wd in ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'])
              Expanded(
                child: Center(
                  child: Text(wd,
                      style: TextStyle(
                          fontSize: 11, color: theme.colorScheme.outline)),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          ...[
            for (var row = 0; row < cells.length / 7; row++)
              Row(children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _dayCell(
                      theme,
                      cells[row * 7 + col],
                      today,
                    ),
                  ),
              ]),
          ],
        ]),
      ),
    );
  }

  Widget _dayCell(ThemeData theme, int? day, DateTime today) {
    if (day == null) return const AspectRatio(aspectRatio: 1, child: SizedBox());
    final iso = _fmt(DateTime(_month.year, _month.month, day));
    final isToday = today.year == _month.year &&
        today.month == _month.month &&
        today.day == day;
    final scheduled =
        _schedule.any((e) => e['date'] == iso);
    final done = _sessionDates.contains(iso);

    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: GestureDetector(
          onTap: () => _selectDay(iso),
          child: Container(
            decoration: BoxDecoration(
              color: scheduled
                  ? theme.colorScheme.primaryContainer.withOpacity(0.6)
                  : isToday
                      ? theme.colorScheme.surfaceContainerHighest
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.bold : null,
                    )),
                const SizedBox(height: 2),
                if (scheduled || done)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (scheduled)
                        Icon(Icons.circle,
                            size: 6, color: theme.colorScheme.primary),
                      if (scheduled && done) const SizedBox(width: 2),
                      if (done)
                        const Icon(Icons.check_circle, size: 6, color: Colors.green),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _selectedDay;

  void _selectDay(String iso) {
    setState(() => _selectedDay = _selectedDay == iso ? null : iso);
  }

  // ---- day entries ----

  Widget _dayList(ThemeData theme) {
    final iso = _selectedDay ?? _fmt(DateTime.now());
    final entries =
        _schedule.where((e) => e['date'] == iso).toList();
    final doneHere = _sessionDates.contains(iso);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_fmtHuman(iso)}${_selectedDay == null ? ' (сегодня)' : ''}'
            '${doneHere ? ' · выполнено' : ''}',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Text('Нет запланированных тренировок на этот день',
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 13))
        else
          ...[
            for (final e in entries)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.fitness_center),
                  title: Text(e['plan_name'] as String? ?? ''),
                  trailing: IconButton(
                    tooltip: 'Удалить запись',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      await _calendar.deleteEntry(e);
                      setState(() => _selectedDay = iso);
                      await _load();
                    },
                  ),
                ),
              ),
          ],
      ],
    );
  }
}
