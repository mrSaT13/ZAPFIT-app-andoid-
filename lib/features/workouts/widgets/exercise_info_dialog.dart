import 'package:flutter/material.dart';

import 'package:endurain/core/models/catalog_models.dart';
import 'package:endurain/core/services/catalog_service.dart';

/// "Как выполнять" — bottom-sheet with the catalog description + technique
/// tip (RU with EN fallback, same as the web picker's ⓘ button).
Future<void> showExerciseInfoDialog(BuildContext context, CatalogExercise ex) async {
  final catalog = CatalogService.instance;
  final desc = ex.description(RussianOrEnglish.ru);
  final tip = ex.firstTip(RussianOrEnglish.ru);
  final category = catalog.categoryName(ex.categoryId);
  final equipment = [for (final id in ex.equipmentIds) catalog.equipmentName(id)]
      .where((s) => s.isNotEmpty)
      .join(', ');
  final muscles = [
    for (final id in [...ex.muscleIds, ...ex.muscleIdsSecondary].take(4)) catalog.muscleName(id),
  ].where((s) => s.isNotEmpty).join(', ');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
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
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ex.name(RussianOrEnglish.ru),
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              Text('Как выполнять', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(desc, style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            if (tip != null && tip.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primaryContainer.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18, color: Theme.of(ctx).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tip, style: Theme.of(ctx).textTheme.bodyMedium)),
                  ],
                ),
              ),
            ],
            if ((desc == null || desc.isEmpty) && (tip == null || tip.isEmpty))
              Text(
                'Описания пока нет — ориентируйтесь на название и мышцы.',
                style: Theme.of(ctx)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(ctx).colorScheme.outline),
              ),
          ],
        ),
      ),
    ),
  );
}
