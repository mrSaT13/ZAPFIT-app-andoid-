import 'package:flutter/material.dart';

import 'package:endurain/core/models/catalog_models.dart';
import 'package:endurain/core/services/catalog_service.dart';
import 'package:endurain/features/workouts/widgets/exercise_info_dialog.dart';

/// Exercise picker over the bundled offline catalog (914 entries, instant).
///
/// Mirrors the web picker: search + category/equipment selects; returns the
/// chosen [CatalogExercise] to the plan editor.
class ExercisePickerDialog extends StatefulWidget {
  const ExercisePickerDialog({super.key});

  @override
  State<ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<ExercisePickerDialog> {
  final CatalogService _catalog = CatalogService.instance;
  final TextEditingController _query = TextEditingController();

  int? _categoryId;
  int? _equipmentId;
  List<CatalogExercise> _results = [];

  @override
  void initState() {
    super.initState();
    _catalog.ensureLoaded().then((_) => mounted ? _runSearch() : null);
    _results = _catalog.search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _runSearch() {
    setState(() {
      _results = _catalog.search(
        query: _query.text,
        categoryId: _categoryId,
        equipmentId: _equipmentId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = _catalog.categories ?? [];
    final equipment = _catalog.equipment ?? [];
    final isReady = _catalog.isReady;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Каталог упражнений', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              onChanged: (_) => _runSearch(),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: 'Поиск упражнений…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _categoryId,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Категория', border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem<int>(child: Text('Все категории')),
                      for (final c in categories)
                        DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(_catalog.categoryName(c.id)),
                        ),
                    ],
                    onChanged: (v) {
                      setState(() => _categoryId = v);
                      _runSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _equipmentId,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Снаряд', border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem<int>(child: Text('Любое снаряжение')),
                      for (final e in equipment)
                        DropdownMenuItem<int>(
                          value: e.id,
                          child: Text(_catalog.equipmentName(e.id)),
                        ),
                    ],
                    onChanged: (v) {
                      setState(() => _equipmentId = v);
                      _runSearch();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: !isReady
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            'Ничего не найдено — попробуйте другой запрос.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final ex = _results[i];
                            final muscles = [
                              for (final id in ex.muscleIds.take(3)) _catalog.muscleName(id),
                            ].where((s) => s.isNotEmpty).join(', ');
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.fitness_center,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(ex.name(RussianOrEnglish.ru), maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                [
                                  _catalog.categoryName(ex.categoryId),
                                  if (muscles.isNotEmpty) muscles,
                                ].where((s) => s.isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: IconButton(
                                tooltip: 'Как выполнять',
                                icon: const Icon(Icons.info_outline, size: 20),
                                onPressed: () => showExerciseInfoDialog(context, ex),
                              ),
                              onTap: () => Navigator.pop(context, ex),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
