import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zapfit/core/models/health_models.dart';

/// BLE service for Xiaomi/body composition scales.
/// Uses standard Weight Scale (0x181D) and Body Composition (0x181C) services.
class ScaleBleService extends ChangeNotifier {
  // Standard BLE UUIDs for weight scales
  static final Guid _weightScaleService = Guid('181D');
  static final Guid _bodyCompositionService = Guid('181C');
  static final Guid _weightMeasurement = Guid('2A9E');
  static final Guid _bodyCompositionMeasurement = Guid('2A9C');

  final StreamController<ScaleMeasurement> _measurementController =
      StreamController<ScaleMeasurement>.broadcast();
  Stream<ScaleMeasurement> get measurement => _measurementController.stream;

  ScaleMeasurement? _lastMeasurement;
  ScaleMeasurement? get lastMeasurement => _lastMeasurement;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _connectedDeviceName;
  String? get connectedDeviceName => _connectedDeviceName;

  final Map<String, List<StreamSubscription<dynamic>>> _deviceSubscriptions = {};
  BluetoothDevice? _connectedDevice;

  Future<void> startScan() async {
    if (!await _checkPermissions()) {
      throw Exception('Bluetooth permissions not granted');
    }

    // Check if Bluetooth adapter is enabled, request to enable if not
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
      await Future.delayed(const Duration(seconds: 1));
    }

    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    _isScanning = true;
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(
        withServices: [_weightScaleService, _bodyCompositionService],
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      throw Exception('Failed to scan for scales: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Stream<List<ScanResult>> get scanResultsStream => FlutterBluePlus.scanResults;

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  Future<void> connect(BluetoothDevice device) async {
    if (!await _checkPermissions()) return;

    await _cancelSubscriptions();

    await device.connect();
    _connectedDevice = device;
    _isConnected = true;
    _connectedDeviceName = device.platformName.isNotEmpty
        ? device.platformName
        : 'Scale';
    notifyListeners();

    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid == _weightScaleService) {
        _subscribeToWeightScale(device, service);
      } else if (service.uuid == _bodyCompositionService) {
        _subscribeToBodyComposition(device, service);
      }
    }
  }

  Future<void> disconnect() async {
    await _cancelSubscriptions();
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _isConnected = false;
    _connectedDeviceName = null;
    notifyListeners();
  }

