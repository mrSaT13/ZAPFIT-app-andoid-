import 'package:flutter/material.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class WeightHistoryScreen extends StatelessWidget {
  final List<WeightRecord> records;
  const WeightHistoryScreen({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.healthWeight} — ${l10n.history.toLowerCase()}'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: records.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = records[i];
          return ListTile(
            leading: const Icon(Icons.monitor_weight_outlined, color: Colors.blue),
            title: Text('${r.weight} кг'),
            subtitle: Text(DateFormat('dd.MM.yyyy').format(r.date)),
            trailing: r.isSynced
                ? const Icon(Icons.cloud_done, color: Colors.green, size: 16)
                : const Icon(Icons.cloud_upload_outlined, color: Colors.orange, size: 16),
          );
        },
      ),
    );
  }
}
