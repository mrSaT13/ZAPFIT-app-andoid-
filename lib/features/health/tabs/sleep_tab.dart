import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:intl/intl.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/core/utils/sleep_score_calculator.dart';
import 'package:zapfit/core/utils/sleep_need_calculator.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/features/health/widgets/sleep_card.dart';
import 'package:zapfit/features/health/tabs/sleep_history_screen.dart';
import 'package:zapfit/features/health/tabs/sleep_detail_screen.dart';
import 'package:zapfit/l10n/app_localizations.dart';

class SleepTab extends StatelessWidget {
  const SleepTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<HealthService>(
      builder: (context, service, child) {
        final records = service.sleepRecords;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => service.autoImportFromHealthConnect(force: true),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (records.isNotEmpty) ...[
                  _buildLatestSleepCard(context, records.first, service),
                  const SizedBox(height: 24),
                  // === ZAPFIT metrics ===
                  _buildZapfitSleepMetricsCard(context, service),
                  const SizedBox(height: 24),
                  Text('${l10n.healthSleep} ${l10n.history.toLowerCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                ],
                if (records.isEmpty && !service.isLoading)
                  Center(child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(l10n.noSleepRecords),
                  ))
                else ...[
                  ...records.take(7).map((r) => _buildSleepTile(context, r, service)),
                  if (records.length > 7)
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SleepHistoryScreen(records: records, heartRateRecords: service.heartRateRecords)),
                      ),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('Показать всё'),
                    ),
                ],
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddSleepDialog(context, service),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildLatestSleepCard(BuildContext context, SleepRecord r, HealthService service) {
    final sorted = List<SleepRecord>.from(service.sleepRecords)
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;

    final stages = <SleepStageSegment>[];
    final deepMin = latest.deepSleepSeconds ~/ 60;
    final lightMin = latest.lightSleepSeconds ~/ 60;
    final remMin = latest.remSleepSeconds ~/ 60;

    int minuteOffset = 0;
    if (deepMin > 0) {
      stages.add(SleepStageSegment(
        stage: SleepStage.deep,
        start: Duration(minutes: minuteOffset),
        end: Duration(minutes: minuteOffset + deepMin),
      ));
      minuteOffset += deepMin;
    }
    if (lightMin > 0) {
      stages.add(SleepStageSegment(
        stage: SleepStage.light,
        start: Duration(minutes: minuteOffset),
        end: Duration(minutes: minuteOffset + lightMin),
      ));
      minuteOffset += lightMin;
    }
    if (remMin > 0) {
      stages.add(SleepStageSegment(
        stage: SleepStage.rem,
        start: Duration(minutes: minuteOffset),
        end: Duration(minutes: minuteOffset + remMin),
      ));
    }

    final sleepStart = latest.sleepStartTime ?? latest.date.subtract(Duration(seconds: latest.totalSleepSeconds));
    final sleepEnd = latest.sleepEndTime ?? latest.date;

    // Calculate score locally if not provided by server
    int sleepScore = latest.sleepScoreOverall ?? 0;
    if (sleepScore == 0 && latest.totalSleepSeconds > 0) {
      final scoreResult = SleepScoreCalculator.calculate(
        totalSleepSeconds: latest.totalSleepSeconds,
        deepSleepSeconds: latest.deepSleepSeconds,
        lightSleepSeconds: latest.lightSleepSeconds,
        remSleepSeconds: latest.remSleepSeconds,
        awakeSleepSeconds: latest.awakeSleepSeconds,
      );
      sleepScore = scoreResult.score;
    }

    return SleepCard(
      data: SleepData(
        date: latest.date,
        totalSleep: Duration(seconds: latest.totalSleepSeconds),
        deepSleep: Duration(seconds: latest.deepSleepSeconds),
        lightSleep: Duration(seconds: latest.lightSleepSeconds),
        remSleep: Duration(seconds: latest.remSleepSeconds),
        awakeTime: Duration(seconds: latest.awakeSleepSeconds),
        restHeartRate: latest.restHeartRate,
        turnOverCount: latest.turnOverCount,
        intoSleepCount: latest.intoSleepCount,
        lazyBedCount: latest.lazyBedCount,
        dreamTime: latest.dreamTime,
        sleepScore: sleepScore > 0 ? sleepScore : null,
        stages: stages,
        sleepStart: sleepStart,
        sleepEnd: sleepEnd,
      ),
    );
  }