  void _subscribeToWeightScale(BluetoothDevice device, BluetoothService service) {
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == _weightMeasurement) {
        characteristic.setNotifyValue(true);
        final sub = characteristic.lastValueStream.listen((value) {
          if (value.isNotEmpty) _parseWeightMeasurement(value);
        });
        _addSubscription(sub);
      }
    }
  }

  void _subscribeToBodyComposition(BluetoothDevice device, BluetoothService service) {
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == _bodyCompositionMeasurement) {
        characteristic.setNotifyValue(true);
        final sub = characteristic.lastValueStream.listen((value) {
          if (value.isNotEmpty) _parseBodyComposition(value);
        });
        _addSubscription(sub);
      }
    }
  }

  /// Parse Weight Scale Measurement characteristic (IEEE 11073-20601).
  void _parseWeightMeasurement(List<int> value) {
    if (value.length < 4) return;

    final flags = value[0];
    final isKg = (flags & 0x01) == 0;
    final isStable = (flags & 0x02) != 0;

    // Weight value is in IEEE 11073 SFLOAT format (16-bit)
    int rawWeight = value[1] | (value[2] << 8);
    if (rawWeight == 0x07FF || rawWeight == 0x0800 || rawWeight == 0x07FE) {
      return; // NaN, NRes, or error
    }

    double weight;
    if (isKg) {
      weight = rawWeight * 0.01; // 0.01 kg resolution
    } else {
      weight = rawWeight * 0.01 * 0.453592; // lbs to kg
    }

    final measurement = ScaleMeasurement(
      weightKg: weight,
      timestamp: DateTime.now(),
      isStable: isStable,
    );

    _lastMeasurement = measurement;
    _measurementController.add(measurement);
    notifyListeners();
  }

  /// Parse Body Composition Measurement characteristic.
  void _parseBodyComposition(List<int> value) {
    if (value.length < 4) return;

    final flags = value[0];
    int offset = 1;

    // Weight (mandatory)
    int rawWeight = value[offset] | (value[offset + 1] << 8);
    offset += 2;
    double weight = rawWeight * 0.01;

    double? bodyFat;
    double? muscleMass;
    double? boneMass;
    double? bodyWater;
    int? visceralFat;

    // Body fat percentage (if bit 1 set)
    if ((flags & 0x02) != 0 && offset + 2 <= value.length) {
      int raw = value[offset] | (value[offset + 1] << 8);
      bodyFat = raw * 0.1;
      offset += 2;
    }

    // Muscle percentage (if bit 8 set)
    if ((flags & 0x80) != 0 && offset + 2 <= value.length) {
      int raw = value[offset] | (value[offset + 1] << 8);
      muscleMass = raw * 0.1;
      offset += 2;
    }

    // Bone mass (if bit 10 set)
    if ((flags & 0x200) != 0 && offset + 2 <= value.length) {
      int raw = value[offset] | (value[offset + 1] << 8);
      boneMass = raw * 0.01;
      offset += 2;
    }

    // Body water (if bit 11 set)
    if ((flags & 0x400) != 0 && offset + 2 <= value.length) {
      int raw = value[offset] | (value[offset + 1] << 8);
      bodyWater = raw * 0.1;
      offset += 2;
    }

    // Visceral fat (if bit 12 set)
    if ((flags & 0x800) != 0 && offset + 1 <= value.length) {
      visceralFat = value[offset];
      offset += 1;
    }

    final measurement = ScaleMeasurement(
      weightKg: weight,
      timestamp: DateTime.now(),
      isStable: true,
      bodyFatPercentage: bodyFat,
      muscleMassKg: muscleMass,
      boneMassKg: boneMass,
      bodyWaterPercentage: bodyWater,
      visceralFatLevel: visceralFat,
    );

    _lastMeasurement = measurement;
    _measurementController.add(measurement);
    notifyListeners();
  }

  /// Convert BLE measurement to WeightRecord for storage.
  WeightRecord toWeightRecord(ScaleMeasurement measurement) {
    return WeightRecord(
      weight: measurement.weightKg,
      date: measurement.timestamp,
      isSynced: false,
      bodyFatPercentage: measurement.bodyFatPercentage,
      muscleMassKg: measurement.muscleMassKg,
      boneMassKg: measurement.boneMassKg,
      bodyWaterPercentage: measurement.bodyWaterPercentage,
      visceralFatLevel: measurement.visceralFatLevel,
    );
  }

  void _addSubscription(StreamSubscription<dynamic> sub) {
    _deviceSubscriptions.putIfAbsent('scale', () => []).add(sub);
  }

  Future<void> _cancelSubscriptions() async {
    for (final subs in _deviceSubscriptions.values) {
      for (final sub in subs) {
        await sub.cancel();
      }
    }
    _deviceSubscriptions.clear();
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

  @override
  void dispose() {
    _cancelSubscriptions();
    _measurementController.close();
    super.dispose();
  }
}

/// Measurement from BLE scale.
class ScaleMeasurement {
  final double weightKg;
  final DateTime timestamp;
  final bool isStable;
  final double? bodyFatPercentage;
  final double? muscleMassKg;
  final double? boneMassKg;
  final double? bodyWaterPercentage;
  final int? visceralFatLevel;

  const ScaleMeasurement({
    required this.weightKg,
    required this.timestamp,
    this.isStable = false,
    this.bodyFatPercentage,
    this.muscleMassKg,
    this.boneMassKg,
    this.bodyWaterPercentage,
    this.visceralFatLevel,
  });

  bool get hasBodyComposition =>
      bodyFatPercentage != null ||
      muscleMassKg != null ||
      boneMassKg != null;
}
