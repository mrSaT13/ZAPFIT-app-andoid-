import 'package:flutter/material.dart';

import 'package:endurain/core/models/catalog_models.dart';
import 'package:endurain/core/services/catalog_service.dart';
import 'package:endurain/core/services/workouts_service.dart';

/// "How to perform" — bottom-sheet with the catalog description + technique
/// tip (RU with EN fallback, same as the web picker's ⓘ button).
///
/// When only the English text exists, a "Translate" button calls the server's
/// AI endpoint once (`POST /workouts/exercises/{id}/translate`); the result
/// is kept in memory for the session. The batch pipeline later stores such
/// translations in `exercise_descriptions_ru.json` on the server.
Future<void> showExerciseInfoDialog(BuildContext context, CatalogExercise ex) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ExerciseInfoSheet(exercise: ex),
  );
}

class _ExerciseInfoSheet extends StatefulWidget {
  const _ExerciseInfoSheet({required this.exercise});

  final CatalogExercise exercise;

  @override
  State<_ExerciseInfoSheet> createState() => _ExerciseInfoSheetState();
}

class _ExerciseInfoSheetState extends State<_ExerciseInfoSheet> {
  String? _translatedDesc;
  String? _translatedTip;
  bool _translating = false;
  bool _translateFailed = false;

  /// In-memory translations for the session (keyed by wger id).
  static final Map<int, ({String description, String? tip})> _cache = {};

  /// True only when the catalog itself carries a Russian description
  /// (the EN fallback doesn't count — that's exactly when translation helps).
  bool get _hasRu => widget.exercise.descriptionRu != null;

  Future<void> _translate() async {
    final cached = _cache[widget.exercise.id];
    if (cached != null) {
      setState(() {
        _translatedDesc = cached.description;
        _translatedTip = cached.tip;
        _translateFailed = false;
      });
      return;
    }
    setState(() {
      _translating = true;
      _translateFailed = false;
    });
    final result = await WorkoutsService.instance.translateExercise(widget.exercise.id);
    if (!mounted) return;
    if (result != null && result.description.isNotEmpty) {
      _cache[widget.exercise.id] = result;
      setState(() {
        _translatedDesc = result.description;
        _translatedTip = result.tip;
      });
    } else {
      setState(() => _translateFailed = true);
    }
    setState(() => _translating = false);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = CatalogService.instance;
    final ex = widget.exercise;
    final desc = _translatedDesc ?? ex.description(RussianOrEnglish.ru);
    final tip = _translatedTip ?? ex.firstTip(RussianOrEnglish.ru);
    final category = catalog.categoryName(ex.categoryId);
    final equipment = [for (final id in ex.equipmentIds) catalog.equipmentName(id)]
        .where((s) => s.isNotEmpty)
        .join(', ');
    final muscles = [
      for (final id in [...ex.muscleIds, ...ex.muscleIdsSecondary].take(4)) catalog.muscleName(id),
    ].where((s) => s.isNotEmpty).join(', ');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scroll) => SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ex.name(RussianOrEnglish.ru),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (category.isNotEmpty) Chip(label: Text(category, style: const TextStyle(fontSize: 12))),
                if (equipment.isNotEmpty) Chip(label: Text(equipment, style: const TextStyle(fontSize: 12))),
                if (muscles.isNotEmpty) Chip(label: Text(muscles, style: const TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 12),
            if (desc != null && desc.isNotEmpty) ...[
              Text('Как выполнять', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(desc, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            if (tip != null && tip.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tip, style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
            ],
            if ((desc == null || desc.isEmpty) && (tip == null || tip.isEmpty))
              Text(
                'Описания пока нет — ориентируйтесь на название и мышцы.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            // On-demand RU translation when only English exists.
            if (!_hasRu && _translatedDesc == null) ...[
              const SizedBox(height: 12),
              if (_translateFailed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Не удалось перевести — проверьте, что ИИ-ассистент настроен на сервере.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _translating ? null : _translate,
                icon: _translating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.translate, size: 18),
                label: Text(_translating ? 'Переводим…' : 'Перевести на русский'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
