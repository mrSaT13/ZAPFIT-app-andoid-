import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Mi Band BLE protocol constants and helpers.
/// Based on Gadgetbridge's MiBandService.java and MiBandSupport.java.
class MiBandProtocol {
  MiBandProtocol._();

  // =====================================================================
  // SERVICE & CHARACTERISTIC UUIDs (MiBandService.java)
  // =====================================================================

  /// Mi Band 1/1A/1S main service (0xFEE0)
  static final Guid serviceMiBand = _uuid('FEE0');

  /// Mi Band 2+ service (0xFEE1)
  static final Guid serviceMiBand2 = _uuid('FEE1');

  /// Standard Heart Rate service (0x180D)
  static final Guid serviceHeartRate = Guid('0000180d-0000-3512-2118-0009af100700');

  /// Characteristics under 0xFEE0 service
  static final Guid charDeviceInfo = _uuid('FF01');
  static final Guid charDeviceName = _uuid('FF02');
  static final Guid charNotification = _uuid('FF03');
  static final Guid charUserInfo = _uuid('FF04');
  static final Guid charControlPoint = _uuid('FF05');
  static final Guid charRealtimeSteps = _uuid('FF06');
  static final Guid charActivityData = _uuid('FF07');
  static final Guid charFirmwareData = _uuid('FF08');
  static final Guid charLeParams = _uuid('FF09');
  static final Guid charDateTime = _uuid('FF0A');
  static final Guid charStatistics = _uuid('FF0B');
  static final Guid charBattery = _uuid('FF0C');
  static final Guid charTest = _uuid('FF0D');
  static final Guid charSensorData = _uuid('FF0E');
  static final Guid charPair = _uuid('FF0F');

  /// Standard Heart Rate measurement (0x2A37)
  static final Guid charHrMeasurement = Guid('00002a37-0000-3512-2118-0009af100700');
  /// Standard Heart Rate control point (0x2A3C)
  static final Guid charHrControlPoint = Guid('00002a3c-0000-3512-2118-0009af100700');

  // =====================================================================
  // NOTIFICATION VALUES (received on charNotification)
  // =====================================================================

  static const int notifyAuthSuccess = 0x05;
  static const int notifyAuthFailed = 0x06;
  static const int notifyFitnessGoalAchieved = 0x07;
  static const int notifySetLatencySuccess = 0x08;
  static const int notifyResetAuthSuccess = 0x0A;
  static const int notifyStatusMotorAuth = 0x13;
  static const int notifyStatusMotorAuthSuccess = 0x15;

  // =====================================================================
  // CONTROL POINT COMMANDS (sent to charControlPoint)
  // =====================================================================

  static const int cmdSetRealtimeStepsNotification = 0x03;
  static const int cmdSetTimer = 0x04;
  static const int cmdSetFitnessGoal = 0x05;
  static const int cmdFetchData = 0x06;
  static const int cmdSendFirmwareInfo = 0x07;
  static const int cmdSendNotification = 0x08;
  static const int cmdFactoryReset = 0x09;
  static const int cmdConfirmActivityTransferComplete = 0x0A;
  static const int cmdSync = 0x0B;
  static const int cmdReboot = 0x0C;
  static const int cmdSetWearLocation = 0x0F;
  static const int cmdStopSyncData = 0x11;
  static const int cmdStopMotorVibrate = 0x13;
  static const int cmdGetSensorData = 0x12;

  // =====================================================================
  // HR CONTROL POINT COMMANDS
  // =====================================================================

  static const int hrSleep = 0x00;
  static const int hrContinuous = 0x01;
  static const int hrManual = 0x02;

  // =====================================================================
  // DATA MODES
  // =====================================================================

  static const int modeRegularDataLenByte = 0x00;
  static const int modeRegularDataLenMinute = 0x01;

  // =====================================================================
  // MAC ADDRESS FILTERS
  // =====================================================================

  static const String macFilter1_1A = '88:0F:10';
  static const String macFilter1S = 'C8:0F:10';

  // =====================================================================
  // HELPER
  // =====================================================================

  static Guid _uuid(String hex16) {
    return Guid('0000$hex16-0000-1000-8000-00805f9b34fb');
  }

  /// Build the low-latency connection parameters (39–49ms interval).
  static Uint8List getLowLatencyParams() => _buildLeParams(39, 49, 0, 500, 0);

  /// Build the high-latency connection parameters (460–500ms interval).
  static Uint8List getHighLatencyParams() => _buildLeParams(460, 500, 0, 500, 0);

  static Uint8List _buildLeParams(
    int minInterval,
    int maxInterval,
    int latency,
    int timeout,
    int advInterval,
  ) {
    final bytes = Uint8List(12);
    bytes[0] = minInterval & 0xFF;
    bytes[1] = (minInterval >> 8) & 0xFF;
    bytes[2] = maxInterval & 0xFF;
    bytes[3] = (maxInterval >> 8) & 0xFF;
    bytes[4] = latency & 0xFF;
    bytes[5] = (latency >> 8) & 0xFF;
    bytes[6] = timeout & 0xFF;
    bytes[7] = (timeout >> 8) & 0xFF;
    bytes[8] = 0;
    bytes[9] = 0;
    bytes[10] = advInterval & 0xFF;
    bytes[11] = (advInterval >> 8) & 0xFF;
    return bytes;
  }

