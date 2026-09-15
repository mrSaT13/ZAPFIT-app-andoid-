import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_model.dart';

/// Describes what a device can do — mirrors Gadgetbridge's DeviceCoordinator interface.
/// Each device family (Xiaomi, Huawei, Polar, etc.) implements this.
abstract class DeviceCoordinator {
  /// Unique identifier for this coordinator type.
  String get id;

  /// Human-readable name (e.g. "Xiaomi Mi Band", "Huawei Band").
  String get name;

  /// Which brand this coordinator handles.
  DeviceBrand get brand;

  /// Bonding style constants (same as Gadgetbridge).
  static const int bondingNone = 0;
  static const int bondingBond = 1;
  static const int bondingAsk = 2;
  static const int bondingRequireKey = 3;
  static const int bondingLazy = 4;

  /// Does this coordinator support the given BLE scan result?
  bool supports(ScanResult candidate);

  /// Bonding style for this device family.
  int get bondingStyle;

  // --- Capability flags (like Gadgetbridge's supports* methods) ---

  bool get supportsHeartRate => false;
  bool get supportsRealtimeHeartRate => false;
  bool get supportsManualHeartRate => false;
  bool get supportsStepCounter => false;
  bool get supportsSleepMeasurement => false;
  bool get supportsDataFetching => false;
  bool get supportsActivityTracking => false;
  bool get supportsFindDevice => false;
  bool get supportsAlarms => false;
  int get alarmSlotCount => 0;
  bool get supportsSmartWakeup => false;
  bool get supportsWeather => false;
  bool get supportsMusicInfo => false;
  bool get supportsNotifications => true;
  bool get supportsRealtimeData => false;
  bool get supportsFirmwareUpdate => false;
  bool get supportsWidgets => false;
  bool get supportsStressMeasurement => false;
  bool get supportsSpo2 => false;
  bool get supportsTemperatureMeasurement => false;

  /// Maximum number of reminders on the device.
  int get reminderSlotCount => 0;

  /// Manufacturer name string.
  String get manufacturer;

  /// Device kind for categorization.
  DeviceKind get deviceKind;

  /// Recommended reconnection delay in milliseconds.
  int get reconnectionDelayMs => 3000;

  /// Scan filter UUIDs this device family advertises.
  List<Guid> get scanFilterUuids => [];

  /// Returns device-specific settings screen definitions.
  List<DeviceSettingGroup> getDeviceSettings(String deviceId) => [];
}

/// Categorizes device types (mirrors Gadgetbridge's DeviceKind enum).
enum DeviceKind {
  unknown,
  watch,
  fitnessBand,
  heartRateMonitor,
  chestStrap,
  smartWatch,
  cyclingSensor,
  smartScale,
  ring,
  thermometer,
  headphones,
  smartGlasses,
}

/// A group of settings shown on the device settings screen.
class DeviceSettingGroup {
  final String title;
  final List<DeviceSetting> settings;

  const DeviceSettingGroup({required this.title, required this.settings});
}

/// A single configurable setting on the device.
class DeviceSetting {
  final String key;
  final String label;
  final DeviceSettingType type;
  final dynamic defaultValue;
  final List<DeviceSettingOption>? options;
  final String? unit;
  final int? min;
  final int? max;

  const DeviceSetting({
    required this.key,
    required this.label,
    required this.type,
    this.defaultValue,
    this.options,
    this.unit,
    this.min,
    this.max,
  });
}

enum DeviceSettingType {
  toggle,
  dropdown,
  number,
  text,
  time,
}

class DeviceSettingOption {
  final String label;
  final dynamic value;

  const DeviceSettingOption({required this.label, required this.value});
}
