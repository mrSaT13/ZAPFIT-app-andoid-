import 'package:flutter/material.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/core/models/hr_zones.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:intl/intl.dart';

class HeartRateHistoryScreen extends StatelessWidget {
  const HeartRateHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = serviceLocator<HealthService>();
    return Scaffold(
      appBar: AppBar(title: const Text('История пульса')),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, child) {
          final records = service.heartRateRecords;
          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('Нет записей пульса', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          // Group by day
          final grouped = <String, List<HeartRateRecord>>{};
          for (final r in records) {
            final key = DateFormat('dd.MM.yyyy').format(r.timestamp);
            grouped.putIfAbsent(key, () => []).add(r);
          }

          final settings = AppSettingsController.instance;
          final zones = HeartRateZones.fromAge(settings.userAge ?? 25);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final day = grouped.keys.elementAt(index);
              final dayRecords = grouped[day]!;
              final minBpm = dayRecords.map((r) => r.bpm).reduce((a, b) => a < b ? a : b);
              final maxBpm = dayRecords.map((r) => r.bpm).reduce((a, b) => a > b ? a : b);
              final avgBpm = (dayRecords.map((r) => r.bpm).reduce((a, b) => a + b) / dayRecords.length).round();
              final zone = zones.getZone(avgBpm);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  leading: CircleAvatar(
                    backgroundColor: zone.color.withValues(alpha: 0.15),
                    child: Text('${dayRecords.length}',
                        style: TextStyle(color: zone.color, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  title: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'средний: $avgBpm · ${zone.nameRu}',
                    style: TextStyle(fontSize: 12, color: zone.color),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _miniStat('▼', '$minBpm', Colors.blue),
                      const SizedBox(width: 8),
                      _miniStat('▲', '$maxBpm', Colors.red),
                    ],
                  ),
                  children: dayRecords.map((r) {
                    final rZone = zones.getZone(r.bpm);
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.favorite, color: rZone.color, size: 18),
                      title: Text('${r.bpm} bpm',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      subtitle: Text(DateFormat('HH:mm').format(r.timestamp), style: const TextStyle(fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: rZone.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(rZone.nameRu, style: TextStyle(fontSize: 10, color: rZone.color)),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Widget _miniStat(String icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: TextStyle(fontSize: 10, color: color)),
        const SizedBox(width: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
