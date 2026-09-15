import 'package:flutter/material.dart';
import 'package:zapfit/core/services/goals_service.dart';
import 'package:zapfit/core/utils/riegel_predictor.dart';
import 'package:zapfit/core/utils/vdot_calculator.dart';

class GoalsTab extends StatefulWidget {
  const GoalsTab({super.key});

  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<GoalsTab> {
  final GoalsService _goalsService = GoalsService.instance;
  List<ServerGoal> _goals = [];
  List<GoalProgress> _progress = [];
  bool _loading = true;

  // === ZAPFIT metrics ===
  final TextEditingController _raceTimeCtrl = TextEditingController();
  String _knownDistanceKey = '5 км';
  Map<String, double>? _predictions;
  double? _vdot;
  Map<String, double>? _trainingPaces;
  // === ZAPFIT metrics end ===

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() => _loading = true);
    try {
      final goals = await _goalsService.fetchGoals();
      final progress = await _goalsService.fetchGoalsProgress();
      if (mounted) setState(() { _goals = goals; _progress = progress; _loading = false; });
    } catch (e) {
      debugPrint('_loadGoals error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateGoals() async {
    try {
      final generated = await _goalsService.autoGenerateGoals();
      if (mounted) {
        await _loadGoals();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Создано ${generated.length} целей')),
        );
      }
    } catch (e) {
      debugPrint('_generateGoals error: $e');
    }
  }

