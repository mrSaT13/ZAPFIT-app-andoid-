import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zapfit/core/models/device_model.dart';
import 'package:zapfit/core/models/device_coordinator.dart';
import 'package:zapfit/core/coordinators/coordinator_registry.dart';
import 'package:zapfit/core/services/xiaomi_ble_auth_service.dart';
import 'package:zapfit/core/services/auto_reconnect_service.dart';
import 'package:zapfit/core/services/companion_device_service.dart';

enum BluetoothSensorType { heartRate, cadence, power, unknown }

class BluetoothSensorService extends ChangeNotifier {
  static const String _savedDeviceIdsKey = 'saved_ble_device_ids';
  static const String _savedDevicesMetaKey = 'saved_ble_devices_meta';

  // Standard BLE Service UUIDs
  static final Guid _heartRateService = Guid('180D');
  static final Guid _cscService = Guid('1816');   // Cycling Speed & Cadence
  static final Guid _rscService = Guid('1814');   // Running Speed & Cadence
  static final Guid _cyclingPowerService = Guid('1818');
  static final Guid _batteryService = Guid('180F');

  // Xiaomi BLE Auth Service UUIDs (for capability detection)
  // 0xFEE1 = Mi Band 2 Service (main auth), 0xFEE0 = old Huami service
  static final Guid _xiaomiAuthService = Guid('0000fee1-0000-1000-8000-00805f9b34fb');
  static final Guid _xiaomiAuthServiceOld = Guid('0000fee0-0000-1000-8000-00805f9b34fb');

  // Standard BLE Characteristic UUIDs
  static final Guid _heartRateMeasurement = Guid('2A37');
  static final Guid _cscMeasurement = Guid('2A5B');
  static final Guid _rscMeasurement = Guid('2A53');  // Running Speed & Cadence Measurement
  static final Guid _cyclingPowerMeasurement = Guid('2A63');
  static final Guid _batteryLevel = Guid('2A19');

  final StreamController<int> _heartRateController = StreamController<int>.broadcast();
  final StreamController<int> _cadenceController = StreamController<int>.broadcast();
  final StreamController<double> _powerController = StreamController<double>.broadcast();
  final StreamController<int> _batteryController = StreamController<int>.broadcast();

  Stream<int> get heartRate => _heartRateController.stream;
  Stream<int> get cadence => _cadenceController.stream;
  Stream<double> get power => _powerController.stream;
  Stream<int> get battery => _batteryController.stream;

  int? _lastHeartRate;
  int? get lastHeartRate => _lastHeartRate;
  final List<int> _heartRateHistory = [];
  List<int> get heartRateHistory => List.unmodifiable(_heartRateHistory);
  DateTime? _lastHrTimestamp;
  DateTime? get lastHrTimestamp => _lastHrTimestamp;

  final Map<String, List<StreamSubscription<dynamic>>> _deviceSubscriptions = {};
  int? _lastCrankRevolutions;
  int? _lastCrankEventTime;

  final Map<String, BluetoothDevice> _connectedDevices = {};
  final Set<String> _savedDeviceIds = {};
  final Map<String, TrackedDevice> _trackedDevices = {};
  SharedPreferences? _prefs;

  // Scanning state
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => _scanResults;

  List<TrackedDevice> get trackedDevices => _trackedDevices.values.toList();
  List<TrackedDevice> get connectedDevices =>
      _trackedDevices.values.where((d) => d.isConnected).toList();

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final saved = _prefs!.getStringList(_savedDeviceIdsKey) ?? <String>[];
    _savedDeviceIds.addAll(saved);

