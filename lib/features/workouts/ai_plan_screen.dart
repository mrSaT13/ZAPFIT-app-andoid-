import 'package:flutter/material.dart';

import 'package:endurain/core/models/workouts_models.dart';
import 'package:endurain/core/services/workouts_service.dart';
import 'package:endurain/features/workouts/workout_calendar_service.dart';

/// AI weekly plan builder: free-text goal → server generates a multi-day
/// draft → user reviews «программа → недели → дни → упражнения» and saves
/// the plan (optionally scheduling it into the calendar for N weeks).
class AiPlanScreen extends StatefulWidget {
  const AiPlanScreen({super.key});

  @override
  State<AiPlanScreen> createState() => _AiPlanScreenState();
}

class _AiPlanScreenState extends State<AiPlanScreen> {
  final WorkoutsService _service = WorkoutsService.instance;

  final _promptCtrl = TextEditingController();
  final Set<int> _weekdays = {1, 3, 5};
  int _weeks = 4;
  bool _generating = false;
  AiPlanDraft? _draft;

  static const _presets = <String, String>{
    'Масса': 'Программа на набор мышечной массы, базовые упражнения, прогрессия нагрузки',
    'Похудение': 'Программа для похудения: силовые с многоповторными подходами и кардио-акценты',
    'Сила': 'Программа на силу: тяжёлые базовые движения, 5-8 повторов, длинный отдых',
    'Всё тело': 'Программа фулбоди на все мышечные группы, 3 тренировки в неделю',
    'Спина и грудь': 'Программа с акцентом на спину и грудные мышцы',
  };

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  String get _weekdaySummary {
    const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final sorted = _weekdays.toList()..sort();
    return sorted.map((w) => names[w - 1]).join(', ');
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Опишите цель — хотя бы 3 символа'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (_weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Выберите дни недели'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() => _generating = true);
    final enriched =
        '$prompt. Программа на $_weeks недел${_weeks == 1 ? 'ю' : 'и'}, '
        'тренировки ${_weekdays.length} раз${_weekdays.length == 1 ? '' : 'а'} '
        'в неделю ($_weekdaySummary), остальные дни — отдых.';
    final status = await _service.aiStatus();
    if (!mounted) return;
    if (status == null || !status.available) {
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'AI недоступен: сервер не настроен (админ должен включить AI в настройках сервера)'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final draft = await _service.generateAiPlan(enriched);
    if (!mounted) return;
    setState(() {
      _generating = false;
      _draft = draft;
    });
    if (draft == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Не удалось сгенерировать план — попробуйте ещё раз'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _save({required bool schedule}) async {
    final draft = _draft;
    if (draft == null) return;
    final plan = draft.toPlan();
    final created = await _service.createPlan(
      name: plan.name,
      description: plan.description,
      exercises: plan.exercises,
    );
    if (!mounted) return;
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ошибка сохранения плана на сервер'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    var scheduled = 0;
    if (schedule) {
      // created.id нужен для записи в план-расписание
      final withId = WorkoutPlan(
        id: created.id,
        userId: created.userId,
        name: created.name,
        description: created.description,
        source: created.source,
        exercises: created.exercises,
      );
      scheduled = await WorkoutCalendarService.instance.schedulePlanDirect(
        withId,
        weekdays: _weekdays,
        weeks: _weeks,
      );
    }
    if (!mounted) return;
    Navigator.pop(context, created);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(schedule && scheduled > 0
          ? 'План сохранён · запланировано тренировок: $scheduled'
          : 'План «${created.name}» сохранён'),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI-план на недели')),
      body: _draft == null ? _buildForm(theme) : _buildReview(theme),
    );
  }

  // ---- form ----