  // === ZAPFIT metrics ===
  Widget _buildZapfitSleepMetricsCard(BuildContext context, HealthService service) {
    final theme = Theme.of(context);
    final settings = AppSettingsController.instance;

    final sorted = List<SleepRecord>.from(service.sleepRecords)
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;

    // Improved Sleep score
    int sleepScore = latest.sleepScoreOverall ?? 0;
    SleepScoreResult? scoreResult;
    if (sleepScore == 0 && latest.totalSleepSeconds > 0) {
      scoreResult = SleepScoreCalculator.calculate(
        totalSleepSeconds: latest.totalSleepSeconds,
        deepSleepSeconds: latest.deepSleepSeconds,
        lightSleepSeconds: latest.lightSleepSeconds,
        remSleepSeconds: latest.remSleepSeconds,
        awakeSleepSeconds: latest.awakeSleepSeconds,
        restHr: latest.restHeartRate?.toDouble(),
        age: settings.userAge,
      );
      sleepScore = scoreResult.score;
    }

    // Sleep need (by age)
    final age = settings.userAge;
    final needHours = age != null ? SleepNeedCalculator.recommendedHours(age) : null;

    // Sleep cycles position (≈90 min per cycle)
    final cycleMinutes = 90;
    final totalMin = latest.totalSleepSeconds ~/ 60;
    final fullCycles = totalMin ~/ cycleMinutes;
    final remainderMin = totalMin % cycleMinutes;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Метрики сна (ZAPFIT)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 14),
            // Improved Sleep score
            Row(
              children: [
                const Icon(Icons.nightlight_round, size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text('Оценка сна', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                if (sleepScore > 0) ...[
                  Text('$sleepScore',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: SleepScoreCalculator.qualityColor(
                              SleepScoreCalculator.classify(sleepScore)))),
                  const SizedBox(width: 8),
                  Text(SleepScoreCalculator.classify(sleepScore),
                      style: const TextStyle(color: Colors.grey)),
                ] else
                  const Text('Нет данных', style: TextStyle(color: Colors.grey)),
              ],
            ),
            if (scoreResult != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _zapfitChip('Длит. +${scoreResult.durationPoints}'),
                  _zapfitChip('Глуб. +${scoreResult.deepPoints}'),
                  _zapfitChip('REM +${scoreResult.remPoints}'),
                  _zapfitChip('Проб. +${scoreResult.awakePoints}'),
                  _zapfitChip('Эфф. +${scoreResult.efficiencyPoints}'),
                ],
              ),
            ],
            const Divider(height: 20),
            // Sleep need by age
            Row(
              children: [
                const Icon(Icons.hourglass_bottom, size: 20, color: Colors.teal),
                const SizedBox(width: 8),
                const Text('Потребность во сне', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                if (needHours != null)
                  Text('$needHours ч',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                else
                  const Text('Нет данных', style: TextStyle(color: Colors.grey)),
                if (needHours != null) ...[
                  const SizedBox(width: 8),
                  Text('(возраст: ${age} лет)',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ],
            ),
            const Divider(height: 20),
            // Sleep cycles position
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.loop, size: 20, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Циклы сна', style: TextStyle(fontWeight: FontWeight.w500)),
                ),
                if (latest.totalSleepSeconds > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$fullCycles × $cycleMinutes мин',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('остаток: $remainderMin мин ($totalMin мин всего)',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  )
                else
                  const Text('Нет данных', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _zapfitChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.indigo)),
    );
  }
  // === ZAPFIT metrics ===

  Widget _buildSleepTile(BuildContext context, SleepRecord r, HealthService service) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SleepDetailScreen(record: r, heartRateRecords: service.heartRateRecords)),
      ),
      onLongPress: () => _showActionSheet(context, r, service),
      leading: const Icon(Icons.bedtime_outlined, color: Colors.indigo),
      title: Text(_formatDuration(r.totalSleepSeconds)),
      subtitle: Text(DateFormat('dd.MM.yyyy').format(r.date)),
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
                _showDeleteDialog(context, () => service.deleteSleepRecord(r.id!));
              } else if (value == 'edit') {
                _showAddSleepDialog(context, service, existingRecord: r);
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

  void _showActionSheet(BuildContext context, SleepRecord r, HealthService service) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                _showAddSleepDialog(context, service, existingRecord: r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, () => service.deleteSleepRecord(r.id!));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  void _showAddSleepDialog(BuildContext context, HealthService service, {SleepRecord? existingRecord}) async {
    final l10n = AppLocalizations.of(context)!;

    TimeOfDay bedtime = const TimeOfDay(hour: 23, minute: 0);
    TimeOfDay wakeTime = const TimeOfDay(hour: 7, minute: 0);

    if (existingRecord != null) {
      final totalH = existingRecord.totalSleepSeconds / 3600;
      final bedH = (24 - totalH).floor().clamp(0, 23);
      final bedM = ((24 - totalH - bedH) * 60).round().clamp(0, 59);
      bedtime = TimeOfDay(hour: bedH, minute: bedM);
      wakeTime = const TimeOfDay(hour: 7, minute: 0);
    }

    final result = await showDialog<Map<String, TimeOfDay>>(
      context: context,
      builder: (context) {
        TimeOfDay bed = bedtime;
        TimeOfDay wake = wakeTime;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final totalMinutes = _calcSleepMinutes(bed, wake);
            final h = totalMinutes ~/ 60;
            final m = totalMinutes % 60;

            return AlertDialog(
              title: Text(existingRecord == null ? l10n.addSleep : l10n.editEntry),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.bedtime, color: Colors.indigo),
                    title: const Text('Заснул'),
                    trailing: Text(
                      '${bed.hour.toString().padLeft(2, '0')}:${bed.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: bed,
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setDialogState(() => bed = picked);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.alarm, color: Colors.green),
                    title: const Text('Проснулся'),
                    trailing: Text(
                      '${wake.hour.toString().padLeft(2, '0')}:${wake.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: wake,
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setDialogState(() => wake = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timelapse, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Итого: ${h}ч ${m.toString().padLeft(2, '0')}м',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
                FilledButton(
                  onPressed: () => Navigator.pop(context, {'bed': bed, 'wake': wake}),
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      final bed = result['bed']!;
      final wake = result['wake']!;
      final totalSeconds = _calcSleepMinutes(bed, wake) * 60;
      if (totalSeconds <= 0) return;

      if (existingRecord != null) {
        service.updateSleep(existingRecord.copyWith(
          totalSleepSeconds: totalSeconds,
          lightSleepSeconds: (totalSeconds * 0.5).toInt(),
          deepSleepSeconds: (totalSeconds * 0.2).toInt(),
          remSleepSeconds: (totalSeconds * 0.2).toInt(),
          awakeSleepSeconds: (totalSeconds * 0.1).toInt(),
          isSynced: false,
        ));
      } else {
        service.addSleep(SleepRecord(
          date: DateTime.now(),
          totalSleepSeconds: totalSeconds,
          lightSleepSeconds: (totalSeconds * 0.5).toInt(),
          deepSleepSeconds: (totalSeconds * 0.2).toInt(),
          remSleepSeconds: (totalSeconds * 0.2).toInt(),
          awakeSleepSeconds: (totalSeconds * 0.1).toInt(),
        ));
      }
    }
  }

  int _calcSleepMinutes(TimeOfDay bed, TimeOfDay wake) {
    int bedMinutes = bed.hour * 60 + bed.minute;
    int wakeMinutes = wake.hour * 60 + wake.minute;
    int diff = wakeMinutes - bedMinutes;
    if (diff <= 0) diff += 24 * 60;
    return diff;
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
