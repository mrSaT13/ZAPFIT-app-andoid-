import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:zapfit/core/models/device_coordinator.dart';
import 'package:zapfit/core/models/device_model.dart';
import 'package:zapfit/core/services/miband_protocol.dart';

/// Coordinator for Huami devices (Mi Band 2/3/4, Amazfit Bip, GTS, GTR, T-Rex, etc.).
/// These use the 0xFEE1 service with AES/ECB or HMAC-SHA256 auth.
class HuamiCoordinator extends DeviceCoordinator {
  @override
  String get id => 'huami';

  @override
  String get name => 'Xiaomi/Amazfit (Huami)';

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
  bool get supportsStressMeasurement => false;

  @override
  bool get supportsSpo2 => false;

  @override
  String get manufacturer => 'Xiaomi';

  @override
  DeviceKind get deviceKind => DeviceKind.fitnessBand;

  @override
  int get reconnectionDelayMs => 5000;

  @override
  List<Guid> get scanFilterUuids => [MiBandProtocol.serviceMiBand2];

  @override
  bool supports(ScanResult candidate) {
    final uuids = candidate.advertisementData.serviceUuids;
    // Mi Band 2+ and all Amazfit devices use 0xFEE1
    if (uuids.contains(MiBandProtocol.serviceMiBand2)) {
      return true;
    }
    // Also support if it has 0xFEE0 + 0xFEE1 (dual service)
    if (uuids.contains(MiBandProtocol.serviceMiBand) &&
        uuids.contains(MiBandProtocol.serviceMiBand2)) {
      return true;
    }
    return false;
  }

