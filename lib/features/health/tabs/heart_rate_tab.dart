import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/core/models/hr_zones.dart';
import 'package:zapfit/core/utils/stress_score_calculator.dart';
import 'package:zapfit/features/health/widgets/heart_rate_card.dart';
import 'package:zapfit/features/health/widgets/realtime_hr_widget.dart';
import 'package:zapfit/features/health/tabs/heart_rate_history_screen.dart';
import 'package:intl/intl.dart';
import 'package:zapfit/l10n/app_localizations.dart';

class HeartRateTab extends StatelessWidget {
  const HeartRateTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<HealthService>(
      builder: (context, service, child) {
        final records = service.heartRateRecords;
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayHr = records.where((r) => r.timestamp.isAfter(todayStart)).toList();

        // Build chart points
        final points = todayHr
            .map((r) => HeartRatePoint(time: r.timestamp, bpm: r.bpm))
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));

        final settings = AppSettingsController.instance;
        final currentBpm = todayHr.isNotEmpty ? todayHr.first.bpm : null;
        final maxBpm = todayHr.isNotEmpty ? todayHr.map((r) => r.bpm).reduce((a, b) => a > b ? a : b) : null;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => service.autoImportFromHealthConnect(daysBack: 30),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const RealtimeHrWidget(showGraph: false),
                const SizedBox(height: 16),
                HeartRateCard(
                  currentBpm: currentBpm,
                  restingBpm: settings.userRestingHeartRate > 0 ? settings.userRestingHeartRate : null,
                  maxBpm: maxBpm,
                  todayPoints: points,
                ),
                const SizedBox(height: 16),
                _buildHrZonesCard(context, todayHr, l10n),
                const SizedBox(height: 16),
                // === ZAPFIT metrics ===
                _buildKarvonenZonesCard(context, l10n),
                const SizedBox(height: 16),
                _buildStressScoreCard(context, l10n),
                const SizedBox(height: 16),
                // === ZAPFIT metrics ===
                if (records.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(l10n.history,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const HeartRateHistoryScreen())),
                        child: const Text('Показать всё', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...records.take(7).map((r) => _buildHrTile(context, r)),
                ],
                if (records.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_outline,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(l10n.noHeartRateRecords,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(l10n.importFromHealthConnect,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHrZonesCard(BuildContext context, List<HeartRateRecord> todayHr, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final settings = AppSettingsController.instance;
    final zones = HeartRateZones.fromAge(settings.userAge ?? 25);

    if (todayHr.length < 2) return const SizedBox.shrink();

    // Calculate time in each zone
    final distribution = <HeartRateZone, int>{};
    for (final z in HeartRateZone.values) {
      distribution[z] = 0;
    }

    for (int i = 1; i < todayHr.length; i++) {
      final prevTs = todayHr[i - 1].timestamp;
      final currTs = todayHr[i].timestamp;
      final bpm = todayHr[i].bpm;
      final durationMs = currTs.difference(prevTs).inMilliseconds;
      final zone = zones.getZone(bpm).zone;
      distribution[zone] = (distribution[zone] ?? 0) + durationMs;
    }

    final totalMs = distribution.values.fold(0, (a, b) => a + b);
    if (totalMs == 0) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Зоны пульса (сегодня)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            for (final zone in zones.zones) ...[
              _buildZoneBar(
                distribution[zone.zone]! / totalMs,
                zone.color,
                zone.nameRu,
                (distribution[zone.zone]! / 60000).round(),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildZoneBar(double ratio, Color color, String label, int minutes) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 14,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text('${minutes}м',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }

  // === ZAPFIT metrics ===
  Widget _buildKarvonenZonesCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final settings = AppSettingsController.instance;

    final maxHr = settings.userMaxHeartRate;
    final restingHr = settings.userRestingHeartRate;

    if (restingHr <= 0 || maxHr <= 0 || restingHr >= maxHr) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Зоны пульса (Karvonen)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 12),
              Text('Нет данных', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final zones = HeartRateZones.fromKarvonen(maxHr: maxHr, restingHr: restingHr);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Зоны пульса (Karvonen)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Покой $restingHr · Макс $maxHr уд/мин',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            for (final zone in zones.zones) ...[
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: zone.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: Text(zone.nameRu,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  const Spacer(),
                  Text('${zone.minBpm}–${zone.maxBpm} уд/мин',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStressScoreCard(BuildContext context, AppLocalizations l10n) {
    final settings = AppSettingsController.instance;
    final restingHr = settings.userRestingHeartRate > 0 ? settings.userRestingHeartRate.toDouble() : null;
    final hrvSetting = settings.userHrvRmssd;
    final hrvRmssd = hrvSetting > 0 ? hrvSetting : null;
    final hasHrv = hrvRmssd != null;

    final score = hasHrv
        ? StressScoreCalculator.calculate(
            hrvRmssd: hrvRmssd,
            lfHfRatio: null,
            restingHr: restingHr,
          )
        : 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Индекс стресса',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            if (score > 0) ...[
              Text('$score — ${StressScoreCalculator.classify(score)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ] else ...[
              const Text('Нет данных', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              const Text('HRV (RMSSD) недоступно в данных устройства',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              const Text('Можно ввести вручную: Профиль → Дополнительные данные → HRV (rMSSD).',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
  // === ZAPFIT metrics ===

  Widget _buildHrTile(BuildContext context, HeartRateRecord record) {
    return ListTile(
      leading: Icon(Icons.favorite,
          color: _hrColor(record.bpm), size: 20),
      title: Text('${record.bpm} bpm',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(record.timestamp)),
      trailing: record.source == 'health_connect'
          ? const Icon(Icons.phone_android, size: 16, color: Colors.grey)
          : const Icon(Icons.bluetooth, size: 16, color: Colors.blue),
    );
  }

  Color _hrColor(int bpm) {
    if (bpm < 60) return Colors.blue;
    if (bpm < 100) return Colors.green;
    if (bpm < 130) return Colors.orange;
    if (bpm < 160) return Colors.red;
    return Colors.purple;
  }
}
