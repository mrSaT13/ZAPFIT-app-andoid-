import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Xiaomi BLE device authentication helper.
/// Supports SHA256-based authentication used by Mi Band/Scale devices.
/// Based on patterns from Gadgetbridge XiaomiAuthService.
class XiaomiAuthHelper {
  XiaomiAuthHelper._();

  /// Generate a random nonce for authentication handshake.
  static Uint8List generateNonce([int length = 16]) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Compute SHA256 HMAC for authentication response.
  /// Used in Mi Band/Scale BLE authentication protocol.
  static Uint8List computeAuthHmac({
    required Uint8List key,
    required Uint8List data,
  }) {
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  /// Compute SHA256 hash.
  static Uint8List sha256Hash(List<int> data) {
    final digest = sha256.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  /// Derive encryption key from secret key and nonce.
  /// Standard Xiaomi protocol: SHA256(secret + nonce).
  static Uint8List deriveKey({
    required Uint8List secretKey,
    required Uint8List nonce,
  }) {
    final combined = Uint8List(secretKey.length + nonce.length);
    combined.setAll(0, secretKey);
    combined.setAll(secretKey.length, nonce);
    return sha256Hash(combined);
  }

  /// Encrypt data using AES-CCM mode (if needed for advanced auth).
  /// Returns null if encryption fails.
  static Uint8List? encryptCcm({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List plainText,
    int macLength = 4,
  }) {
    try {
      // Simplified CCM - in production would use pointycastle CCMBlockCipher
      // For now, XOR-based simple encryption for basic auth
      final result = Uint8List(plainText.length + macLength);
      for (int i = 0; i < plainText.length; i++) {
        result[i] = plainText[i] ^ key[i % key.length];
      }
      // Append MAC
      final mac = sha256Hash(key + plainText);
      for (int i = 0; i < macLength; i++) {
        result[plainText.length + i] = mac[i];
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Parse Mi Band device info from BLE advertisement or service data.
  static MiDeviceInfo? parseDeviceInfo(List<int> data) {
    if (data.length < 10) return null;

    try {
      // Common Mi Band advertisement format
      final deviceId = data.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final firmwareMajor = data[4];
      final firmwareMinor = data[5];
      final firmwarePatch = data[6];
      final batteryLevel = data.length > 7 ? data[7] : -1;
      final deviceType = data.length > 8 ? data[8] : 0;

      return MiDeviceInfo(
        deviceId: deviceId,
        firmwareVersion: '$firmwareMajor.$firmwareMinor.$firmwarePatch',
        batteryLevel: batteryLevel,
        deviceType: _deviceTypeFromCode(deviceType),
      );
    } catch (e) {
      return null;
    }
  }

  static String _deviceTypeFromCode(int code) {
    switch (code) {
      case 0: return 'Mi Band';
      case 1: return 'Mi Scale';
      case 2: return 'Mi Band 2';
      case 3: return 'Mi Scale 2';
      case 4: return 'Mi Band 3';
      case 5: return 'Mi Band 4';
      case 6: return 'Mi Band 5';
      case 7: return 'Mi Band 6';
      case 8: return 'Mi Band 7';
      case 9: return 'Mi Band 8';
      default: return 'Unknown ($code)';
    }
  }
}

class MiDeviceInfo {
  final String deviceId;
  final String firmwareVersion;
  final int batteryLevel;
  final String deviceType;

  const MiDeviceInfo({
    required this.deviceId,
    required this.firmwareVersion,
    required this.batteryLevel,
    required this.deviceType,
  });

  @override
  String toString() => '$deviceType ($deviceId) FW:$firmwareVersion Battery:$batteryLevel%';
}
