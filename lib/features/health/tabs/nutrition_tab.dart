import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:endurain/core/models/nutrition_models.dart';
import 'package:endurain/core/services/app_settings_controller.dart';
import 'package:endurain/core/services/nutrition_service.dart';
import 'package:endurain/core/utils/tdee_calculator.dart';
import 'package:endurain/features/health/widgets/nutrition_meal_dialog.dart';

/// Half-window of the journal pulled from the server on each reload
/// (± days around the selected date).
const int _windowDays = 15;

/// Meal types served by the diary (server `meal_type` values).
const List<(String, String, IconData)> _mealTypes = [
  ('breakfast', 'Завтрак', Icons.free_breakfast_outlined),
  ('lunch', 'Обед', Icons.lunch_dining_outlined),
  ('dinner', 'Ужин', Icons.dinner_dining_outlined),
  ('snack', 'Перекус', Icons.apple_outlined),
];

class NutritionTab extends StatefulWidget {
  const NutritionTab({super.key});

  @override
  State<NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends State<NutritionTab> {
  final NutritionService _service = NutritionService.instance;

  DateTime _selectedDate = _today();
  List<MealLog> _logs = const [];
  NutritionSummary? _summary;
  int _pending = 0;
  bool _loading = true;

  ActivityLevel? _activityLevel;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// Pushes the offline queue, pulls the journal window (centered on the
  /// selected date), aggregates the day.
  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      _pending = await _service.syncPending();
    } catch (e) {
      debugPrint('NutritionTab: syncPending error: $e');
    }
    final dateTo = _fmt(_selectedDate.add(const Duration(days: _windowDays)));
    final dateFrom =
        _fmt(_selectedDate.subtract(const Duration(days: _windowDays)));
    List<MealLog> logs;
    try {
      logs = await _service.fetchLogs(dateFrom: dateFrom, dateTo: dateTo);
    } catch (e) {
      debugPrint('NutritionTab: fetchLogs error: $e');
      logs = const [];
    }
    if (!mounted) return;
    setState(() {
      _logs = logs;
    });
    await _reloadSummary();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reloadSummary() async {
    final date = _fmt(_selectedDate);
    final server = await _service.fetchSummary(date);
    // Intake for the day falls back to the local cache when unreachable.
    final local = server ?? await _service.localSummary(date);
    if (!mounted) return;
    setState(() => _summary = local);
  }

