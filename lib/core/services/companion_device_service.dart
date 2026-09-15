import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android CompanionDeviceManager integration via MethodChannel.
/// Mirrors Gadgetbridge's BondingUtil.java for device pairing.
///
/// This provides:
/// - BLE device association (Android 12+)
/// - Persistent device observation (auto-reconnect)
/// - Bond state monitoring
class CompanionDeviceService {
  CompanionDeviceService._();
  static final CompanionDeviceService instance = CompanionDeviceService._();

  static const _channel = MethodChannel('com.zapfit/companion_device');

  final StreamController<CompanionDeviceEvent> _eventController =
      StreamController<CompanionDeviceEvent>.broadcast();

  Stream<CompanionDeviceEvent> get events => _eventController.stream;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onBondStateChanged':
          final args = call.arguments as Map;
          _eventController.add(CompanionDeviceEvent(
            type: CompanionEventType.bondStateChanged,
            deviceId: args['deviceId'] as String,
            bondState: args['bondState'] as int,
          ));
          break;
        case 'onDeviceConnected':
          final args = call.arguments as Map;
          _eventController.add(CompanionDeviceEvent(
            type: CompanionEventType.connected,
            deviceId: args['deviceId'] as String,
          ));
          break;
        case 'onDeviceDisconnected':
          final args = call.arguments as Map;
          _eventController.add(CompanionDeviceEvent(
            type: CompanionEventType.disconnected,
            deviceId: args['deviceId'] as String,
          ));
          break;
        case 'onCompanionPairResult':
          final args = call.arguments as Map;
          _eventController.add(CompanionDeviceEvent(
            type: CompanionEventType.pairResult,
            deviceId: args['deviceId'] as String,
            success: args['success'] as bool,
            message: args['message'] as String?,
          ));
          break;
      }
    });
  }

  /// Request CompanionDeviceManager pairing for a BLE device.
  /// On Android 12+, this uses the CompanionDevice association API.
  /// Returns the bonded MAC address or null if cancelled.
  Future<CompanionPairResult?> pairDevice({
    required String macAddress,
    required String deviceName,
    int deviceType = 2, // BLE = 2
  }) async {
    try {
      final result = await _channel.invokeMethod('pairDevice', {
        'macAddress': macAddress,
        'deviceName': deviceName,
        'deviceType': deviceType,
      });
      return CompanionPairResult(
        success: result['success'] as bool,
        macAddress: result['macAddress'] as String?,
        message: result['message'] as String?,
      );
    } on PlatformException catch (e) {
      debugPrint('CompanionDevice: pair error: $e');
      return CompanionPairResult(success: false, message: e.message);
    }
  }

  /// Start observing a paired device (for auto-reconnect).
  Future<void> startObserving(String deviceId) async {
    try {
      await _channel.invokeMethod('startObserving', {'deviceId': deviceId});
    } catch (e) {
      debugPrint('CompanionDevice: startObserving error: $e');
    }
  }

  /// Stop observing a device.
  Future<void> stopObserving(String deviceId) async {
    try {
      await _channel.invokeMethod('stopObserving', {'deviceId': deviceId});
    } catch (e) {
      debugPrint('CompanionDevice: stopObserving error: $e');
    }
  }

  /// Remove CompanionDevice association.
  Future<void> disassociate(String deviceId) async {
    try {
      await _channel.invokeMethod('disassociate', {'deviceId': deviceId});
    } catch (e) {
      debugPrint('CompanionDevice: disassociate error: $e');
    }
  }

  /// Remove Bluetooth bond.
  Future<bool> removeBond(String macAddress) async {
    try {
      final result = await _channel.invokeMethod('removeBluetoothBond', {
        'macAddress': macAddress,
      });
      return result == true;
    } catch (e) {
      debugPrint('CompanionDevice: removeBond error: $e');
      return false;
    }
  }

  /// Get list of all CompanionDevice associations.
  Future<List<String>> getAssociations() async {
    try {
      final result = await _channel.invokeMethod('getAssociations');
      return List<String>.from(result as List);
    } catch (e) {
      debugPrint('CompanionDevice: getAssociations error: $e');
      return [];
    }
  }

  /// Check if CompanionDeviceManager is available on this device.
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod('isAvailable');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _eventController.close();
  }
}

enum CompanionEventType {
  bondStateChanged,
  connected,
  disconnected,
  pairResult,
}

class CompanionDeviceEvent {
  final CompanionEventType type;
  final String deviceId;
  final int? bondState;
  final bool? success;
  final String? message;

  const CompanionDeviceEvent({
    required this.type,
    required this.deviceId,
    this.bondState,
    this.success,
    this.message,
  });
}

class CompanionPairResult {
  final bool success;
  final String? macAddress;
  final String? message;

  const CompanionPairResult({
    required this.success,
    this.macAddress,
    this.message,
  });
}
