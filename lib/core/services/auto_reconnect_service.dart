import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auto-reconnect service for saved BLE devices.
/// Mirrors Gadgetbridge's reconnect logic:
/// - Monitors ACL disconnect events
/// - Reconnects on connection loss
/// - Uses exponential backoff
/// - Respects device-specific reconnection delays
class AutoReconnectService {
  AutoReconnectService._();
  static final AutoReconnectService instance = AutoReconnectService._();

  static const String _reconnectEnabledKey = 'auto_reconnect_enabled';
  static const String _savedDevicesKey = 'saved_reconnect_devices';

  bool _enabled = true;
  bool _running = false;
  Timer? _reconnectTimer;
  final Map<String, int> _reconnectAttempts = {};
  final Map<String, int> _deviceDelays = {};
  final Set<String> _permanentlyFailed = {};

  bool get isEnabled => _enabled;
  bool get isRunning => _running;

  // Callback when a device reconnects
  Function(BluetoothDevice device)? onReconnected;
  Function(String deviceId, String error)? onReconnectFailed;

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _enabled = _prefs!.getBool(_reconnectEnabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_reconnectEnabledKey, enabled);
    if (!enabled) stop();
  }

  /// Register a device for auto-reconnect.
  Future<void> registerDevice(String deviceId, {int delayMs = 3000}) async {
    _deviceDelays[deviceId] = delayMs;
    _permanentlyFailed.remove(deviceId);
    _reconnectAttempts.remove(deviceId);
    _saveDevices();
  }

  /// Unregister a device from auto-reconnect.
  Future<void> unregisterDevice(String deviceId) async {
    _deviceDelays.remove(deviceId);
    _reconnectAttempts.remove(deviceId);
    _permanentlyFailed.remove(deviceId);
    _saveDevices();
  }

  /// Start monitoring and auto-reconnecting.
  void start() {
    if (_running || !_enabled) return;
    _running = true;

    // Listen for Bluetooth state changes
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        _attemptReconnectAll();
      }
    });

    // Listen for device disconnections
    FlutterBluePlus.connectedDevices.forEach((device) {
      _monitorDevice(device);
    });

    // Periodic check every 15 seconds
    _reconnectTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _attemptReconnectAll();
    });

    debugPrint('AutoReconnect: started');
  }

  void stop() {
    _running = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    debugPrint('AutoReconnect: stopped');
  }

  void _monitorDevice(BluetoothDevice device) {
    final deviceId = device.remoteId.str;
    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        debugPrint('AutoReconnect: device $deviceId disconnected, scheduling reconnect');
        _scheduleReconnect(deviceId);
      }
    });
  }

  void _scheduleReconnect(String deviceId) {
    if (!_enabled || _permanentlyFailed.contains(deviceId)) return;
    if (!_deviceDelays.containsKey(deviceId)) return;

    final baseDelay = _deviceDelays[deviceId] ?? 3000;
    final attempts = _reconnectAttempts[deviceId] ?? 0;
    // Exponential backoff: delay * 2^attempts, capped at 60 seconds
    final delay = (baseDelay * (1 << attempts.clamp(0, 4))).clamp(0, 60000);

    _reconnectAttempts[deviceId] = attempts + 1;

    debugPrint('AutoReconnect: will retry $deviceId in ${delay}ms (attempt ${attempts + 1})');

    Future.delayed(Duration(milliseconds: delay), () {
      _tryReconnect(deviceId);
    });
  }

  Future<void> _tryReconnect(String deviceId) async {
    if (!_enabled || _permanentlyFailed.contains(deviceId)) return;

    try {
      final status = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      final granted = status[Permission.bluetoothConnect]?.isGranted ?? false;
      if (!granted) {
        debugPrint('AutoReconnect: no BT permissions for $deviceId');
        return;
      }

      final device = BluetoothDevice.fromId(deviceId);
      await device.connect(timeout: const Duration(seconds: 10));

      // Reset attempts on success
      _reconnectAttempts.remove(deviceId);
      debugPrint('AutoReconnect: successfully reconnected to $deviceId');
      onReconnected?.call(device);

      // Monitor for future disconnections
      _monitorDevice(device);
    } catch (e) {
      debugPrint('AutoReconnect: failed to reconnect $deviceId: $e');
      final attempts = _reconnectAttempts[deviceId] ?? 0;

      if (attempts >= 10) {
        debugPrint('AutoReconnect: giving up on $deviceId after $attempts attempts');
        _permanentlyFailed.add(deviceId);
        onReconnectFailed?.call(deviceId, 'Too many failed attempts');
      } else {
        _scheduleReconnect(deviceId);
      }
    }
  }

  Future<void> _attemptReconnectAll() async {
    if (!_enabled) return;
    for (final deviceId in _deviceDelays.keys) {
      final isAlreadyConnected = FlutterBluePlus.connectedDevices
          .any((d) => d.remoteId.str == deviceId);
      if (!isAlreadyConnected && !_permanentlyFailed.contains(deviceId)) {
        _tryReconnect(deviceId);
      }
    }
  }

  /// Reset reconnect state for a device (e.g. after user manually connects).
  void resetAttempts(String deviceId) {
    _reconnectAttempts.remove(deviceId);
    _permanentlyFailed.remove(deviceId);
  }

  Future<void> _saveDevices() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setStringList(_savedDevicesKey, _deviceDelays.keys.toList());
  }

  Future<void> loadSavedDevices() async {
    _prefs ??= await SharedPreferences.getInstance();
    final saved = _prefs!.getStringList(_savedDevicesKey) ?? [];
    for (final id in saved) {
      _deviceDelays[id] = 3000;
    }
  }
}