  /// Build user info payload for charUserInfo (FF04).
  static Uint8List buildUserInfo({
    required int weight, // kg
    required int height, // cm
    required int age,
    required int gender, // 0=male, 1=female
    required int alias,
  }) {
    final bytes = Uint8List(20);
    bytes[0] = 0;
    bytes[1] = gender & 0xFF;
    bytes[2] = age & 0xFF;
    bytes[3] = weight & 0xFF;
    bytes[4] = (weight >> 8) & 0xFF;
    bytes[5] = height & 0xFF;
    bytes[6] = (height >> 8) & 0xFF;
    return bytes;
  }

  /// Build fitness goal command payload.
  static Uint8List buildFitnessGoal(int steps) {
    return Uint8List.fromList([
      cmdSetFitnessGoal,
      0,
      steps & 0xFF,
      (steps >> 8) & 0xFF,
    ]);
  }

  /// Build wear location command payload.
  static Uint8List buildWearLocation(int location) {
    return Uint8List.fromList([cmdSetWearLocation, location & 0xFF]);
  }

  /// Build timer/alarm command payload.
  static Uint8List buildAlarm({
    required int position,
    required bool enabled,
    required DateTime timestamp,
    required int smartWakeupMinutes,
    required int repetition,
  }) {
    final year = timestamp.year - 2000;
    final month = timestamp.month;
    final day = timestamp.day;
    final hour = timestamp.hour;
    final minute = timestamp.minute;
    final second = timestamp.second;

    return Uint8List.fromList([
      cmdSetTimer,
      position & 0xFF,
      enabled ? 1 : 0,
      second & 0xFF,
      minute & 0xFF,
      hour & 0xFF,
      day & 0xFF,
      month & 0xFF,
      year & 0xFF,
      smartWakeupMinutes & 0xFF,
      repetition & 0xFF,
    ]);
  }

  /// Parse battery info from charBattery (FF0C) response.
  static BatteryInfo parseBattery(List<int> value) {
    if (value.length < 3) return BatteryInfo.unknown();
    final level = value[0] & 0xFF;
    final status = value[1] & 0xFF; // 1=charging, 2=discharging, 3=not charging, 4=full
    return BatteryInfo(level: level, status: status);
  }

  /// Parse device info from charDeviceInfo (FF01) response.
  static DeviceInfo parseDeviceInfo(List<int> value) {
    if (value.length < 4) return DeviceInfo.unknown();
    final firmwareVersion = (value[3] & 0xFF) << 16 | (value[2] & 0xFF) << 8 | (value[1] & 0xFF);
    final hardwareVersion = value[0] & 0xFF;
    final profileVersion = value.length > 5
        ? (value[5] & 0xFF) << 24 | (value[4] & 0xFF) << 16 | (value[6] & 0xFF) << 8 | (value[7] & 0xFF)
        : 0;
    return DeviceInfo(
      firmwareVersion: firmwareVersion,
      hardwareVersion: hardwareVersion,
      profileVersion: profileVersion,
    );
  }

  /// Parse heart rate from HR measurement characteristic.
  static int? parseHeartRate(List<int> value) {
    if (value.length < 2) return null;
    if (value[0] == 0x06 && value.length >= 2) {
      return value[1] & 0xFF;
    }
    return null;
  }

  /// Parse realtime steps from charRealtimeSteps (FF06).
  static int? parseRealtimeSteps(List<int> value) {
    if (value.length < 2) return null;
    return (value[0] & 0xFF) | ((value[1] & 0xFF) << 8);
  }

  /// Parse activity metadata (11 bytes: type, timestamp[6], total, block).
  static ActivityMetadata? parseActivityMetadata(List<int> value) {
    if (value.length != 11) return null;
    final dataType = value[0];
    // timestamp bytes 1-6 (skip for now, raw)
    final totalData = (value[7] & 0xFF) | ((value[8] & 0xFF) << 8);
    final blockData = (value[9] & 0xFF) | ((value[10] & 0xFF) << 8);
    return ActivityMetadata(
      dataType: dataType,
      totalData: totalData,
      blockData: blockData,
    );
  }
}

// =====================================================================
// DATA MODELS
// =====================================================================

class BatteryInfo {
  final int level;
  final int status; // 1=charging, 2=discharging, 3=not charging, 4=full

  const BatteryInfo({required this.level, required this.status});
  factory BatteryInfo.unknown() => const BatteryInfo(level: 0, status: 0);

  bool get isCharging => status == 1 || status == 4;
}

class DeviceInfo {
  final int firmwareVersion;
  final int hardwareVersion;
  final int profileVersion;

  const DeviceInfo({
    required this.firmwareVersion,
    required this.hardwareVersion,
    required this.profileVersion,
  });
  factory DeviceInfo.unknown() =>
      const DeviceInfo(firmwareVersion: 0, hardwareVersion: 0, profileVersion: 0);

  bool get supportsHeartrate => hardwareVersion >= 7; // Mi Band 1S+
  String get firmwareString =>
      '${(firmwareVersion >> 16) & 0xFF}.${(firmwareVersion >> 8) & 0xFF}.${firmwareVersion & 0xFF}';
}

class ActivityMetadata {
  final int dataType;
  final int totalData;
  final int blockData;

  const ActivityMetadata({
    required this.dataType,
    required this.totalData,
    required this.blockData,
  });
}
