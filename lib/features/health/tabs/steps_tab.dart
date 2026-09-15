import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/services/steps_counter_service.dart';
import 'package:zapfit/core/services/widgets_service.dart';
import 'package:zapfit/features/health/tabs/steps_history_screen.dart';
import 'package:intl/intl.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zapfit/l10n/app_localizations.dart';

class StepsTab extends StatefulWidget {
  const StepsTab({super.key});

  @override
  State<StepsTab> createState() => _StepsTabState();
}

class _StepsTabState extends State<StepsTab> {
  bool _autoSyncTriggered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<HealthService>(
      builder: (context, service, child) {
        if (!_autoSyncTriggered && !service.isLoading) {
          _autoSyncTriggered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            // First: Health Connect import (authoritative source)
            await service.autoImportFromHealthConnect(force: true);
            // Then: pedometer sync (fallback, only updates if higher)
            final stepsService = StepsCounterService.instance;
            if (stepsService.autoSyncEnabled && stepsService.permissionsGranted) {
              stepsService.syncNow(daysBack: 2);
            }
          });
        }
        final records = service.stepsRecords;
        final todayStr = DateTime.now().toIso8601String().split('T')[0];
        final todaySteps = records.any((r) => r.date.toIso8601String().startsWith(todayStr))
            ? records.firstWhere((r) => r.date.toIso8601String().startsWith(todayStr)).steps
            : 0;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => service.autoImportFromHealthConnect(force: true),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStepsCard(context, todaySteps, service),
                const SizedBox(height: 24),
                if (records.length >= 2) ...[
                  Text(l10n.weeklyStats, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  _buildStepsChart(context, records),
                  const SizedBox(height: 24),
                ],
                Text(l10n.stepsHistory, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                if (records.isEmpty && !service.isLoading)
                  Center(child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(l10n.noData),
                  ))
                else ...[
                  ...records.take(7).map((r) => _buildStepsTile(context, r, service)),
                  if (records.length > 7)
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => StepsHistoryScreen(records: records)),
                      ),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('Показать всё'),
                    ),
                ],
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddOrUpdateStepsDialog(context, service, todaySteps),
            icon: todaySteps == 0 ? const Icon(Icons.add) : const Icon(Icons.edit),
            label: Text(todaySteps == 0 ? l10n.add : l10n.edit),
          ),
        );
      },
    );
  }

  Widget _buildStepsCard(BuildContext context, int steps, HealthService service) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    const goal = 10000;
    final progress = (steps / goal).clamp(0.0, 1.0);

    // Calculate today's detailed stats
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final todayRecord = service.stepsRecords.isNotEmpty
        ? service.stepsRecords.firstWhere(
            (r) => r.date.toIso8601String().startsWith(todayStr),
            orElse: () => StepsRecord(date: DateTime.now(), steps: 0),
          )
        : null;

    final distanceKm = (todayRecord?.distanceMeters ?? todayRecord?.estimatedDistanceMeters ?? 0) / 1000;
    final calories = todayRecord?.calories ?? todayRecord?.estimatedCalories ?? 0;
    final activeMin = todayRecord?.activeMinutes ?? 0;
    final runDist = todayRecord?.runDistanceMeters ?? 0;
    final walkDist = todayRecord?.walkDistanceMeters ?? 0;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_walk, color: theme.colorScheme.primary, size: 32),
                const SizedBox(width: 8),
                Text('$steps', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
              ],
            ),
            Text('шагов сегодня', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  children: [
                    Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text(l10n.goal, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('${l10n.goal}: $goal ${l10n.healthSteps.toLowerCase()}', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // Detailed stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat('Дистанция', '${distanceKm.toStringAsFixed(1)} км'),
                _miniStat('Калории', '${calories.toStringAsFixed(0)} ккал'),
                if (activeMin > 0) _miniStat('Активность', '$activeMin мин'),
              ],
            ),
            if (runDist > 0 || walkDist > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (runDist > 0) _miniStat('Бег', '${(runDist / 1000).toStringAsFixed(1)} км'),
                  if (walkDist > 0) _miniStat('Ходьба', '${(walkDist / 1000).toStringAsFixed(1)} км'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStepsChart(BuildContext context, List<StepsRecord> records) {
    final theme = Theme.of(context);
    final chartData = records.take(7).toList().reversed.toList();
    
    return Container(
      height: 150,
      padding: const EdgeInsets.only(top: 16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 20000,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= chartData.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('E').format(chartData[value.toInt()].date),
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
          barGroups: chartData.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.steps.toDouble(),
                  color: theme.colorScheme.primary,
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

  Widget _buildStepsTile(BuildContext context, StepsRecord r, HealthService service) {
    final l10n = AppLocalizations.of(context)!;
    final distanceKm = (r.distanceMeters ?? r.estimatedDistanceMeters) / 1000;
    final calories = r.calories ?? r.estimatedCalories;
    return ListTile(
      onLongPress: () => _showActionSheet(context, r, service),
      leading: const Icon(Icons.history, color: Colors.green),
      title: Text('${r.steps} шагов'),
      subtitle: Text(
        '${DateFormat('dd.MM.yyyy').format(r.date)}  •  ${distanceKm.toStringAsFixed(1)} км  •  ${calories.toStringAsFixed(0)} ккал',
        style: const TextStyle(fontSize: 12),
      ),
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
              if (value == 'edit') {
                _showEditStepsDialog(context, service, r);
              } else if (value == 'delete') {
                _showDeleteDialog(context, () => service.deleteStepsRecord(r.id!));
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

  void _showActionSheet(BuildContext context, StepsRecord r, HealthService service) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.editSteps),
              onTap: () {
                Navigator.pop(context);
                _showEditStepsDialog(context, service, r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(l10n.deleteRecord),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, () => service.deleteStepsRecord(r.id!));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOrUpdateStepsDialog(BuildContext context, HealthService service, int currentSteps) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentSteps == 0 ? '' : currentSteps.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentSteps == 0 ? l10n.add : l10n.editEntry),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '10000',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result != null && result >= 0) {
      if (currentSteps == 0) {
        service.addStepsRecord(result);
      } else {
        service.updateSteps(result);
      }
      WidgetsService.instance.updateStepsWidget(result, 10000);
    }
  }

  void _showEditStepsDialog(BuildContext context, HealthService service, StepsRecord record) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: record.steps.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editSteps),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '10000',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result != null && result >= 0) {
      service.updateStepsRecord(record.copyWith(steps: result, isSynced: false));
    }
  }

  void _showDeleteDialog(BuildContext context, VoidCallback onConfirm) {
    final l10n = AppLocalizations.of(context)!;
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