  /// Detect specific device model from name.
  static HuamiDeviceModel detectModel(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('amazfit bip')) return HuamiDeviceModel.amazfitBip;
    if (lower.contains('amazfit bip s')) return HuamiDeviceModel.amazfitBipS;
    if (lower.contains('amazfit bip lite')) return HuamiDeviceModel.amazfitBipLite;
    if (lower.contains('amazfit gts')) return HuamiDeviceModel.amazfitGts;
    if (lower.contains('amazfit gtr')) return HuamiDeviceModel.amazfitGtr;
    if (lower.contains('amazfit t-rex')) return HuamiDeviceModel.amazfitTRex;
    if (lower.contains('amazfit pace')) return HuamiDeviceModel.amazfitPace;
    if (lower.contains('amazfit verve')) return HuamiDeviceModel.amazfitVerve;
    if (lower.contains('mi band 4')) return HuamiDeviceModel.miBand4;
    if (lower.contains('mi band 5')) return HuamiDeviceModel.miBand5;
    if (lower.contains('mi band 6')) return HuamiDeviceModel.miBand6;
    if (lower.contains('mi band 7')) return HuamiDeviceModel.miBand7;
    if (lower.contains('mi band 8')) return HuamiDeviceModel.miBand8;
    if (lower.contains('mi band')) return HuamiDeviceModel.miBandGeneric;
    if (lower.contains('redmi')) return HuamiDeviceModel.redmiBand;
    return HuamiDeviceModel.unknown;
  }

  @override
  List<DeviceSettingGroup> getDeviceSettings(String deviceId) {
    return [
      DeviceSettingGroup(title: 'Отображение', settings: [
        DeviceSetting(key: 'wear_location', label: 'Рука ношения', type: DeviceSettingType.dropdown, defaultValue: 'left', options: [
          const DeviceSettingOption(label: 'Левая', value: 'left'),
          const DeviceSettingOption(label: 'Правая', value: 'right'),
        ]),
        DeviceSetting(key: 'datetime_format', label: 'Формат времени', type: DeviceSettingType.dropdown, defaultValue: '24h', options: [
          const DeviceSettingOption(label: '24 часа', value: '24h'),
          const DeviceSettingOption(label: '12 часов', value: '12h'),
        ]),
        DeviceSetting(key: 'display_items', label: 'Элементы экрана', type: DeviceSettingType.dropdown, defaultValue: 'steps_distance_calories', options: [
          const DeviceSettingOption(label: 'Шаги/Дистанция/Калории', value: 'steps_distance_calories'),
          const DeviceSettingOption(label: 'Пульс', value: 'heart_rate'),
          const DeviceSettingOption(label: 'Погода', value: 'weather'),
        ]),
      ]),
      DeviceSettingGroup(title: 'Уведомления', settings: [
        const DeviceSetting(key: 'notification_vibration', label: 'Вибрация уведомлений', type: DeviceSettingType.toggle, defaultValue: true),
        const DeviceSetting(key: 'notification_reject', label: 'Отклонение звонков', type: DeviceSettingType.toggle, defaultValue: true),
        DeviceSetting(key: 'vibration_profile', label: 'Профиль вибрации', type: DeviceSettingType.dropdown, defaultValue: 'short', options: [
          const DeviceSettingOption(label: 'Короткая', value: 'short'),
          const DeviceSettingOption(label: 'Длинная', value: 'long'),
          const DeviceSettingOption(label: 'Двойная', value: 'double'),
          const DeviceSettingOption(label: 'Тройная', value: 'triple'),
        ]),
      ]),
      DeviceSettingGroup(title: 'Пульс', settings: [
        const DeviceSetting(key: 'hr_sleep_support', label: 'Измерение пульса во сне', type: DeviceSettingType.toggle, defaultValue: false),
        const DeviceSetting(key: 'hr_continuous', label: 'Непрерывное измерение', type: DeviceSettingType.toggle, defaultValue: false),
        const DeviceSetting(key: 'hr_interval', label: 'Интервал измерения (мин)', type: DeviceSettingType.number, defaultValue: 10, min: 1, max: 60),
        const DeviceSetting(key: 'hr_high_alert', label: 'Оповещение о высоком пульсе', type: DeviceSettingType.number, defaultValue: 0, min: 0, max: 220),
        const DeviceSetting(key: 'hr_low_alert', label: 'Оповещение о низком пульсе', type: DeviceSettingType.number, defaultValue: 0, min: 0, max: 220),
      ]),
      DeviceSettingGroup(title: 'Фитнес', settings: [
        const DeviceSetting(key: 'fitness_goal', label: 'Цель по шагам', type: DeviceSettingType.number, defaultValue: 10000, min: 1000, max: 100000),
        const DeviceSetting(key: 'goal_alert', label: 'Оповещение о цели', type: DeviceSettingType.toggle, defaultValue: true),
      ]),
      DeviceSettingGroup(title: 'Будильники', settings: List.generate(5, (i) => DeviceSetting(
        key: 'alarm_${i}_enabled',
        label: 'Будильник ${i + 1}',
        type: DeviceSettingType.toggle,
        defaultValue: false,
      ))),
      DeviceSettingGroup(title: 'Do Not Disturb', settings: [
        const DeviceSetting(key: 'dnd_enabled', label: 'Не беспокоить', type: DeviceSettingType.toggle, defaultValue: false),
        const DeviceSetting(key: 'dnd_start', label: 'Начало', type: DeviceSettingType.time, defaultValue: '22:00'),
        const DeviceSetting(key: 'dnd_end', label: 'Конец', type: DeviceSettingType.time, defaultValue: '07:00'),
      ]),
      DeviceSettingGroup(title: 'Расписание экранов', settings: [
        const DeviceSetting(key: 'raise_to_wake', label: 'Поднятие для просмотра', type: DeviceSettingType.toggle, defaultValue: true),
        const DeviceSetting(key: 'always_on_display', label: 'Always-on дисплей', type: DeviceSettingType.toggle, defaultValue: false),
        const DeviceSetting(key: 'screen_timeout', label: 'Таймаут экрана (сек)', type: DeviceSettingType.number, defaultValue: 5, min: 3, max: 15),
      ]),
    ];
  }
}

enum HuamiDeviceModel {
  unknown,
  miBandGeneric,
  miBand4,
  miBand5,
  miBand6,
  miBand7,
  miBand8,
  redmiBand,
  amazfitBip,
  amazfitBipS,
  amazfitBipLite,
  amazfitGts,
  amazfitGtr,
  amazfitTRex,
  amazfitPace,
  amazfitVerve,
}
