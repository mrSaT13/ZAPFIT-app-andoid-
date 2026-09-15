import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:zapfit/core/models/device_coordinator.dart';
import 'package:zapfit/core/models/device_model.dart';

/// Coordinator for Huawei/Honor Band and Watch devices.
/// Uses proprietary Huawei BLE protocol.
class HuaweiCoordinator extends DeviceCoordinator {
  @override
  String get id => 'huawei';

  @override
  String get name => 'Huawei Band/Watch';

  @override
  DeviceBrand get brand => DeviceBrand.huawei;

  @override
  int get bondingStyle => DeviceCoordinator.bondingAsk;

  @override
  bool get supportsHeartRate => true;

  @override
  bool get supportsRealtimeHeartRate => true;

  @override
  bool get supportsStepCounter => true;

  @override
  bool get supportsSleepMeasurement => true;

  @override
  bool get supportsDataFetching => true;

  @override
  bool get supportsActivityTracking => true;

  @override
  bool get supportsFindDevice => true;

  @override
  bool get supportsAlarms => true;

  @override
  int get alarmSlotCount => 5;

  @override
  bool get supportsSmartWakeup => true;

  @override
  bool get supportsWeather => true;

  @override
  bool get supportsMusicInfo => true;

  @override
  bool get supportsRealtimeData => true;

  @override
  bool get supportsStressMeasurement => true;

  @override
  bool get supportsSpo2 => true;

  @override
  bool get supportsTemperatureMeasurement => true;

  @override
  String get manufacturer => 'Huawei';

  @override
  DeviceKind get deviceKind => DeviceKind.fitnessBand;

  // Huawei service UUID: 0xFDD2
  static final Guid _huaweiService = Guid('0000fdd2-0000-1000-8000-00805f9b34fb');

  @override
  List<Guid> get scanFilterUuids => [_huaweiService];

  @override
  bool supports(ScanResult candidate) {
    final name = candidate.device.platformName.toLowerCase();
    final uuids = candidate.advertisementData.serviceUuids;

    if (uuids.contains(_huaweiService)) return true;
    if (name.contains('huawei') || name.contains('honor band') || name.contains('honor watch')) {
      return true;
    }
    return false;
  }

  @override
  List<DeviceSettingGroup> getDeviceSettings(String deviceId) {
    return [
      DeviceSettingGroup(title: 'Отображение', settings: [
        DeviceSetting(key: 'wear_location', label: 'Рука ношения', type: DeviceSettingType.dropdown, defaultValue: 'left', options: [
          const DeviceSettingOption(label: 'Левая', value: 'left'),
          const DeviceSettingOption(label: 'Правая', value: 'right'),
        ]),
      ]),
      DeviceSettingGroup(title: 'Пульс', settings: [
        const DeviceSetting(key: 'hr_smart_alert', label: 'Умные оповещения пульса', type: DeviceSettingType.toggle, defaultValue: true),
        const DeviceSetting(key: 'hr_continuous', label: 'Непрерывное измерение', type: DeviceSettingType.toggle, defaultValue: false),
      ]),
      DeviceSettingGroup(title: 'Стресс', settings: [
        const DeviceSetting(key: 'stress_auto', label: 'Авто-измерение стресса', type: DeviceSettingType.toggle, defaultValue: true),
      ]),
      DeviceSettingGroup(title: 'SpO2', settings: [
        const DeviceSetting(key: 'spo2_alert', label: 'Оповещение о SpO2', type: DeviceSettingType.toggle, defaultValue: false),
      ]),
    ];
  }
}
