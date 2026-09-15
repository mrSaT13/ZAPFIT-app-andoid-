import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:intl/intl.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/features/health/tabs/water_history_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zapfit/l10n/app_localizations.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/utils/hydration_need_calculator.dart';

class WaterTab extends StatelessWidget {
  const WaterTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<HealthService>(
      builder: (context, service, child) {
        final records = service.waterRecords;
        final todayStr = DateTime.now().toIso8601String().split('T')[0];
        final todayAmount = records
            .where((r) => r.date.toIso8601String().startsWith(todayStr))
            .fold<double>(0.0, (sum, r) => sum + r.amountMl);

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => service.autoImportFromHealthConnect(force: true),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTodayWaterCard(context, todayAmount, service),
                const SizedBox(height: 16),
                // === ZAPFIT metrics ===
                _buildHydrationNeedCard(context, service, todayStr, todayAmount),
                // === ZAPFIT metrics ===
                const SizedBox(height: 24),
                if (records.length >= 2) ...[
                  Text(l10n.weeklyStats, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  _buildWaterChart(context, records),
                  const SizedBox(height: 24),
                ],
                Text(l10n.history, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                if (records.isEmpty && !service.isLoading)
                  Center(child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(l10n.noWaterRecords),
                  ))
                else ...[
                  ...records.take(7).map((r) => _buildWaterTile(context, r, service)),
                  if (records.length > 7)
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => WaterHistoryScreen(records: records)),
                      ),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('Показать всё'),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaterChart(BuildContext context, List<WaterRecord> records) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));

    final dailyMap = <String, double>{};
    for (int i = 0; i <= 6; i++) {
      final d = now.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      dailyMap[key] = 0;
    }
    for (final r in records) {
      final key = DateFormat('yyyy-MM-dd').format(r.date);
      if (dailyMap.containsKey(key)) {
        dailyMap[key] = dailyMap[key]! + r.amountMl;
      }
    }

    final entries = dailyMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      height: 150,
      padding: const EdgeInsets.only(top: 16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 3000,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('E').format(DateTime.parse(entries[idx].key)),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value,
                  color: Colors.cyan,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTodayWaterCard(BuildContext context, double amount, HealthService service) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    const goal = 2000.0;
    final progress = (amount / goal).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(l10n.todayDrunk, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${amount.toInt()}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Text('ml', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.cyan.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
              ),
            ),
            const SizedBox(height: 8),
            Text('${l10n.goal}: ${goal.toInt()} ml', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _addWaterButton(context, service, 250, l10n.glass),
                _addWaterButton(context, service, 500, l10n.bottle),
                _addWaterButton(context, service, 100, '+100'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // === ZAPFIT metrics ===
  Widget _buildHydrationNeedCard(BuildContext context, HealthService service, String todayStr, double todayAmount) {
    final theme = Theme.of(context);

    double weightKg = 0;
    if (service.weightRecords.isNotEmpty) weightKg = service.weightRecords.first.weight;
    if (weightKg <= 0) weightKg = AppSettingsController.instance.userWeight;

    int activityMinutes = 0;
    for (final r in service.stepsRecords) {
      if (r.date.toIso8601String().startsWith(todayStr)) {
        activityMinutes = r.activeMinutes ?? 0;
        break;
      }
    }

    if (weightKg <= 0) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.water_drop_outlined, size: 48, color: Colors.cyan),
              SizedBox(height: 12),
              Text('Нет данных', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Укажите вес в профиле для расчёта нормы воды.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final needMl = HydrationNeedCalculator.dailyNeedMl(
      weightKg: weightKg,
      activityMinutes: activityMinutes,
    );
    final needL = (needMl / 1000.0);
    final progress = (todayAmount / needMl).clamp(0.0, 1.0);

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
                const Icon(Icons.water_drop_outlined, color: Colors.cyan),
                const SizedBox(width: 8),
                Text('Потребность в воде', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${needMl}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                const Text('мл/день', style: TextStyle(fontSize: 15, color: Colors.grey)),
                const SizedBox(width: 10),
                Text('(${needL.toStringAsFixed(1)} л)', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.cyan.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Выпито сегодня: ${todayAmount.toInt()} мл из ${needMl} мл',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (activityMinutes > 0)
              Text(
                'С активностью: $activityMinutes мин',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
  // === ZAPFIT metrics ===

  Widget _addWaterButton(BuildContext context, HealthService service, double ml, String label) {
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: () => service.addWater(ml),
          icon: const Icon(Icons.add),
          style: IconButton.styleFrom(backgroundColor: Colors.cyan.withOpacity(0.1), foregroundColor: Colors.cyan),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
        Text('${ml.toInt()} ml', style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildWaterTile(BuildContext context, WaterRecord r, HealthService service) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      onLongPress: () => _showActionSheet(context, r, service),
      leading: const Icon(Icons.water_drop_outlined, color: Colors.cyan),
      title: Text('${r.amountMl.toInt()} ml'),
      subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(r.date)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            r.isSynced ? Icons.cloud_done : Icons.cloud_upload_outlined,
            color: r.isSynced ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteDialog(context, l10n, () => service.deleteWaterRecord(r.id!));
              } else if (value == 'edit') {
                _showEditWaterDialog(context, service, r);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit), title: Text(l10n.edit), contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: Text(l10n.delete, style: const TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
    );
  }

  void _showActionSheet(BuildContext context, WaterRecord r, HealthService service) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.editVolume),
              onTap: () {
                Navigator.pop(context);
                _showEditWaterDialog(context, service, r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(l10n.deleteRecord),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, l10n, () => service.deleteWaterRecord(r.id!));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditWaterDialog(BuildContext context, HealthService service, WaterRecord r) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: r.amountMl.toInt().toString());
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editVolume),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(suffixText: 'ml', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text)),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      service.updateWater(r.copyWith(amountMl: result, isSynced: false));
    }
  }

  void _showDeleteDialog(BuildContext context, AppLocalizations l10n, VoidCallback onConfirm) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${l10n.deleteRecord}?'),
        content: Text(l10n.deleteRecordConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton.tonal(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
