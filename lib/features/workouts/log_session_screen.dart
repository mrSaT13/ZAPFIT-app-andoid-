import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:endurain/core/models/catalog_models.dart';
import 'package:endurain/core/models/workouts_models.dart';
import 'package:endurain/core/services/catalog_service.dart';
import 'package:endurain/core/services/workouts_service.dart';

/// Set-by-set session logging screen — entry from a plan card («Записать»).
///
/// Mirrors the web's SessionDialog: for each plan exercise a set table with
/// weight/reps inputs; «Готово» posts the session to the server (or queues it
/// offline through the sync flow).
class LogSessionScreen extends StatefulWidget {
  const LogSessionScreen({super.key, required this.plan});

  final WorkoutPlan plan;

  @override
  State<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends State<LogSessionScreen> {
  final CatalogService _catalog = CatalogService.instance;
  final WorkoutsService _service = WorkoutsService.instance;

  late final List<_ExerciseState> _exercises;
  bool _saving = false;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    _exercises = [
      for (final ex in widget.plan.exercises)
        _ExerciseState(
          name: ex.name,
          wgerId: ex.wgerExerciseId ?? _resolveIdByName(ex.name),
          defaultWeight: ex.targetWeightKg,
          sets: [
            for (var s = 0; s < (ex.targetSets ?? 3); s++)
              if (ex.wgerExerciseId != null)
                _SetInput(
                  weight: ex.targetWeightKg,
                  reps: int.tryParse(ex.targetReps ?? ''),
                ),
          ],
        ),
    ];
  }

  int? _resolveIdByName(String name) {
    final byName = _catalog.search(query: name, limit: 1);
    return byName.isNotEmpty ? byName.first.id : null;
  }

  Future<void> _finish() async {
    setState(() {
      _saving = true;
      _resultMessage = null;
    });
    bool anySet = _exercises.any((e) => e.sets.any((s) => s.weight != null || s.reps != null));
    if (!anySet) {
      setState(() {
        _saving = false;
        _resultMessage = 'Отметьте хотя бы один подход (вес или повторы)';
      });
      return;
    }
    final today = DateTime.now();
    final sets = <WorkoutSetLog>[];
    for (final ex in _exercises) {
      var setNo = 1;
      for (final s in ex.sets) {
        if (s.weight == null && s.reps == null) continue;
        sets.add(WorkoutSetLog(
          exerciseName: ex.name,
          wgerExerciseId: ex.wgerId,
          setNo: setNo++,
          weightKg: s.weight,
          reps: s.reps,
          completed: true,
        ));
      }
    }
    final session = WorkoutSession(
      planId: widget.plan.id,
      date: '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
      sets: sets,
    );
    final saved = await _service.logSession(session);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _resultMessage = saved == null ? 'Сохранено локально — отправится при следующей связи' : 'Сессия сохранена';
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Записать: ${widget.plan.name}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _exercises.length,
        itemBuilder: (ctx, i) {
          final ex = _exercises[i];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (ex.tip != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        ex.tip!,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                  ...[
                    for (var s = 0; s < ex.sets.length; s++) _setRow(ex, s, theme),
                  ],
                  TextButton.icon(
                    onPressed: () => setState(() => ex.sets.add(
                          _SetInput(weight: ex.defaultWeight),
                        )),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Добавить подход'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_resultMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_resultMessage!, style: theme.textTheme.bodyMedium),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _finish,
                  icon: const Icon(Icons.check),
                  label: const Text('Готово'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _setRow(_ExerciseState ex, int index, ThemeData theme) {
    final set = ex.sets[index];
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primaryContainer,
          ),
          child: Text('${index + 1}', style: theme.textTheme.labelMedium),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            initialValue: set.weight == null ? '' : set.weight.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(labelText: 'вес, кг', isDense: true, border: OutlineInputBorder()),
            onChanged: (v) => set.weight = double.tryParse(v.replaceAll(',', '.')),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: set.reps == null ? '' : set.reps.toString(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'повторы', isDense: true, border: OutlineInputBorder()),
            onChanged: (v) => set.reps = int.tryParse(v),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          onPressed: () => setState(() => ex.sets.removeAt(index)),
        ),
      ],
    );
  }
}

class _ExerciseState {
  final String name;
  final int? wgerId;
  final double? defaultWeight;
  final List<_SetInput> sets;

  _ExerciseState({
    required this.name,
    this.wgerId,
    this.defaultWeight,
    required this.sets,
  });

  String? get tip => CatalogService.instance.byId(wgerId ?? 0)?.firstTip(RussianOrEnglish.ru);
}

class _SetInput {
  double? weight;
  int? reps;

  _SetInput({this.weight, this.reps});
}
