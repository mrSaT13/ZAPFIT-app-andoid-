import 'package:flutter/material.dart';

import 'package:endurain/core/services/catalog_service.dart';
import 'package:endurain/core/models/workouts_models.dart';
import 'package:endurain/core/services/workouts_service.dart';
import 'package:endurain/features/workouts/log_session_screen.dart';
import 'package:endurain/features/workouts/widgets/exercise_plan_editor_dialog.dart';

/// «Тренировки» — the fifth bottom tab: strength plans from the server
/// (cached for offline) plus the sessions journal with the set-by-set logger.
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen>
    with SingleTickerProviderStateMixin {
  final WorkoutsService _service = WorkoutsService.instance;
  final CatalogService _catalog = CatalogService.instance;

  late final TabController _tabs = TabController(length: 2, vsync: this);

  List<WorkoutPlan> _plans = [];
  List<WorkoutSession> _sessions = [];
  int _pendingCount = 0;
  bool _loading = true;
  bool _catalogLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() {}); // FAB switches between "add plan" (hidden in journal).
    });
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await _catalog.ensureLoaded();
    if (!mounted) return;
    setState(() => _catalogLoading = false);
    await _refreshData();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    _plans = await _service.fetchPlans();
    _sessions = await _service.fetchSessions();
    _pendingCount = await _service.pendingCount();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createPlan() async {
    final saved = await showPlanEditorDialog(context);
    if (saved) await _refreshData();
  }

  Future<void> _editPlan(WorkoutPlan plan) async {
    final saved = await showPlanEditorDialog(context, existing: plan);
    if (saved) await _refreshData();
  }

  Future<void> _deletePlan(WorkoutPlan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить план?'),
        content: Text('"${plan.name}" будет удалён на сервере'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true || plan.id == null) return;
    final deleted = await _service.deletePlan(plan.id!);
    if (mounted && deleted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('План удалён')));
    }
    await _refreshData();
  }

  Future<void> _logSession(WorkoutPlan plan) async {
    if (_catalogLoading) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LogSessionScreen(plan: plan)),
    );
    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировки'),
        actions: [
          if (_pendingCount > 0)
            IconButton(
              tooltip: 'Отправить сохранённые офлайн сессии',
              icon: Badge(label: Text('$_pendingCount'), child: const Icon(Icons.sync)),
              onPressed: () async {
                final n = await _service.syncPending();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(n == 0 ? 'Нет связи — попробуем позже' : 'Отправлено: $n')),
                );
                await _refreshData();
              },
            ),
        ],
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Планы'),
          Tab(text: 'Журнал'),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'workouts_fab',
        onPressed: _tabs.index == 0 ? _createPlan : null,
        child: const Icon(Icons.add),
      ),
      body: _catalogLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Загружаем каталог упражнений…'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [_buildPlansTab(theme), _buildJournalTab(theme)],
            ),
    );
  }

  Widget _buildPlansTab(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 64, color: theme.colorScheme.outline.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Планов пока нет', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Создай план из каталога — жимы, тяги, программы\nи записывай по нему сессии',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _createPlan,
              icon: const Icon(Icons.add),
              label: const Text('Новый план'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final plan in _plans)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') {
                              _editPlan(plan);
                            } else if (v == 'delete') {
                              _deletePlan(plan);
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'edit', child: Text('Изменить')),
                            PopupMenuItem(value: 'delete', child: Text('Удалить')),
                          ],
                        ),
                      ],
                    ),
                    if (plan.description != null && plan.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          plan.description!,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Text(
                      'Упражнений: ${plan.exercises.length}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _editPlan(plan),
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('Просмотр'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _logSession(plan),
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: const Text('Записать сессию'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJournalTab(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: theme.colorScheme.outline.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Сессий пока нет', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Запиши первую сессию по плану —\nпоявится здесь и в графике прогресса на сервере',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final s in _sessions)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: ListTile(
                leading: Icon(Icons.fitness_center, color: theme.colorScheme.primary),
                title: Text(
                  s.date,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _sessionSummary(s),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _sessionSummary(WorkoutSession s) {
    final setCount = s.sets.length;
    final volumeKg =
        s.sets.fold<double>(0, (sum, st) => sum + (st.weightKg ?? 0) * (st.reps ?? 0));
    final exercises = s.sets.map((st) => st.exerciseName).toSet().length;
    return 'Упражнений: $exercises · подходов: $setCount'
        '${volumeKg > 0 ? ' · объём ${volumeKg.toStringAsFixed(0)} кг' : ''}'
        '${s.planId != null ? ' · по плану' : ''}';
  }
}
