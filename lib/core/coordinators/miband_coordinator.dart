import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:zapfit/core/models/device_coordinator.dart';
import 'package:zapfit/core/models/device_model.dart';
import 'package:zapfit/core/services/miband_protocol.dart';

/// Coordinator for Mi Band 1/1A/1S and early Huami devices.
/// These use the 0xFEE0 service with custom auth (no AES).
class MiBandCoordinator extends DeviceCoordinator {
  @override
  String get id => 'miband_v1';

  @override
  String get name => 'Xiaomi Mi Band (1/1A/1S)';

  @override
  DeviceBrand get brand => DeviceBrand.xiaomi;

  @override
  int get bondingStyle => DeviceCoordinator.bondingAsk;

  @override
  bool get supportsHeartRate => true;

  @override
  bool get supportsRealtimeHeartRate => true;

  @override
  bool get supportsManualHeartRate => true;

  @override
  bool get supportsStepCounter => true;

  @override
  bool get supportsDataFetching => true;

  @override
  bool get supportsActivityTracking => true;

  @override
  bool get supportsFindDevice => true;

  @override
  bool get supportsAlarms => true;

  @override
  int get alarmSlotCount => 3;

  @override
  bool get supportsSmartWakeup => true;

  @override
  bool get supportsRealtimeData => true;

  @override
  String get manufacturer => 'Xiaomi';

  @override
  DeviceKind get deviceKind => DeviceKind.fitnessBand;

  @override
  List<Guid> get scanFilterUuids => [MiBandProtocol.serviceMiBand];

  @override
  bool supports(ScanResult candidate) {
    final uuids = candidate.advertisementData.serviceUuids;
    // Supports 0xFEE0 but NOT 0xFEE1 (that's Mi Band 2+)
    if (uuids.contains(MiBandProtocol.serviceMiBand) &&
        !uuids.contains(MiBandProtocol.serviceMiBand2)) {
      return true;
    }
    // MAC prefix heuristic
    final mac = candidate.device.remoteId.str.toUpperCase();
    if (mac.startsWith(MiBandProtocol.macFilter1_1A) ||
        mac.startsWith(MiBandProtocol.macFilter1S)) {
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
        DeviceSetting(key: 'datetime_display', label: 'Формат времени', type: DeviceSettingType.dropdown, defaultValue: '24h', options: [
          const DeviceSettingOption(label: '24 часа', value: '24h'),
          const DeviceSettingOption(label: '12 часов', value: '12h'),
        ]),
      ]),
      DeviceSettingGroup(title: 'Уведомления', settings: [
        const DeviceSetting(key: 'vibration_count', label: 'Количество вибраций', type: DeviceSettingType.number, defaultValue: 1, min: 1, max: 10),
        const DeviceSetting(key: 'vibration_duration', label: 'Длительность вибрации (мс)', type: DeviceSettingType.number, defaultValue: 500, min: 100, max: 3000),
      ]),
      DeviceSettingGroup(title: 'Пульс', settings: [
        const DeviceSetting(key: 'hr_sleep_support', label: 'Измерение пульса во сне', type: DeviceSettingType.toggle, defaultValue: false),
        const DeviceSetting(key: 'hr_interval', label: 'Интервал измерения (мин)', type: DeviceSettingType.number, defaultValue: 10, min: 1, max: 60),
      ]),
      DeviceSettingGroup(title: 'Фитнес', settings: [
        const DeviceSetting(key: 'fitness_goal', label: 'Цель по шагам', type: DeviceSettingType.number, defaultValue: 10000, min: 1000, max: 100000),
      ]),
      DeviceSettingGroup(title: 'Будильники', settings: [
        const DeviceSetting(key: 'alarm_0_enabled', label: 'Будильник 1', type: DeviceSettingType.toggle, defaultValue: false),
        const DeviceSetting(key: 'alarm_0_time', label: 'Время будильника 1', type: DeviceSettingType.time, defaultValue: '07:00'),
        const DeviceSetting(key: 'alarm_0_smart', label: 'Умный подъём 1', type: DeviceSettingType.toggle, defaultValue: false),
        const DeviceSetting(key: 'alarm_1_enabled', label: 'Будильник 2', type: DeviceSettingType.toggle, defaultValue: false),
        const DeviceSetting(key: 'alarm_2_enabled', label: 'Будильник 3', type: DeviceSettingType.toggle, defaultValue: false),
      ]),
    ];
  }
}
