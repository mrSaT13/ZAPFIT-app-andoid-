import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:zapfit/core/models/device_coordinator.dart';
import 'package:zapfit/core/models/device_model.dart';

/// Coordinator for Polar chest straps (H7, H9, H10).
/// Uses standard BLE Heart Rate service (0x180D) + Polar-specific services.
class PolarCoordinator extends DeviceCoordinator {
  @override
  String get id => 'polar';

  @override
  String get name => 'Polar HR Monitor';

  @override
  DeviceBrand get brand => DeviceBrand.polar;

  @override
  int get bondingStyle => DeviceCoordinator.bondingNone;

  @override
  bool get supportsHeartRate => true;

  @override
  bool get supportsRealtimeHeartRate => true;

  @override
  bool get supportsManualHeartRate => true;

  @override
  bool get supportsDataFetching => true;

  @override
  bool get supportsActivityTracking => true;

  @override
  bool get supportsFindDevice => false;

  @override
  String get manufacturer => 'Polar';

  @override
  DeviceKind get deviceKind => DeviceKind.chestStrap;

  @override
  int get reconnectionDelayMs => 2000;

  // Polar proprietary service
  static final Guid _polarService = Guid('0000180d-0000-1000-8000-00805f9b34fb');

  @override
  List<Guid> get scanFilterUuids => [_polarService];

  @override
  bool supports(ScanResult candidate) {
    final name = candidate.device.platformName.toLowerCase();
    if (name.startsWith('polar h') || name.startsWith('polar h10') || name.startsWith('polar h9')) {
      return true;
    }
    return false;
  }

  @override
  List<DeviceSettingGroup> getDeviceSettings(String deviceId) {
    return [
      DeviceSettingGroup(title: 'Пульс', settings: [
        const DeviceSetting(key: 'hr_broadcast', label: 'Broadcast HR', type: DeviceSettingType.toggle, defaultValue: true),
      ]),
    ];
  }
}