  Widget _buildForm(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Опишите цель', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        TextField(
          controller: _promptCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Например: накачать грудные и руки, тренажёрный зал 3 раза в неделю',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in _presets.entries)
              ActionChip(
                label: Text(entry.key),
                onPressed: () => setState(() => _promptCtrl.text = entry.value),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Тренировочные дни', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (var i = 1; i <= 7; i++)
              FilterChip(
                label: Text(_weekdayName(i)),
                selected: _weekdays.contains(i),
                onSelected: (v) =>
                    setState(() => v ? _weekdays.add(i) : _weekdays.remove(i)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Дни недели: $_weekdaySummary · остальные дни — отдых',
            style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
        const SizedBox(height: 16),
        Text('Длительность программы', style: theme.textTheme.titleMedium),
        Row(children: [
          Expanded(
            child: Slider(
              value: _weeks.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              label: '$_weeks нед.',
              onChanged: (v) => setState(() => _weeks = v.round()),
            ),
          ),
          SizedBox(
              width: 80,
              child: Text('$_weeks нед.',
                  style: theme.textTheme.titleMedium)),
        ]),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _generating ? null : _generate,
          icon: _generating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_generating ? 'Генерируем…' : 'Сгенерировать план'),
        ),
        const SizedBox(height: 8),
        Text(
          'План создаётся нейросетью на сервере из каталога упражнений. '
          'Перед сохранением вы увидите его целиком и сможете отменить.',
          style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
        ),
      ],
    );
  }

  // ---- review: weeks → days → exercises ----

  Widget _buildReview(ThemeData theme) {
    final plan = _draft!.toPlan();
    final groups = plan.dayGroups();
    final dayLabels = groups.keys.toList();
    final trainingPerWeek = dayLabels.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.primaryContainer.withOpacity(0.35),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (plan.description != null &&
                    plan.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(plan.description!,
                        style: TextStyle(color: theme.colorScheme.outline)),
                  ),
                const SizedBox(height: 6),
                Text(
                    '$_weeks нед. · $trainingPerWeek тренировки/нед '
                    '(${_weekdaySummary}) · '
                    '${plan.exercises.length} упражнений',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var w = 1; w <= _weeks; w++) _weekSection(theme, w, dayLabels, groups),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _draft = null),
              icon: const Icon(Icons.replay),
              label: const Text('Заново'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _save(schedule: false),
              icon: const Icon(Icons.save),
              label: const Text('Сохранить'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => _save(schedule: true),
            icon: const Icon(Icons.event_available),
            label: Text(
                'Сохранить и запланировать ($_weeks нед · $_weekdaySummary)'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '«Запланировать» добавит тренировки в системный календарь '
          '(с напоминаниями) и во вкладку Календарь.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
        ),
      ],
    );
  }

  Widget _weekSection(ThemeData theme, int week, List<String> dayLabels,
      Map<String, List<WorkoutPlanExercise>> groups) {
    // каждая неделя одинаковая по структуре: тренировочные дни по порядку
    // раскладываются на выбранные дни недели, остальные — отдых.
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Неделя $week',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var i = 1; i <= 7; i++)
              _weekDayRow(theme, i, week, dayLabels, groups),
          ],
        ),
      ),
    );
  }

  Widget _weekDayRow(
    ThemeData theme,
    int weekday,
    int week,
    List<String> dayLabels,
    Map<String, List<WorkoutPlanExercise>> groups,
  ) {
    if (!_weekdays.contains(weekday)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 34, child: Text(_weekdayName(weekday),
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 12))),
          Icon(Icons.hotel, size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Text('Отдых',
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 13)),
        ]),
      );
    }
    // i-й тренировочный день недели → i-й день плана (по кругу, если дней меньше)
    final trainingIndex = _weekdays.where((w) => w <= weekday).length - 1;
    final dayLabel =
        dayLabels.isEmpty ? '' : dayLabels[trainingIndex % dayLabels.length];
    final exercises = groups[dayLabel] ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 34, child: Text(_weekdayName(weekday),
              style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayLabel.isEmpty ? 'Тренировка' : dayLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  exercises.map((e) => e.name).join(' · '),
                  style: TextStyle(
                      color: theme.colorScheme.outline, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _weekdayName(int weekday) => switch (weekday) {
        1 => 'Пн', 2 => 'Вт', 3 => 'Ср', 4 => 'Чт',
        5 => 'Пт', 6 => 'Сб', _ => 'Вс',
      };
}
