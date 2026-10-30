import 'package:flutter/material.dart';

import 'package:endurain/core/models/catalog_models.dart';
import 'package:endurain/core/models/workouts_models.dart';
import 'package:endurain/core/services/catalog_service.dart';
import 'package:endurain/core/services/workouts_service.dart';
import 'package:endurain/features/workouts/widgets/exercise_info_dialog.dart';
import 'package:endurain/features/workouts/widgets/exercise_picker_dialog.dart';

/// Plan editor (create/edit): name, description and exercise prescriptions.
///
/// Mirrors the web's PlanDialog: exercises are picked from the catalog and
/// configured with target sets/reps/weight.
Future<bool> showPlanEditorDialog(
  BuildContext context, {
  WorkoutPlan? existing,
}) async {
  // `false` = closed/cancelled, `true` = plan saved.
  final result = await showDialog<_PlanEditorResult?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PlanEditorDialog(existing: existing),
  );
  return result?.saved ?? false;
}

class _PlanEditorResult {
  final bool saved;
  final String message;
  const _PlanEditorResult(this.saved, this.message);
}

class _PlanEditorDialog extends StatefulWidget {
  const _PlanEditorDialog({this.existing});

  final WorkoutPlan? existing;

  @override
  State<_PlanEditorDialog> createState() => _PlanEditorDialogState();
}

class _PlanEditorDialogState extends State<_PlanEditorDialog> {
  final WorkoutsService _service = WorkoutsService.instance;
  final CatalogService _catalog = CatalogService.instance;

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final List<_EditorRow> _rows;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _description = TextEditingController(text: widget.existing?.description ?? '');
    _rows = [
      for (final ex in widget.existing?.exercises ?? const <WorkoutPlanExercise>[])
        _EditorRow(
          name: ex.name,
          wgerId: ex.wgerExerciseId,
          targetSets: ex.targetSets ?? 3,
          targetReps: ex.targetReps ?? '10',
          targetWeight: ex.targetWeightKg,
          dayLabel: ex.dayLabel,
        ),
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _addExercise() async {
    final picked = await showDialog<CatalogExercise>(
      context: context,
      builder: (ctx) => const ExercisePickerDialog(),
    );
    if (picked == null) return;
    setState(() {
      _rows.add(_EditorRow(
        name: picked.name(RussianOrEnglish.ru),
        wgerId: picked.id,
        targetSets: 3,
        targetReps: '10',
      ));
    });
  }

  Future<void> _save() async {
    if (_rows.isEmpty) {
      setState(() => _error = 'Добавьте хотя бы одно упражнение');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final exercises = [
      for (var i = 0; i < _rows.length; i++)
        _rows[i].toPlanExercise(position: i),
    ];
    WorkoutPlan? saved;
    if (widget.existing?.id != null) {
      saved = await _service.updatePlan(
        widget.existing!.id!,
        name: _name.text.trim(), 
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        exercises: exercises,
      );
    } else {
      saved = await _service.createPlan(
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        exercises: exercises,
      );
    }
    if (!mounted) return;
    if (saved == null) {
      setState(() {
        _saving = false;
        _error = 'Не удалось сохранить: нет связи с сервером?';
      });
      return;
    }
    Navigator.pop(context, const _PlanEditorResult(true, 'План сохранён'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing?.id != null ? 'Изменить план' : 'Новый план',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: widget.existing?.id == null,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Упражнения', style: theme.textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: _saving ? null : _addExercise,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Добавить'),
                ),
              ],
            ),
            Expanded(
              child: _rows.isEmpty
                  ? Center(
                      child: Text(
                        'Пусто — добавьте упражнения из каталога',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: false,
                      itemCount: _rows.length,
                      itemBuilder: (ctx, i) {
                        final row = _rows[i];
                        final catalogEx =
                            row.wgerId != null ? _catalog.byId(row.wgerId!) : null;
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${i + 1}. ${row.name}',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (catalogEx != null)
                                      IconButton(
                                        tooltip: 'Как выполнять',
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.info_outline, size: 18),
                                        onPressed: () =>
                                            showExerciseInfoDialog(context, catalogEx),
                                      ),
                                    _reorderButtons(i),
                                    IconButton(
                                      tooltip: 'Удалить',
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      onPressed: () => setState(() => _rows.removeAt(i)),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    _numberField(
                                      label: 'подх.',
                                      value: row.targetSets,
                                      isInt: true,
                                      onChanged: (v) => row.targetSets = v?.toInt(),
                                    ),
                                    const SizedBox(width: 6),
                                    _textField(
                                      label: 'повторы',
                                      text: row.targetReps ?? '',
                                      onChanged: (v) => row.targetReps = v,
                                    ),
                                    const SizedBox(width: 6),
                                    _numberField(
                                      label: 'кг',
                                      value: row.targetWeight,
                                      isInt: false,
                                      onChanged: (v) => row.targetWeight = v,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context, const _PlanEditorResult(false, '')),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сохранить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reorderButtons(int i) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_upward, size: 16),
          onPressed: i > 0
              ? () => setState(() {
                    final r = _rows.removeAt(i);
                    _rows.insert(i - 1, r);
                  })
              : null,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_downward, size: 16),
          onPressed: i < _rows.length - 1
              ? () => setState(() {
                    final r = _rows.removeAt(i);
                    _rows.insert(i + 1, r);
                  })
              : null,
        ),
      ],
    );
  }

  Widget _textField({
    required String label,
    required String text,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 72,
      child: TextFormField(
        initialValue: text,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _numberField({
    required String label,
    num? value,
    required bool isInt,
    required ValueChanged<double?> onChanged,
  }) {
    return SizedBox(
      width: 72,
      child: TextFormField(
        initialValue: value == null ? '' : (isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(1)),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) {
          final parsed = double.tryParse(v.replaceAll(',', '.'));
          onChanged(parsed);
        },
      ),
    );
  }
}

class _EditorRow {
  String name;
  int? wgerId;
  String? dayLabel;
  int? targetSets;
  String targetReps;
  double? targetWeight;

  _EditorRow({
    required this.name,
    this.wgerId,
    this.dayLabel,
    required this.targetSets,
    required this.targetReps,
    this.targetWeight,
  });

  WorkoutPlanExercise toPlanExercise({required int position}) => WorkoutPlanExercise(
        position: position,
        name: name,
        muscleGroup: null,
        wgerExerciseId: wgerId,
        targetSets: targetSets,
        targetReps: targetReps,
        targetWeightKg: targetWeight,
        dayLabel: dayLabel,
      );
}
