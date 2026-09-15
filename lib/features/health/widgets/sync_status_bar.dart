import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zapfit/core/services/health_service.dart';

class HealthSyncStatusBar extends StatelessWidget {
  const HealthSyncStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthService>(
      builder: (context, service, child) {
        if (!service.isSyncing && service.syncProgress == 0) return const SizedBox.shrink();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: service.syncStatus.isNotEmpty ? 65 : 0,
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      service.syncStatus,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (service.totalToSync > 0)
                    Text(
                      '${service.currentSynced} / ${service.totalToSync}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: service.syncProgress,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
