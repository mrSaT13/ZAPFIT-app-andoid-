import 'package:flutter/material.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/utils/tdee_calculator.dart';

class NutritionTab extends StatefulWidget {
  const NutritionTab({super.key});

  @override
  State<NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends State<NutritionTab> {
  ActivityLevel? _activityLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsController.instance;

    final weightKg = settings.userWeight;
    final heightCm = settings.userHeight;
    final age = settings.userAge;
    final gender = settings.userGender.toLowerCase() == 'male' ? 1 : 0;

    final hasBase = weightKg > 0 && heightCm > 0 && age != null && age > 0;
    final canCompute = hasBase && _activityLevel != null;

    // === ZAPFIT metrics ===
    TdeeResult? tdee;
    if (canCompute) {
      tdee = TdeeCalculator.calculate(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age!,
        gender: gender,
        activityLevel: _activityLevel!,
      );
    }

    final macros = tdee?.maintenanceMacros;

    // Caloric balance: no intake model in the app — show TDEE baseline with note.
    // === ZAPFIT metrics ===

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Питание',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            if (!hasBase)
              _buildNoDataCard(
                context,
                'Нет данных',
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
                _buildCalorieBalanceCard(context, tdee),
              ],
            ],
          ],
        ),
      ),
    );
  }

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
            const Text('Уровень активности', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ActivityLevel.values.map((level) {
                final selected = _activityLevel == level;
                return ChoiceChip(
                  label: Text(TdeeCalculator.activityLevelLabel(level)),
                  selected: selected,
                  onSelected: (v) => setState(() => _activityLevel = v ? level : null),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // === ZAPFIT metrics ===
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
                const Icon(Icons.local_fire_department_outlined, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Text('Суточный расход (TDEE)', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${tdee.tdee.round()}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                const Text('ккал/день', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
                Text('Макронутриенты (норма)', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: r.$4, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 15))),
                  Text('${r.$2.round()} г', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Text('${r.$3.round()} ккал', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            )),
            const Divider(),
            Row(
              children: [
                const Expanded(child: Text('Всего', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                Text('${macros.totalCal.round()} ккал', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieBalanceCard(BuildContext context, TdeeResult tdee) {
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
            _balanceRow('Потребление:', '— ккал'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Учёт потребления калорий не подключён. Показан только расход (TDEE) как базовая норма.',
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
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
            Icon(Icons.info_outline, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
  // === ZAPFIT metrics ===
}