    // Load device metadata
    final metaJson = _prefs!.getString(_savedDevicesMetaKey);
    if (metaJson != null) {
      try {
        final decoded = json.decode(metaJson) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _trackedDevices[entry.key] = TrackedDevice.fromJson(entry.value as Map<String, dynamic>);
        }
      } catch (_) {}
    }

    // Initialize auto-reconnect
    await AutoReconnectService.instance.init();
    await AutoReconnectService.instance.loadSavedDevices();
    AutoReconnectService.instance.onReconnected = (device) {
      final deviceId = device.remoteId.str;
      debugPrint('BLE: Auto-reconnected to $deviceId');
      _handleReconnection(device);
    };

    // Initialize CompanionDeviceManager
    await CompanionDeviceService.instance.init();
  }

  Future<void> _saveDevicesMeta() async {
    _prefs ??= await SharedPreferences.getInstance();
    final Map<String, dynamic> map = {};
    for (final entry in _trackedDevices.entries) {
      map[entry.key] = entry.value.toJson();
    }
    await _prefs!.setString(_savedDevicesMetaKey, json.encode(map));
  }

  BluetoothSensorType identifyDevice(ScanResult result) {
    final uuids = result.advertisementData.serviceUuids;
    if (uuids.contains(_heartRateService)) return BluetoothSensorType.heartRate;
    if (uuids.contains(_cscService) || uuids.contains(_rscService)) return BluetoothSensorType.cadence;
    if (uuids.contains(_cyclingPowerService)) return BluetoothSensorType.power;
    return BluetoothSensorType.unknown;
  }

  Future<void> startScan({bool filterByServices = true}) async {
    if (!await _checkPermissions()) {
      throw Exception('Bluetooth permissions not granted');
    }

    // Check if Bluetooth adapter is enabled, request to enable if not
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
      // Wait a moment for Bluetooth to fully enable
      await Future.delayed(const Duration(seconds: 1));
    }

    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    _isScanning = true;
    _scanResults = [];
    notifyListeners();

    try {
      if (filterByServices) {
        // Use coordinator scan filters for better device detection.
        // Android limits to 5 service UUID filters — cap to avoid
        // "Failed to start scan" on devices with many coordinators.
        var filterUuids = CoordinatorRegistry.instance.getAllScanFilterUuids();
        if (filterUuids.length > 5) filterUuids = filterUuids.take(5).toList();
        await FlutterBluePlus.startScan(
          withServices: filterUuids.isNotEmpty ? filterUuids : [
            _heartRateService, _cscService, _rscService, _cyclingPowerService,
          ],
          timeout: const Duration(seconds: 15),
          androidUsesFineLocation: true,
        );
      } else {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 15),
          androidUsesFineLocation: true,
        );
      }
    } catch (e) {
      throw Exception('Failed to start BLE scan: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<bool> _checkPermissions() async {
    if (!Platform.isAndroid) return true;

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final locationGranted = statuses[Permission.location]?.isGranted ?? false;

    return (scanGranted && connectGranted) || locationGranted;
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  Stream<List<ScanResult>> get scanResultsStream => FlutterBluePlus.scanResults;

  Stream<List<ScanResult>> scan({Duration timeout = const Duration(seconds: 8)}) {
    startScan(filterByServices: false).catchError((_) {});
    return scanResultsStream;
  }

  void updateScanResults(List<ScanResult> results) {
    _scanResults = results;
    notifyListeners();
  }

  Future<List<String>> getSavedDevices() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getStringList(_savedDeviceIdsKey) ?? const [];
  }

  Future<void> addSavedDevice(BluetoothDevice device, ScanResult? scanResult) async {
    _prefs ??= await SharedPreferences.getInstance();
    final deviceId = device.remoteId.str;
    _savedDeviceIds.add(deviceId);
    await _prefs!.setStringList(_savedDeviceIdsKey, _savedDeviceIds.toList());

    // Create tracked device metadata
    final name = device.platformName.isNotEmpty ? device.platformName : 'Unknown Device';
    final brand = TrackedDevice.detectBrand(name);
    final serviceUuids = scanResult?.advertisementData.serviceUuids.map((g) => g.str).toList() ?? [];
    final category = TrackedDevice.detectCategory(name, serviceUuids);

    // Auto-detect coordinator
    final coordinator = scanResult != null ? CoordinatorRegistry.instance.resolve(scanResult) : null;
    final coordinatorId = coordinator?.id;

    _trackedDevices[deviceId] = TrackedDevice(
      id: deviceId,
      name: name,
      brand: brand,
      category: category,
      lastSeen: DateTime.now(),
      rssi: scanResult?.rssi,
      coordinatorId: coordinatorId,
    );
    await _saveDevicesMeta();

    // Register for auto-reconnect
    AutoReconnectService.instance.registerDevice(deviceId, delayMs: coordinator?.reconnectionDelayMs ?? 3000);

    // Start observing via CompanionDeviceManager (Android 12+)
    CompanionDeviceService.instance.startObserving(deviceId);

    notifyListeners();
  }

  Future<void> removeSavedDevice(String deviceId) async {
    _prefs ??= await SharedPreferences.getInstance();
    _savedDeviceIds.remove(deviceId);
    await _prefs!.setStringList(_savedDeviceIdsKey, _savedDeviceIds.toList());
    _trackedDevices.remove(deviceId);
    await _saveDevicesMeta();

    // Unregister from auto-reconnect
    AutoReconnectService.instance.unregisterDevice(deviceId);
    CompanionDeviceService.instance.stopObserving(deviceId);

    notifyListeners();
  }

  Future<void> connect(BluetoothDevice device) async {
    if (!await _checkPermissions()) return;

    final deviceId = device.remoteId.str;
    await _cancelSubscriptions(deviceId);

    await device.connect();
    _connectedDevices[deviceId] = device;
    _savedDeviceIds.add(deviceId);
    await _prefs?.setStringList(_savedDeviceIdsKey, _savedDeviceIds.toList());

    // Reset auto-reconnect attempts (user connected successfully)
    AutoReconnectService.instance.resetAttempts(deviceId);

    // Monitor disconnection for auto-reconnect
    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        debugPrint('BLE: Device $deviceId disconnected');
        _connectedDevices.remove(deviceId);
        final existing = _trackedDevices[deviceId];
        if (existing != null) {
          _trackedDevices[deviceId] = existing.copyWith(isConnected: false);
        }
        _saveDevicesMeta();
        notifyListeners();
      }
    });

    // Update tracked device
    final existing = _trackedDevices[deviceId];
    final name = device.platformName.isNotEmpty ? device.platformName : (existing?.name ?? 'Unknown');
    _trackedDevices[deviceId] = (existing ?? TrackedDevice(id: deviceId, name: name)).copyWith(
      name: name,
      isConnected: true,
      lastSeen: DateTime.now(),
    );
    await _saveDevicesMeta();
    notifyListeners();

    final services = await device.discoverServices();
    debugPrint('BLE: Discovered ${services.length} services for ${device.platformName}');
    final capabilities = <String, dynamic>{};

    // Use coordinator for capability detection if available
    final coordinatorId = existing?.coordinatorId;
    final coordinator = coordinatorId != null ? CoordinatorRegistry.instance.getById(coordinatorId) : null;

    for (final service in services) {
      debugPrint('BLE:   Service: ${service.uuid}');
      if (service.uuid == _heartRateService) {
        _subscribeToHeartRate(deviceId, service);
        capabilities['heartRate'] = true;
      } else if (service.uuid == _cscService || service.uuid == _rscService) {
        _subscribeToCSC(deviceId, service);
        capabilities['cadence'] = true;
      } else if (service.uuid == _cyclingPowerService) {
        _subscribeToPower(deviceId, service);
        capabilities['power'] = true;
      } else if (service.uuid == _batteryService) {
        _subscribeToBattery(deviceId, service);
        capabilities['battery'] = true;
      } else if (service.uuid == _xiaomiAuthService || service.uuid == _xiaomiAuthServiceOld) {
        capabilities['xiaomiAuth'] = true;
        debugPrint('BLE:   Found Xiaomi auth service');
      }

      // Check coordinator-specific services
      if (coordinator != null) {
        for (final filterUuid in coordinator.scanFilterUuids) {
          if (service.uuid == filterUuid) {
            capabilities['vendorService'] = true;
            debugPrint('BLE:   Found vendor service: ${service.uuid}');
          }
        }
      }
    }

    // Add coordinator-declared capabilities
    if (coordinator != null) {
      if (coordinator.supportsStepCounter) capabilities['steps'] = true;
      if (coordinator.supportsSleepMeasurement) capabilities['sleep'] = true;
      if (coordinator.supportsDataFetching) capabilities['dataFetch'] = true;
      if (coordinator.supportsFindDevice) capabilities['findDevice'] = true;
      if (coordinator.supportsAlarms) capabilities['alarms'] = true;
      if (coordinator.supportsWeather) capabilities['weather'] = true;
      if (coordinator.supportsMusicInfo) capabilities['music'] = true;
      if (coordinator.supportsStressMeasurement) capabilities['stress'] = true;
      if (coordinator.supportsSpo2) capabilities['spo2'] = true;
      if (coordinator.supportsTemperatureMeasurement) capabilities['temperature'] = true;
    }

    // Attempt Xiaomi BLE auth if device has the capability
    if (capabilities.containsKey('xiaomiAuth')) {
      _tryXiaomiAuth(deviceId, device);
    }

    // Update capabilities
    _trackedDevices[deviceId] = _trackedDevices[deviceId]!.copyWith(
      capabilities: capabilities,
    );
    await _saveDevicesMeta();
    notifyListeners();
  }

  Future<void> disconnect(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    await _cancelSubscriptions(deviceId);
    await device.disconnect();
    _connectedDevices.remove(deviceId);

    _trackedDevices[deviceId] = _trackedDevices[deviceId]?.copyWith(
      isConnected: false,
    ) ?? TrackedDevice(id: deviceId, name: 'Unknown', isConnected: false);

    // Reset auto-reconnect attempts (user disconnected intentionally)
    AutoReconnectService.instance.resetAttempts(deviceId);

    await _saveDevicesMeta();
    notifyListeners();
  }

  Future<void> _handleReconnection(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;

    // Cancel stale subscriptions from before the disconnect
    await _cancelSubscriptions(deviceId);

    // Track as connected
    _connectedDevices[deviceId] = device;

    // Monitor for future disconnections
    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        debugPrint('BLE: Device $deviceId disconnected (post-reconnect)');
        _connectedDevices.remove(deviceId);
        final existing = _trackedDevices[deviceId];
        if (existing != null) {
          _trackedDevices[deviceId] = existing.copyWith(isConnected: false);
        }
        _saveDevicesMeta();
        notifyListeners();
      }
    });

    // Update tracked device status
    final existing = _trackedDevices[deviceId];
    _trackedDevices[deviceId] = (existing ?? TrackedDevice(id: deviceId, name: 'Unknown')).copyWith(
      isConnected: true,
      lastSeen: DateTime.now(),
    );
    await _saveDevicesMeta();

    // Re-discover services and re-subscribe to notifications
    try {
      final services = await device.discoverServices();
      debugPrint('BLE: Re-discovered ${services.length} services for $deviceId after reconnect');

      for (final service in services) {
        if (service.uuid == _heartRateService) {
          _subscribeToHeartRate(deviceId, service);
        } else if (service.uuid == _cscService || service.uuid == _rscService) {
          _subscribeToCSC(deviceId, service);
        } else if (service.uuid == _cyclingPowerService) {
          _subscribeToPower(deviceId, service);
        } else if (service.uuid == _batteryService) {
          _subscribeToBattery(deviceId, service);
        }
      }

      debugPrint('BLE: Re-subscribed to notifications for $deviceId');
    } catch (e) {
      debugPrint('BLE: Failed to re-discover services after reconnect: $e');
    }

    notifyListeners();
  }

  Future<void> _cancelSubscriptions(String deviceId) async {
    final subs = _deviceSubscriptions[deviceId];
    if (subs != null) {
      for (final sub in subs) {
        await sub.cancel();
      }
      _deviceSubscriptions.remove(deviceId);
    }
  }

  void _addSubscription(String deviceId, StreamSubscription<dynamic> sub) {
    _deviceSubscriptions.putIfAbsent(deviceId, () => []).add(sub);
  }

  void _subscribeToHeartRate(String deviceId, BluetoothService service) {
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == _heartRateMeasurement) {
        characteristic.setNotifyValue(true);
        final sub = characteristic.lastValueStream.listen((value) {
          if (value.isNotEmpty) _parseHeartRate(value);
        });
        _addSubscription(deviceId, sub);
      }
    }
  }

  void _subscribeToCSC(String deviceId, BluetoothService service) {
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == _cscMeasurement || characteristic.uuid == _rscMeasurement) {
        characteristic.setNotifyValue(true);
        final sub = characteristic.lastValueStream.listen((value) {
          if (value.isNotEmpty) {
            if (characteristic.uuid == _rscMeasurement) {
              _parseRSC(value);
            } else {
              _parseCSC(value);
            }
          }
        });
        _addSubscription(deviceId, sub);
      }
    }
  }

  void _subscribeToPower(String deviceId, BluetoothService service) {
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == _cyclingPowerMeasurement) {
        characteristic.setNotifyValue(true);
        final sub = characteristic.lastValueStream.listen((value) {
          if (value.isNotEmpty) _parsePower(value);
        });
        _addSubscription(deviceId, sub);
      }
    }
  }

  void _subscribeToBattery(String deviceId, BluetoothService service) {
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == _batteryLevel) {
        // Read current battery level
        characteristic.read().then((value) {
          if (value.isNotEmpty) {
            final level = value[0];
            _batteryController.add(level);
            final existing = _trackedDevices[deviceId];
            if (existing != null) {
              _trackedDevices[deviceId] = existing.copyWith(batteryLevel: level);
            }
            _saveDevicesMeta();
            notifyListeners();
          }
        });

        // Subscribe to battery changes
        if (characteristic.properties.notify) {
          characteristic.setNotifyValue(true);
          final sub = characteristic.lastValueStream.listen((value) {
            if (value.isNotEmpty) {
              final level = value[0];
              _batteryController.add(level);
              final existing = _trackedDevices[deviceId];
              if (existing != null) {
                _trackedDevices[deviceId] = existing.copyWith(batteryLevel: level);
              }
              _saveDevicesMeta();
              notifyListeners();
            }
          });
          _addSubscription(deviceId, sub);
        }
      }
    }
  }

  void _parseHeartRate(List<int> value) {
    final flags = value[0];
    final isUint16 = (flags & 0x01) != 0;
    int hr = isUint16 ? (value[1] + (value[2] << 8)) : value[1];
    _lastHeartRate = hr;
    _lastHrTimestamp = DateTime.now();
    _heartRateHistory.add(hr);
    if (_heartRateHistory.length > 300) _heartRateHistory.removeAt(0);
    _heartRateController.add(hr);
    notifyListeners();
  }

  void _parsePower(List<int> value) {
    if (value.length >= 4) {
      int power = value[2] + (value[3] << 8);
      _powerController.add(power.toDouble());
    }
  }

  void _parseCSC(List<int> value) {
    final flags = value[0];
    final hasWheelData = (flags & 0x01) != 0;
    final hasCrankData = (flags & 0x02) != 0;

    int offset = 1;
    if (hasWheelData) offset += 6;

    if (hasCrankData && value.length >= offset + 4) {
      int cumulativeCrankRevolutions = value[offset] + (value[offset + 1] << 8);
      int lastCrankEventTime = value[offset + 2] + (value[offset + 3] << 8);

      if (_lastCrankRevolutions != null && _lastCrankEventTime != null) {
        int revDiff = cumulativeCrankRevolutions - _lastCrankRevolutions!;
        if (revDiff < 0) revDiff += 65536;

        int timeDiff = lastCrankEventTime - _lastCrankEventTime!;
        if (timeDiff < 0) timeDiff += 65536;

        if (timeDiff > 0 && revDiff >= 0) {
          double rpm = (revDiff * 1024 * 60) / timeDiff;
          if (rpm < 300) {
            _cadenceController.add(rpm.round());
          }
        }
      }
      _lastCrankRevolutions = cumulativeCrankRevolutions;
      _lastCrankEventTime = lastCrankEventTime;
    }
  }

  void _parseRSC(List<int> value) {
    // RSC Measurement format:
    // Byte 0: Flags (bit 0 = instantaneous stride length present, bit 1 = total distance present)
    // Byte 1-2: Instantaneous Speed (uint16, resolution 1/256 m/s)
    // Byte 3: Instantaneous Cadence (uint8, resolution 1/2 steps/min)
    // [Optional] Byte 4-5: Instantaneous Stride Length (uint16, resolution 1/100 m)
    // [Optional] Byte 6-8: Total Distance (uint24, meters)
    if (value.length < 4) return;
    final flags = value[0];
    final hasStrideLength = (flags & 0x01) != 0;

    // Instantaneous Cadence is at byte 3, resolution 1/2 steps/min
    final cadenceHalfSteps = value[3];
    final cadence = cadenceHalfSteps * 2; // Convert to steps/min

    if (cadence > 0 && cadence < 300) {
      _cadenceController.add(cadence);
    }
  }

  /// Attempt Xiaomi BLE authentication using the professional auth service.
  /// Supports both ECDSA (Amazfit Bip) and HMAC-SHA256 (Mi Band 4+).
  Future<void> _tryXiaomiAuth(String deviceId, BluetoothDevice device) async {
    try {
      final authResult = await XiaomiBleAuthService.instance.authenticate(device);

      if (authResult.isSuccess) {
        debugPrint('BLE: Xiaomi auth success: ${authResult.message}');
        // Update capabilities to show auth succeeded
        final existing = _trackedDevices[deviceId];
        if (existing != null) {
          final caps = Map<String, dynamic>.from(existing.capabilities);
          caps['xiaomiAuth'] = true;
          caps['xiaomiAuthStatus'] = 'authenticated';
          _trackedDevices[deviceId] = existing.copyWith(capabilities: caps);
          await _saveDevicesMeta();
          notifyListeners();
        }
      } else {
        debugPrint('BLE: Xiaomi auth failed: ${authResult.message}');
        // Still mark as having xiaomi auth capability for UI
        final existing = _trackedDevices[deviceId];
        if (existing != null) {
          final caps = Map<String, dynamic>.from(existing.capabilities);
          caps['xiaomiAuth'] = true;
          caps['xiaomiAuthStatus'] = 'failed';
          _trackedDevices[deviceId] = existing.copyWith(capabilities: caps);
          await _saveDevicesMeta();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('BLE: Xiaomi auth attempt failed: $e');
    }
  }

  Future<void> reconnectAllSaved() async {
    // Start auto-reconnect service
    AutoReconnectService.instance.start();

    final saved = await getSavedDevices();
    for (final id in saved) {
      if (_connectedDevices.containsKey(id)) continue;
      try {
        final device = BluetoothDevice.fromId(id);
        await connect(device);
        debugPrint('BLE: Auto-connected to $id');
      } catch (e) {
        debugPrint('BLE: Failed to auto-connect to $id: $e');
      }
    }
  }

  List<String> get connectedDeviceIds => _connectedDevices.keys.toList();

  bool isDeviceConnected(String deviceId) => _connectedDevices.containsKey(deviceId);

  @override
  void dispose() {
    for (final deviceSubs in _deviceSubscriptions.values) {
      for (final sub in deviceSubs) {
        sub.cancel();
      }
    }
    _deviceSubscriptions.clear();
    _heartRateController.close();
    _cadenceController.close();
    _powerController.close();
    _batteryController.close();
    AutoReconnectService.instance.stop();
    super.dispose();
  }
}