  Future<void> _showCreateGoalDialog() async {
    String interval = 'weekly';
    String activityType = 'run';
    String goalType = 'distance';
    final distanceCtrl = TextEditingController();
    final countCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Новая цель'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: interval,
                  decoration: const InputDecoration(labelText: 'Период'),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Ежедневно')),
                    DropdownMenuItem(value: 'weekly', child: Text('Еженедельно')),
                    DropdownMenuItem(value: 'monthly', child: Text('Ежемесячно')),
                  ],
                  onChanged: (v) => setDialogState(() => interval = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: activityType,
                  decoration: const InputDecoration(labelText: 'Активность'),
                  items: const [
                    DropdownMenuItem(value: 'run', child: Text('Бег')),
                    DropdownMenuItem(value: 'bike', child: Text('Велосипед')),
                    DropdownMenuItem(value: 'swim', child: Text('Плавание')),
                    DropdownMenuItem(value: 'walk', child: Text('Ходьба')),
                    DropdownMenuItem(value: 'strength', child: Text('Силовая')),
                    DropdownMenuItem(value: 'cardio', child: Text('Кардио')),
                  ],
                  onChanged: (v) => setDialogState(() => activityType = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: goalType,
                  decoration: const InputDecoration(labelText: 'Тип цели'),
                  items: const [
                    DropdownMenuItem(value: 'distance', child: Text('Дистанция')),
                    DropdownMenuItem(value: 'activities', child: Text('Количество тренировок')),
                    DropdownMenuItem(value: 'duration', child: Text('Время')),
                    DropdownMenuItem(value: 'calories', child: Text('Калории')),
                  ],
                  onChanged: (v) => setDialogState(() => goalType = v!),
                ),
                const SizedBox(height: 8),
                if (goalType == 'distance')
                  TextField(controller: distanceCtrl, decoration: const InputDecoration(labelText: 'Дистанция (км)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                if (goalType == 'activities')
                  TextField(controller: countCtrl, decoration: const InputDecoration(labelText: 'Количество тренировок', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                if (goalType == 'duration')
                  TextField(controller: distanceCtrl, decoration: const InputDecoration(labelText: 'Время (часы)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                if (goalType == 'calories')
                  TextField(controller: countCtrl, decoration: const InputDecoration(labelText: 'Калории (ккал)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
          ],
        ),
      ),
    );

    if (result == true) {
      int? goalDistance;
      int? goalActivitiesNumber;
      int? goalDuration;
      int? goalCalories;

      switch (goalType) {
        case 'distance':
          goalDistance = ((double.tryParse(distanceCtrl.text) ?? 0) * 1000).toInt();
          break;
        case 'activities':
          goalActivitiesNumber = int.tryParse(countCtrl.text);
          break;
        case 'duration':
          goalDuration = ((double.tryParse(distanceCtrl.text) ?? 0) * 3600).toInt();
          break;
        case 'calories':
          goalCalories = int.tryParse(countCtrl.text);
          break;
      }

      await _goalsService.createGoal(
        interval: interval,
        activityType: activityType,
        goalType: goalType,
        goalDistance: goalDistance,
        goalActivitiesNumber: goalActivitiesNumber,
        goalDuration: goalDuration,
        goalCalories: goalCalories,
      );
      _loadGoals();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: _goals.isEmpty ? _buildEmptyState(theme) : _buildGoalsList(theme),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'generate_goals',
            onPressed: _generateGoals,
            child: const Icon(Icons.auto_awesome, size: 20),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'add_goal',
            onPressed: _showCreateGoalDialog,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, size: 64, color: theme.colorScheme.outline.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('Нет целей', style: TextStyle(color: theme.colorScheme.outline, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Создайте цель вручную или сгенерируйте автоматически',
               textAlign: TextAlign.center,
               style: TextStyle(color: theme.colorScheme.outline.withOpacity(0.6), fontSize: 13)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _generateGoals,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Сгенерировать цели'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsList(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader(theme, 'Мои цели'),
        ..._goals.map((g) => _buildGoalCard(theme, g)),
        if (_progress.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Прогресс'),
          ..._progress.map((p) => _buildProgressCard(theme, p)),
        ],
        // === ZAPFIT metrics ===
        const SizedBox(height: 16),
        _sectionHeader(theme, 'Прогноз гонки'),
        _buildRacePredictorSection(theme),
        // === ZAPFIT metrics end ===
      ],
    );
  }

  Widget _buildGoalCard(ThemeData theme, ServerGoal goal) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(Icons.flag, color: _intervalColor(goal.interval)),
        title: Text(goal.targetDisplay, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${goal.activityTypeLabel} • ${goal.goalTypeLabel} • ${goal.intervalLabel}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Удалить цель?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
                ],
              ),
            );
            if (confirm == true) {
              await _goalsService.deleteGoal(goal.id);
              _loadGoals();
            }
          },
        ),
      ),
    );
  }

  Widget _buildProgressCard(ThemeData theme, GoalProgress p) {
    final pct = p.percentageCompleted ?? 0;
    final color = pct >= 100 ? Colors.green : pct >= 70 ? Colors.orange : theme.colorScheme.primary;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(pct >= 100 ? Icons.check_circle : Icons.trending_up, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${_activityLabel(p.activityType)} • ${_intervalLabel(p.interval)}',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
                Text('$pct%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.outlineVariant.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(p.progressDisplay, style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  // === ZAPFIT metrics ===
  double? _parseRaceTime(String text) {
    final parts = text.trim().split(':').map((p) => int.tryParse(p) ?? -1).toList();
    if (parts.any((p) => p < 0)) return null;
    if (parts.length == 2) return (parts[0] * 60 + parts[1]).toDouble();
    if (parts.length == 3) return (parts[0] * 3600 + parts[1] * 60 + parts[2]).toDouble();
    return null;
  }

  void _computePredictions() {
    final knownMeters = RiegelPredictor.standardDistances[_knownDistanceKey]!;
    final time = _parseRaceTime(_raceTimeCtrl.text);
    if (time == null || time <= 0) {
      setState(() {
        _predictions = null;
        _vdot = null;
        _trainingPaces = null;
      });
      return;
    }
    setState(() {
      _predictions = RiegelPredictor.predictAll(
        timeSeconds: time,
        knownDistanceMeters: knownMeters,
      );
      _vdot = VdotCalculator.estimateVdot(
        timeSeconds: time,
        distanceMeters: knownMeters,
      );
      _trainingPaces = _vdot != null && _vdot! > 0
          ? VdotCalculator.trainingPaces(_vdot!)
          : null;
    });
  }

  Widget _buildRacePredictorSection(ThemeData theme) {
    final distanceItems = RiegelPredictor.standardDistances.keys
        .map((k) => DropdownMenuItem(value: k, child: Text(k)))
        .toList();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
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
                Icon(Icons.timer_outlined, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Прогноз результата (Riegel + VDOT)',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _knownDistanceKey,
                    decoration: const InputDecoration(labelText: 'Известная дистанция', border: OutlineInputBorder()),
                    items: distanceItems,
                    onChanged: (v) => setState(() => _knownDistanceKey = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _raceTimeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Время (ММ:СС или Ч:ММ:СС)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.datetime,
                    onChanged: (_) => _computePredictions(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_predictions != null) ...[
              Text('Прогноз времён:',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 4),
              ..._predictions!.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key),
                        Text(RiegelPredictor.formatTime(e.value),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              if (_vdot != null && _vdot! > 0) ...[
                Text('VDOT: ${_vdot!.toStringAsFixed(1)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Тренировочные темпы (мин/км):',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                ...(_trainingPaces ?? {}).entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key),
                          Text(VdotCalculator.formatPace(e.value),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
              ],
            ] else
              const Text('Введите время известной дистанции для расчёта.',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
  // === ZAPFIT metrics end ===

  String _activityLabel(String type) {
    switch (type) {
      case 'run': return 'Бег';
      case 'bike': return 'Велосипед';
      case 'swim': return 'Плавание';
      case 'walk': return 'Ходьба';
      case 'strength': return 'Силовая';
      case 'cardio': return 'Кардио';
      default: return type;
    }
  }

  String _intervalLabel(String interval) {
    switch (interval) {
      case 'daily': return 'Ежедневно';
      case 'weekly': return 'Еженедельно';
      case 'monthly': return 'Ежемесячно';
      case 'yearly': return 'Ежегодно';
      default: return interval;
    }
  }

  Color _intervalColor(String interval) {
    switch (interval) {
      case 'daily': return Colors.orange;
      case 'weekly': return Colors.blue;
      case 'monthly': return Colors.purple;
      case 'yearly': return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.outline, letterSpacing: 1.2)),
    );
  }
}
