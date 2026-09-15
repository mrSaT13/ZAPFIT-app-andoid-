import 'dart:async';

import 'package:zapfit/core/services/bluetooth_sensor_service.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothSensorsScreen extends StatefulWidget {
  const BluetoothSensorsScreen({super.key});

  @override
  State<BluetoothSensorsScreen> createState() => _BluetoothSensorsScreenState();
}

class _BluetoothSensorsScreenState extends State<BluetoothSensorsScreen> {
  final BluetoothSensorService _service = serviceLocator<BluetoothSensorService>();

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<ScanResult> _results = const [];
  List<String> _saved = const [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _service.stopScan();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final saved = await _service.getSavedDevices();
    if (!mounted) {
      return;
    }
    setState(() {
      _saved = saved;
    });
  }

  Future<void> _toggleScan() async {
    if (_scanning) {
      await _service.stopScan();
      await _scanSubscription?.cancel();
      if (!mounted) {
        return;
      }
      setState(() {
        _scanning = false;
      });
      return;
    }

    setState(() {
      _scanning = true;
      _results = const [];
    });

    _scanSubscription?.cancel();
    _scanSubscription = _service.scan().listen((results) {
      if (!mounted) return;
      setState(() {
        _results = results;
      });
      // Автоподключение к сохранённым устройствам при обнаружении
      for (final result in results) {
        final id = result.device.remoteId.str;
        if (_saved.contains(id) && !_service.isDeviceConnected(id)) {
          _service.connect(result.device).catchError((_) {});
        }
      }
    });
  }

  Future<void> _saveDevice(ScanResult result) async {
    await _service.addSavedDevice(result.device, result);
    await _loadSaved();
  }

  Future<void> _removeDevice(String id) async {
    await _service.removeSavedDevice(id);
    await _loadSaved();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bluetoothSensors),
        actions: [
          TextButton(
            onPressed: _toggleScan,
            child: Text(_scanning ? l10n.stop : l10n.scan),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(title: Text(l10n.savedDevices)),
          if (_saved.isEmpty)
            ListTile(
              title: Text(l10n.noSavedSensors),
            ),
          ..._saved.map(
            (id) {
              final connected = _service.isDeviceConnected(id);
              return ListTile(
                leading: Icon(
                  connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: connected ? Colors.green : Colors.grey,
                ),
                title: Text(id),
                subtitle: Text(connected ? 'Подключён' : 'Не подключён'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (connected)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    IconButton(
                      onPressed: () => _removeDevice(id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          ListTile(title: Text(l10n.nearbyDevices)),
          if (_results.isEmpty && _scanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Поиск устройств...', style: TextStyle(color: Colors.grey))),
            ),
          ..._results.where((r) => r.device.platformName.trim().isNotEmpty).map((result) {
            final name = result.device.platformName.trim();
            final id = result.device.remoteId.str;
            final rssi = result.rssi;
            return ListTile(
              leading: const Icon(Icons.bluetooth),
              title: Text(name),
              subtitle: Text('$id · ${rssi} dBm'),
              trailing: TextButton(
                onPressed: () => _saveDevice(result),
                child: Text(l10n.add),
              ),
            );
          }),
          if (_results.any((r) => r.device.platformName.trim().isEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Ещё ${_results.where((r) => r.device.platformName.trim().isEmpty).length} устройств без имени (скрыты)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
