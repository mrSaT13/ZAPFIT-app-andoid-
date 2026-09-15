import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zapfit/core/services/gear_service.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/models/gear_model.dart';
import 'package:zapfit/core/models/gear_photo.dart';
import 'package:zapfit/features/activities/gear_detail_screen.dart';

class GearTab extends StatefulWidget {
  const GearTab({super.key});

  @override
  State<GearTab> createState() => _GearTabState();
}

class _GearTabState extends State<GearTab> {
  final GearService _gearService = serviceLocator<GearService>();

  @override
  void initState() {
    super.initState();
    _gearService.fetchGears();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _gearService,
      child: Consumer<GearService>(
        builder: (context, service, _) {
          if (service.isLoading && service.gears.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.gears.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Снаряжение не найдено', style: TextStyle(color: Colors.grey)),
                  TextButton(onPressed: () => service.fetchGears(), child: const Text('Обновить')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => service.fetchGears(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: service.gears.length,
              itemBuilder: (context, index) {
                final gear = service.gears[index];
                return _buildGearCard(gear, service);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildGearCard(GearRecord gear, GearService service) {
    final theme = Theme.of(context);
    final distanceKm = gear.displayMileageKm.toStringAsFixed(1);
    
    // [comment removed - encoding corrupted]
    bool isDefault = service.defaultGears.values.contains(gear.id);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDefault ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => GearDetailScreen(gear: gear)),
            ),
            leading: FutureBuilder<List<GearPhoto>>(
              future: LocalActivityRepository.instance.getGearPhotos(gear.id),
              builder: (ctx, snap) {
                final photos = snap.data;
                if (photos != null && photos.isNotEmpty) {
                  // Prefer photo with existing file (offline cache covers server images)
                  GearPhoto? photo;
                  for (final p in photos) {
                    if (File(p.filePath).existsSync()) { photo = p; break; }
                  }
                  photo ??= photos.first;
                  final f = File(photo.filePath);
                  if (f.existsSync()) {
                    return ClipOval(
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Image.file(f, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(gear.gearType == 1 ? Icons.directions_bike : Icons.directions_run, color: Colors.grey)),
                      ),
                    );
                  }
                }
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDefault ? theme.colorScheme.primary : theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    gear.gearType == 1 ? Icons.directions_bike : Icons.directions_run,
                    color: isDefault ? Colors.white : theme.colorScheme.primary,
                  ),
                );
              },
            ),
            title: Row(
              children: [
                Expanded(child: Text(gear.nickname, style: const TextStyle(fontWeight: FontWeight.bold))),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('ОСНОВНОЕ', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: Text('${gear.brand ?? ""} ${gear.model ?? ""} • ${gear.typeLabel}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$distanceKm км', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('пробег', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showSetDefaultDialog(gear, service),
                  icon: const Icon(Icons.star_outline, size: 18),
                  label: const Text('Сделать основным', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSetDefaultDialog(GearRecord gear, GearService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сделать основным для:'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (gear.gearType == 1)
              ...[
                _defaultTypeTile(context, service, gear.id, 'ride_gear_id', 'Велозаезд'),
                _defaultTypeTile(context, service, gear.id, 'mtb_ride_gear_id', 'MTB'),
                _defaultTypeTile(context, service, gear.id, 'gravel_ride_gear_id', 'Гревел'),
              ]
            else if (gear.gearType == 2)
              ...[
                _defaultTypeTile(context, service, gear.id, 'run_gear_id', 'Бег'),
                _defaultTypeTile(context, service, gear.id, 'trail_run_gear_id', 'Трейл'),
                _defaultTypeTile(context, service, gear.id, 'walk_gear_id', 'Ходьба'),
                _defaultTypeTile(context, service, gear.id, 'hike_gear_id', 'Поход'),
              ]
            else
              const Text('Для данного типа снаряжения нет категорий по умолчанию'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Widget _defaultTypeTile(BuildContext context, GearService service, int gearId, String key, String label) {
    bool isCurrent = service.defaultGears[key] == gearId;
    return ListTile(
      title: Text(label),
      trailing: isCurrent ? const Icon(Icons.check_circle, color: Colors.green) : null,
      onTap: () async {
        await service.setDefaultGear(key, gearId);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }
}
