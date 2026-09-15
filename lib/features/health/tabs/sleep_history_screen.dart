import 'package:flutter/material.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/core/utils/sleep_score_calculator.dart';
import 'package:zapfit/core/utils/sleep_need_calculator.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/features/health/tabs/sleep_detail_screen.dart';
import 'package:zapfit/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class SleepHistoryScreen extends StatelessWidget {
  final List<SleepRecord> records;
  final List<HeartRateRecord> heartRateRecords;
  const SleepHistoryScreen({super.key, required this.records, this.heartRateRecords = const []});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.healthSleep} — ${l10n.history.toLowerCase()}'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: records.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == 0) return _buildZapfitSummaryCard(context);
          final r = records[i - 1];
          final scoreResult = SleepScoreCalculator.calculate(
            totalSleepSeconds: r.totalSleepSeconds,
            deepSleepSeconds: r.deepSleepSeconds,
            lightSleepSeconds: r.lightSleepSeconds,
            remSleepSeconds: r.remSleepSeconds,
            awakeSleepSeconds: r.awakeSleepSeconds,
          );
          final h = r.totalSleepSeconds ~/ 3600;
          final m = (r.totalSleepSeconds % 3600) ~/ 60;
          return ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SleepDetailScreen(record: r, heartRateRecords: heartRateRecords)),
            ),
            leading: const Icon(Icons.bedtime_outlined, color: Colors.indigo),
            title: Text('${h}ч ${m}м'),
            subtitle: Text(DateFormat('dd.MM.yyyy').format(r.date)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: SleepScoreCalculator.qualityColor(scoreResult.quality).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${scoreResult.score}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: SleepScoreCalculator.qualityColor(scoreResult.quality))),
            ),
          );
        },
      ),
    );
  }

  // === ZAPFIT metrics ===
  Widget _buildZapfitSummaryCard(BuildContext context) {
    final settings = AppSettingsController.instance;
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = List<SleepRecord>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;

    int sleepScore = latest.sleepScoreOverall ?? 0;
    if (sleepScore == 0 && latest.totalSleepSeconds > 0) {
      sleepScore = SleepScoreCalculator.calculate(
        totalSleepSeconds: latest.totalSleepSeconds,
        deepSleepSeconds: latest.deepSleepSeconds,
        lightSleepSeconds: latest.lightSleepSeconds,
        remSleepSeconds: latest.remSleepSeconds,
        awakeSleepSeconds: latest.awakeSleepSeconds,
        restHr: latest.restHeartRate?.toDouble(),
        age: settings.userAge,
      ).score;
    }

    final age = settings.userAge;
    final needHours = age != null ? SleepNeedCalculator.recommendedHours(age) : null;

    final cycleMinutes = 90;
    final totalMin = latest.totalSleepSeconds ~/ 60;
    final fullCycles = totalMin ~/ cycleMinutes;
    final remainderMin = totalMin % cycleMinutes;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Метрики сна (ZAPFIT)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Оценка сна', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                if (sleepScore > 0)
                  Text('$sleepScore — ${SleepScoreCalculator.classify(sleepScore)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: SleepScoreCalculator.qualityColor(
                              SleepScoreCalculator.classify(sleepScore))))
                else
                  const Text('Нет данных', style: TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Потребность во сне', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                if (needHours != null)
                  Text('$needHours ч (возраст ${age} лет)',
                      style: const TextStyle(fontWeight: FontWeight.bold))
                else
                  const Text('Нет данных', style: TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Циклы сна', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                if (latest.totalSleepSeconds > 0)
                  Text('$fullCycles × $cycleMinutes мин (ост. $remainderMin)',
                      style: const TextStyle(fontWeight: FontWeight.bold))
                else
                  const Text('Нет данных', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  // === ZAPFIT metrics ===
}