  void _changeDay(int days) {
    final target = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day + days,
    );
    final windowStart =
        _selectedDate.subtract(const Duration(days: _windowDays));
    if (target.isBefore(windowStart) ||
        target.isAfter(_selectedDate.add(const Duration(days: _windowDays)))) {
      // Outside the cached journal window — full reload around the new date.
      setState(() {
        _selectedDate = target;
        _summary = null;
      });
      unawaited(_reload());
      return;
    }
    setState(() {
      _selectedDate = target;
      _summary = null;
    });
    unawaited(_reloadSummary());
  }

  List<MealLog> _logsFor(String mealType) {
    final date = _fmt(_selectedDate);
    return [
      for (final log in _logs)
        if (log.mealType == mealType && log.date == date) log,
    ];
  }

  double _totalKcal(List<MealLog> logs) {
    var sum = 0.0;
    for (final log in logs) {
      sum += log.calories ?? 0;
    }
    return sum;
  }

  Future<void> _openAddDialog(String mealType, String mealTitle) async {
    final result = await showNutritionMealDialog(
      context,
      date: _fmt(_selectedDate),
      mealType: mealType,
      mealTitle: mealTitle,
    );
    if (result == null || !mounted) return;
    final created = await _service.addLog(result);
    if (!mounted) return;
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сервер отклонил запись — проверьте поля'),
        ),
      );
      return;
    }
    if (created.synced == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сохранено локально — отправится при синхронизации'),
        ),
      );
    }
    await _reload();
  }

  Future<void> _openEditDialog(MealLog log, String mealTitle) async {
    final result = await showNutritionMealDialog(
      context,
      date: log.date,
      mealType: log.mealType,
      mealTitle: mealTitle,
      existing: log,
    );
    if (result == null || !mounted) return;
    final updated = await _service.updateLog(
      log.copyWith(
        productName: result.productName,
        calories: result.calories,
        protein: result.protein,
        carbs: result.carbs,
        fat: result.fat,
        portionG: result.portionG,
        offBarcode: result.offBarcode,
      ),
    );
    if (!mounted) return;
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить запись')),
      );
      return;
    }
    await _reload();
  }

  Future<void> _confirmDelete(MealLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text('"${log.productName}" будет удалена из дневника.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final removed = await _service.removeLog(log);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? 'Запись удалена'
              : 'Удаление сохранено локально — отправится при синке',
        ),
      ),
    );
    await _reload();
  }

  String _dateTitle(DateTime d) {
    final today = _today();
    if (d == today) return 'Сегодня';
    if (d == today.subtract(const Duration(days: 1))) return 'Вчера';
    if (d == today.add(const Duration(days: 1))) return 'Завтра';
    return DateFormat('dd.MM.yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsController.instance;

    final weightKg = settings.userWeight;
    final heightCm = settings.userHeight;
    final age = settings.userAge;
    final gender = settings.userGender.toLowerCase() == 'male' ? 1 : 0;

    final hasBase = weightKg > 0 && heightCm > 0 && age != null && age > 0;
    final canCompute = hasBase && _activityLevel != null;

    TdeeResult? tdee;
    if (canCompute) {
      tdee = TdeeCalculator.calculate(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        gender: gender,
        activityLevel: _activityLevel!,
      );
    }
    final macros = tdee?.maintenanceMacros;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Питание',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(context),
            const SizedBox(height: 16),
            _buildDateNav(context),
            const SizedBox(height: 12),
            if (_pending > 0) _buildOfflineBar(context),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final (mealType, mealTitle, icon) in _mealTypes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildMealSection(context, mealType, mealTitle, icon),
                ),
            if (!hasBase)
              _buildNoDataCard(
                context,
                'Рассчёт TDEE недоступен',
                'Для расчёта укажите рост, вес и дату рождения в профиле.',
              )
            else ...[
              _buildActivitySelector(context),
              const SizedBox(height: 16),
              if (tdee == null)
                _buildNoDataCard(
                  context,
                  'Нет данных',
                  'Выберите уровень активности для расчёта TDEE.',
                )
              else ...[
                _buildTdeeCard(context, tdee),
                const SizedBox(height: 16),
                if (macros != null) ...[
                  _buildMacroCard(context, macros),
                  const SizedBox(height: 16),
                ],
                _buildCalorieBalanceCard(context, tdee, _summary),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ==== diary summary ====

  Widget _buildSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _summary;
    final burned = summary?.burnedCalories;
    final net = summary?.netCalories;
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
                const Icon(
                  Icons.local_dining_outlined,
                  color: Colors.deepOrange,
                ),
                const SizedBox(width: 8),
                Text('Итог дня', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (summary == null)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_pending > 0)
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  summary == null
                      ? '—'
                      : summary.intakeCalories.round().toString(),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'ккал съедено',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              children: [
                _macroChip('Б', summary?.intakeProtein, Colors.green),
                _macroChip('У', summary?.intakeCarbs, Colors.blue),
                _macroChip('Ж', summary?.intakeFat, Colors.orange),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Сожжено за день',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  burned == null ? '— ккал' : '${_numText(burned)} ккал',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text('Баланс', style: theme.textTheme.bodyMedium),
                ),
                Text(
                  net == null
                      ? '— ккал'
                      : '${net >= 0 ? '+' : ''}${_numText(net)} ккал',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              burned == null
                  ? 'Цифры за день. «Сожжено» приходит с сервера (активности + базовый обмен); без сети показан только приём.'
                  : 'Сожжено = активности за день + базовый обмен (считает сервер).',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroChip(String label, double? grams, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label ${grams == null ? '—' : _numText(grams)} г',
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  String _numText(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  // ==== date navigation ====

  Widget _buildDateNav(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Предыдущий день',
          onPressed: () => _changeDay(-1),
        ),
        Expanded(
          child: Text(
            '${_dateTitle(_selectedDate)}, ${DateFormat('d MMMM', 'ru').format(_selectedDate)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Следующий день',
          onPressed: () => _changeDay(1),
        ),
      ],
    );
  }

  Widget _buildOfflineBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 16,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_pending записей сохранены локально — отправятся при синхронизации.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  // ==== meal sections ====

  Widget _buildMealSection(
    BuildContext context,
    String mealType,
    String mealTitle,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final logs = _logsFor(mealType);
    final total = _totalKcal(logs);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  mealTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (logs.isNotEmpty)
                  Text(
                    '${total.round()} ккал',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                IconButton(
                  tooltip: 'Добавить — $mealTitle',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _openAddDialog(mealType, mealTitle),
                ),
              ],
            ),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ничего нет',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              )
            else
              for (final log in logs) _buildLogTile(context, log, mealTitle),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTile(BuildContext context, MealLog log, String mealTitle) {
    final theme = Theme.of(context);
    final protein = log.protein;
    final carbs = log.carbs;
    final fat = log.fat;
    final kcalText =
        log.calories == null ? '—' : '${_numText(log.calories!)} ккал';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        log.productName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Row(
        children: [
          Text(
            log.portionG != null ? '${_numText(log.portionG!)} г · ' : '',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
          Text(
            kcalText,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
          if (protein != null || carbs != null || fat != null) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                [
                  if (protein != null) 'Б ${_numText(protein)}',
                  if (carbs != null) 'У ${_numText(carbs)}',
                  if (fat != null) 'Ж ${_numText(fat)}',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
          if (log.synced == false) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.cloud_off_outlined,
              size: 14,
              color: theme.colorScheme.outline,
            ),
          ],
        ],
      ),
      isThreeLine: false,
      onTap: () => _openEditDialog(log, mealTitle),
      trailing: IconButton(
        tooltip: 'Удалить',
        icon: const Icon(Icons.close),
        onPressed: () => _confirmDelete(log),
      ),
    );
  }

  // ==== TDEE section below (existing ZAPFIT metrics) ====

  Widget _buildActivitySelector(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Норма калорий (TDEE)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ActivityLevel.values.map((level) {
                final selected = _activityLevel == level;
                return ChoiceChip(
                  label: Text(TdeeCalculator.activityLevelLabel(level)),
                  selected: selected,
                  onSelected: (v) =>
                      setState(() => _activityLevel = v ? level : null),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTdeeCard(BuildContext context, TdeeResult tdee) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_outlined,
                  color: Colors.deepOrange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Суточный расход (TDEE)',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${tdee.tdee.round()}',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ккал/день',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Активность: ${tdee.activityLabel} (${tdee.activityDescription})',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'BMR (средн.): ${tdee.bmrAvg.round()} ккал',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCard(BuildContext context, MacroBreakdown macros) {
    final theme = Theme.of(context);
    final rows = [
      ('Белки', macros.proteinGrams, macros.proteinCal, Colors.green),
      ('Жиры', macros.fatGrams, macros.fatCal, Colors.orange),
      ('Углеводы', macros.carbGrams, macros.carbCal, Colors.blue),
    ];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_menu_outlined, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Макронутриенты (норма)',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: r.$4,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r.$1, style: const TextStyle(fontSize: 15)),
                    ),
                    Text(
                      '${r.$2.round()} г',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${r.$3.round()} ккал',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Всего',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${macros.totalCal.round()} ккал',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieBalanceCard(
    BuildContext context,
    TdeeResult tdee,
    NutritionSummary? summary,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.balance_outlined, color: Colors.purple),
                const SizedBox(width: 8),
                Text('Калорийный баланс', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _balanceRow('Расход (TDEE):', '${tdee.tdee.round()} ккал'),
            _balanceRow(
              'Потребление:',
              summary == null || summary.intakeCalories <= 0
                  ? '— ккал'
                  : '${summary.intakeCalories.round()} ккал',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Норма показана как ориентир: TDEE считается на этой вкладке, фактический расход — в карточке «Итог дня».',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataCard(BuildContext context, String title, String subtitle) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
