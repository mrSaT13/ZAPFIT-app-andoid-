import 'package:flutter/material.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class WaterHistoryScreen extends StatelessWidget {
  final List<WaterRecord> records;
  const WaterHistoryScreen({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.healthWater} — ${l10n.history.toLowerCase()}'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: records.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = records[i];
          return ListTile(
            leading: const Icon(Icons.water_drop_outlined, color: Colors.cyan),
            title: Text('${r.amountMl.toInt()} ml'),
            subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(r.date)),
          );
        },
      ),
    );
  }
}
