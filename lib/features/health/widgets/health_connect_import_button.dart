import 'package:flutter/material.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/services/health_connect_service.dart';
import 'package:zapfit/l10n/app_localizations.dart';

class HealthConnectImportButton extends StatelessWidget {
  final HealthService healthService;
  final VoidCallback? onImported;

  const HealthConnectImportButton({
    super.key,
    required this.healthService,
    this.onImported,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(Icons.sync_alt, size: 20),
      tooltip: l10n.importFromHealthConnect,
      onPressed: () => _showImportDialog(context, l10n),
    );
  }

  void _showImportDialog(BuildContext context, AppLocalizations l10n) async {
    // First check availability
    final hc = HealthConnectService.instance;
    debugPrint('ImportButton: checking Health Connect availability...');
    final available = await hc.isAvailable();
    debugPrint('ImportButton: available = $available');
    
    if (!available) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health Connect не установлен или недоступен.\nУстановите Health Connect из Google Play.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Try to get permissions
    debugPrint('ImportButton: requesting permissions...');
    final hasPerms = await hc.hasPermissions();
    debugPrint('ImportButton: hasPermissions = $hasPerms');
    
    if (!hasPerms) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Разрешения Health Connect не выданы.\nОткройте: Настройки Android → Приложения → Health Connect → разрешения → включите ZAPFIT'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 6),
          ),
        );
      }
      return;
    }

    DateTimeRange? selectedRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: selectedRange,
      helpText: l10n.importFromHealthConnect.toUpperCase(),
      saveText: l10n.save,
    );

    if (range == null || !context.mounted) return;

    // Show loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(l10n.importing),
            ],
          ),
        ),
      );
    }

    final count = await healthService.importFromHealthConnect(
      start: range.start,
      end: range.end,
    );

    if (context.mounted) {
      Navigator.of(context).pop(); // dismiss loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.importSummary(count)),
          backgroundColor: Colors.green,
        ),
      );

      onImported?.call();
    }
  }
}
