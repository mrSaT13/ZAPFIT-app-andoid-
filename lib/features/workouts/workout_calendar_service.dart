import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:endurain/core/models/workouts_models.dart';
import 'package:endurain/core/services/workouts_local_repository.dart';
import 'package:permission_handler/permission_handler.dart';

/// Workout plan scheduling: writes plan entries into the local plan_schedule
/// table AND inserts events directly into the Android system calendar
/// (WRITE_CALENDAR), so the user gets stock calendar notifications.
class WorkoutCalendarService {
  WorkoutCalendarService._();

  static final WorkoutCalendarService instance = WorkoutCalendarService._();

  static const _channel = MethodChannel('com.zapfit/calendar');

  final WorkoutsLocalRepository _local = WorkoutsLocalRepository.instance;

  /// Requests calendar permissions. Returns true when granted.
  Future<bool> ensurePermissions() async {
    final status = await Permission.calendarFullAccess.request();
    if (status.isGranted) return true;
    // Fallback for narrow variants
    final write = await Permission.calendarWriteOnly.request();
    return write.isGranted ||
        (await Permission.calendarFullAccess.status).isGranted;
  }

  /// Opens the schedule dialog for [plan] and, when confirmed, creates
  /// schedule entries + system calendar events. Returns number of created
  /// entries (0 when cancelled / nothing created).
  Future<int> showScheduleDialog(BuildContext context, WorkoutPlan plan) async {
    final theme = Theme.of(context);
    final selected = <int>{1, 3, 5}; // пн, ср, пт
    var start = DateTime.now();
    var weeks = 4;
    var time = const TimeOfDay(hour: 18, minute: 0);
    var reminder = 30;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Запланировать тренировки'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Дни недели:', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var i = 1; i <= 7; i++)
                      FilterChip(
                        label: Text(_weekdayName(i)),
                        selected: selected.contains(i),
                        onSelected: (v) => setDialog(() =>
                            v ? selected.add(i) : selected.remove(i)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Дата старта'),
                      subtitle: Text(_fmtDate(start)),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: start,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setDialog(() => start = d);
                      },
                    ),
                  ),
                ]),
                Row(children: [
                  const Text('Время:'),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: time);
                      if (t != null) setDialog(() => time = t);
                    },
                    child: Text(time.format(ctx)),
                  ),
                ]),
                Row(children: [
                  const Text('Напоминание:'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: reminder,
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('за 10 мин')),
                      DropdownMenuItem(value: 30, child: Text('за 30 мин')),
                      DropdownMenuItem(value: 60, child: Text('за 1 час')),
                      DropdownMenuItem(value: 0, child: Text('без напоминания')),
                    ],
                    onChanged: (v) => setDialog(() => reminder = v ?? 30),
                  ),
                ]),
                Row(children: [
                  const Text('Недель:'),
                  Expanded(
                    child: Slider(
                      value: weeks.toDouble(),
                      min: 1,
                      max: 12,
                      divisions: 11,
                      label: '$weeks',
                      onChanged: (v) => setDialog(() => weeks = v.round()),
                    ),
                  ),
                  Text('$weeks', style: theme.textTheme.titleMedium),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Запланировать'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return 0;
    return schedulePlanDirect(plan,
        weekdays: selected, weeks: weeks, time: time, reminderMinutes: reminder);
  }

  /// Schedules [plan] on the given weekdays for N weeks straight into the
  /// local schedule table + the system calendar (no dialog).
  Future<int> schedulePlanDirect(
    WorkoutPlan plan, {
    required Set<int> weekdays,
    required int weeks,
    TimeOfDay time = const TimeOfDay(hour: 18, minute: 0),
    int reminderMinutes = 30,
  }) async {
    final start = DateTime.now();
    var created = 0;
    for (var w = 0; w < weeks; w++) {
      for (final weekday in weekdays) {
        // первая неделя может начаться не с понедельника: пропускаем прошлое
        var date = start;
        var daysAhead = (weekday - date.weekday) % 7;
        if (daysAhead < 0) daysAhead += 7;
        date = date.add(Duration(days: daysAhead + w * 7));
        await _createEntry(plan, date, time, reminderMinutes);
        created++;
      }
    }
    return created;
  }

  Future<void> _createEntry(
    WorkoutPlan plan,
    DateTime date,
    TimeOfDay time,
    int reminder,
  ) async {
    final begin =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final end = begin.add(const Duration(hours: 1));

    var eventId = -1;
    try {
      eventId = await _channel.invokeMethod<int>('insertEvent', {
        'title': 'Тренировка: ${plan.name}',
        'description': 'ZAPFIT · план «${plan.name}»',
        'beginMs': begin.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
        'reminderMinutes': reminder,
      }) ?? -1;
    } catch (e) {
      debugPrint('WorkoutCalendarService: insertEvent error: $e');
    }
    if (eventId == -1) {
      // нет разрешения — запросим и попробуем ещё раз один раз
      if (await ensurePermissions()) {
        try {
          eventId = await _channel.invokeMethod<int>('insertEvent', {
            'title': 'Тренировка: ${plan.name}',
            'description': 'ZAPFIT · план «${plan.name}»',
            'beginMs': begin.millisecondsSinceEpoch,
            'endMs': end.millisecondsSinceEpoch,
            'reminderMinutes': reminder,
          }) ?? -1;
        } catch (e) {
          debugPrint('WorkoutCalendarService: retry insertEvent error: $e');
        }
      }
    }
    await _local.addScheduleEntry(
      planId: plan.id,
      planName: plan.name,
      date: date,
      calendarEventId: eventId > 0 ? eventId : null,
    );
  }

  /// Deletes a schedule entry and its system calendar event.
  Future<void> deleteEntry(Map<String, dynamic> entry) async {
    final eventId = entry['calendar_event_id'] as int?;
    if (eventId != null && eventId > 0) {
      try {
        await _channel.invokeMethod('deleteEvent', {'eventId': eventId});
      } catch (e) {
        debugPrint('WorkoutCalendarService: deleteEvent error: $e');
      }
    }
    await _local.removeScheduleEntry(entry['id'] as int);
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _weekdayName(int weekday) => switch (weekday) {
        1 => 'Пн', 2 => 'Вт', 3 => 'Ср', 4 => 'Чт',
        5 => 'Пт', 6 => 'Сб', _ => 'Вс',
      };
}
