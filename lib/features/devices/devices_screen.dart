import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:zapfit/core/models/device_model.dart';
import 'package:zapfit/core/services/bluetooth_sensor_service.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/features/devices/device_detail_screen.dart';
import 'package:intl/intl.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final BluetoothSensorService _bleService = serviceLocator<BluetoothSensorService>();
  StreamSubscription<List<ScanResult>>? _scanSub;
  List<ScanResult> _scanResults = [];
  List<BluetoothDevice> _bondedDevices = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _bleService.addListener(_onBleChanged);
    _loadBondedDevices();
  }

  @override
  void dispose() {
    _bleService.removeListener(_onBleChanged);
    _scanSub?.cancel();
    _bleService.stopScan();
    super.dispose();
  }

  void _onBleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadBondedDevices() async {
    try {
      final bonded = await FlutterBluePlus.bondedDevices;
      if (mounted) setState(() => _bondedDevices = bonded);
    } catch (e) {
      debugPrint('Failed to get bonded devices: $e');
    }
  }

  Future<void> _toggleScan() async {
    if (_scanning) {
      await _bleService.stopScan();
      await _scanSub?.cancel();
      setState(() => _scanning = false);
      return;
    }

    setState(() {
      _scanning = true;
      _scanResults = [];
    });

    _scanSub?.cancel();
    _scanSub = _bleService.scanResultsStream.listen((results) {
      if (!mounted) return;
      setState(() {
        _scanResults = results;
        _bleService.updateScanResults(results);
      });
      // Auto-connect to saved devices
      for (final result in results) {
        final id = result.device.remoteId.str;
        if (_bleService.trackedDevices.any((d) => d.id == id) && !_bleService.isDeviceConnected(id)) {
          _bleService.connect(result.device).catchError((_) {});
        }
      }
    });

    _bleService.startScan(filterByServices: true).catchError((_) {});
    _loadBondedDevices();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tracked = _bleService.trackedDevices;
    final connected = _bleService.connectedDevices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои устройства'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _toggleScan,
            icon: Icon(_scanning ? Icons.stop_circle : Icons.bluetooth_searching),
            tooltip: _scanning ? 'Остановить поиск' : 'Найти устройства',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Connected devices section
          if (connected.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'ПОДКЛЮЧЕНЫ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildConnectedDeviceCard(connected[index]),
                childCount: connected.length,
              ),
            ),
          ],

          // Saved (not connected) devices section
          if (tracked.where((d) => !d.isConnected).isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'СОХРАНЁННЫЕ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildSavedDeviceTile(tracked.where((d) => !d.isConnected).elementAt(index)),
                childCount: tracked.where((d) => !d.isConnected).length,
              ),
            ),
          ],

          // Bonded (paired with OS) devices section
          if (_bondedDevices.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'СПАРЕННЫЕ В СИСТЕМЕ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildBondedDeviceTile(_bondedDevices[index]),
                childCount: _bondedDevices.length,
              ),
            ),
          ],

          // Scan results section
          if (_scanning || _scanResults.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'ПОИСК УСТРОЙСТВ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_scanning) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final filteredResults = _scanResults.where((r) {
                    final id = r.device.remoteId.str;
                    return !_bondedDevices.any((b) => b.remoteId.str == id);
                  }).toList();
                  if (index >= filteredResults.length) return null;
                  return _buildScanResultTile(filteredResults[index]);
                },
                childCount: _scanResults.where((r) {
                  final id = r.device.remoteId.str;
                  return !_bondedDevices.any((b) => b.remoteId.str == id);
                }).length,
              ),
            ),
          ],

          // Empty state
          if (tracked.isEmpty && !_scanning && _scanResults.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bluetooth_disabled,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Нет устройств',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Нажмите кнопку поиска, чтобы найти\nфитнес-браслеты, пульсометры и датчики',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _toggleScan,
                      icon: const Icon(Icons.bluetooth_searching, size: 20),
                      label: const Text('Найти устройства'),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceCard(TrackedDevice device) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDeviceDetail(device),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Device icon with glow
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.tertiary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getDeviceIcon(device),
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                // Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            device.brandLabel.isNotEmpty ? '${device.brandLabel} · ${device.categoryLabel}' : device.categoryLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Battery + chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (device.batteryLevel != null)
                      _buildBatteryChip(device.batteryLevel!),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedDeviceTile(TrackedDevice device) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Icon(
          _getDeviceIcon(device),
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        device.lastSeen != null
            ? 'Видели ${DateFormat('d MMM, HH:mm').format(device.lastSeen!)}'
            : device.categoryLabel,
        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (device.batteryLevel != null) _buildBatteryChip(device.batteryLevel!),
          IconButton(
            onPressed: () => _removeDevice(device),
            icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
          ),
        ],
      ),
      onTap: () => _openDeviceDetail(device),
    );
  }

  Widget _buildBondedDeviceTile(BluetoothDevice device) {
    final theme = Theme.of(context);
    final name = device.platformName.isNotEmpty ? device.platformName : 'Спаренное устройство';
    final id = device.remoteId.str;
    final isSaved = _bleService.trackedDevices.any((d) => d.id == id);
    final isConnected = _bleService.isDeviceConnected(id);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isConnected ? Colors.green.withValues(alpha: 0.15) : theme.colorScheme.surfaceContainerHighest,
        ),
        child: Icon(
          Icons.link,
          size: 20,
          color: isConnected ? Colors.green : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        id,
        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: isSaved
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : TextButton(
              onPressed: () => _addBondedDevice(device),
              child: const Text('Добавить'),
            ),
    );
  }

  void _addBondedDevice(BluetoothDevice device) async {
    await _bleService.addSavedDevice(device, null);
    _bleService.connect(device).catchError((_) {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${device.platformName.isNotEmpty ? device.platformName : "Устройство"} добавлено'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildScanResultTile(ScanResult result) {
    final theme = Theme.of(context);
    final name = result.device.platformName.isNotEmpty ? result.device.platformName : 'Неизвестное устройство';
    final brand = TrackedDevice.detectBrand(name);
    final isSaved = _bleService.trackedDevices.any((d) => d.id == result.device.remoteId.str);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primaryContainer,
        ),
        child: Icon(
          Icons.bluetooth,
          size: 20,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${result.device.remoteId.str} · ${result.rssi} dBm${brand != DeviceBrand.unknown ? ' · ${brand.label}' : ''}',
        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: isSaved
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : TextButton(
              onPressed: () => _addDevice(result),
              child: const Text('Добавить'),
            ),
    );
  }

  Widget _buildBatteryChip(int level) {
    Color color;
    IconData icon;
    if (level > 60) {
      color = Colors.green;
      icon = Icons.battery_full;
    } else if (level > 30) {
      color = Colors.orange;
      icon = Icons.battery_5_bar;
    } else {
      color = Colors.red;
      icon = Icons.battery_alert;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 2),
          Text(
            '$level%',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(TrackedDevice device) {
    switch (device.category) {
      case DeviceCategory.smartBand:
        return Icons.watch;
      case DeviceCategory.smartWatch:
        return Icons.watch;
      case DeviceCategory.heartRateMonitor:
        return Icons.favorite;
      case DeviceCategory.cyclingSensor:
        return Icons.pedal_bike;
      case DeviceCategory.smartScale:
        return Icons.monitor_weight_outlined;
      case DeviceCategory.other:
        return Icons.bluetooth;
    }
  }

  Future<void> _addDevice(ScanResult result) async {
    await _bleService.addSavedDevice(result.device, result);
    // Try to connect immediately
    _bleService.connect(result.device).catchError((_) {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Устройство добавлено'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _removeDevice(TrackedDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить устройство?'),
        content: Text('Устройство "${device.name}" будет удалено из списка.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _bleService.removeSavedDevice(device.id);
    }
  }

  void _openDeviceDetail(TrackedDevice device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceDetailScreen(device: device),
      ),
    );
  }
}
