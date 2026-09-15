import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;

/// Professional Xiaomi BLE authentication service.
/// Implements exact Gadgetbridge protocol for Amazfit Bip / Mi Band devices.
///
/// Amazfit Bip (Huami) uses a 3-step AES/ECB auth:
///   Step 1: Phone sends secret key to device
///   Step 2: Phone requests random auth number from device
///   Step 3: Phone encrypts random number with AES/ECB(key) and sends back
///
/// Mi Band 4+ uses HMAC-SHA256 protobuf-based auth.
class XiaomiBleAuthService {
  XiaomiBleAuthService._();
  static final XiaomiBleAuthService instance = XiaomiBleAuthService._();

  // --- Huami UUIDs (from HuamiService.java) ---
  // Service: Mi Band 2 Service (0xFEE1), NOT 0xFEE0!
  static final Guid _huamiService = Guid('0000fee1-0000-1000-8000-00805f9b34fb');
  static final Guid _huamiAuthChar = Guid('00000009-0000-3512-2118-0009af100700');
  static final Guid _huamiBatteryChar = Guid('00000006-0000-3512-2118-0009af100700');
  static final Guid _huamiHrService = Guid('0000180d-0000-3512-2118-0009af100700');
  static final Guid _huamiHrChar = Guid('00002a37-0000-3512-2118-0009af100700');

  // --- Auth commands (from HuamiService.java) ---
  static const int _authSendKey = 0x01;
  static const int _authRequestRandom = 0x02;
  static const int _authSendEncrypted = 0x03;
  static const int _authResponse = 0x10;
  static const int _authSuccess = 0x01;
  static const int _authFail = 0x04;
  static const int _authByte = 0x08;

  // --- Default secret key (from InitOperation.java line 93) ---
  static final Uint8List _defaultSecretKey = Uint8List.fromList([
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
    0x38, 0x39, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45,
  ]);

  SharedPreferences? _prefs;
  final Map<String, bool> _authenticated = {};

  bool isAuthenticated(String deviceId) => _authenticated[deviceId] ?? false;

  // ====================================================================
  // HUAMI 3-STEP AUTH (Amazfit Bip, Mi Band 2/3)
  // Exact replica of Gadgetbridge InitOperation.java
  // ====================================================================

  /// Perform 3-step Huami authentication with Amazfit Bip / Mi Band.
  Future<XiaomiAuthResult> authenticateHuami(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;

    try {
      debugPrint('XiaomiAuth: Starting Huami 3-step auth for ${device.platformName}');

      // Load or generate secret key
      final secretKey = await _loadSecretKey(deviceId);

      // Discover services with RETRY — device may need time to initialize after bonding
      List<BluetoothService> services = [];
      BluetoothService? huamiService;

      for (int attempt = 1; attempt <= 5; attempt++) {
        debugPrint('XiaomiAuth: Service discovery attempt $attempt...');
        services = await device.discoverServices();
        debugPrint('XiaomiAuth: Found ${services.length} services on attempt $attempt:');
        for (final svc in services) {
          debugPrint('XiaomiAuth:   ${svc.uuid} (${svc.characteristics.length} chars)');
          if (svc.uuid == _huamiService) {
            huamiService = svc;
          }
        }

        if (huamiService != null) break;

        // Wait before retry — device may need time after bonding
        if (attempt < 5) {
          debugPrint('XiaomiAuth: 0xFEE0 not found, waiting 2s before retry...');
          await Future.delayed(const Duration(seconds: 2));
          // Try reconnecting if disconnected
          if (device.isConnected == false) {
            debugPrint('XiaomiAuth: Device disconnected, reconnecting...');
            await device.connect();
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      if (huamiService == null) {
        debugPrint('XiaomiAuth: ⚠ Huami service 0xFEE0 NOT found!');
        debugPrint('XiaomiAuth: Available services: ${services.map((s) => s.uuid).join(', ')}');
        return XiaomiAuthResult.failed('Huami service (0xFEE0) not found. Available: ${services.map((s) => s.uuid).join(', ')}');
      }
      debugPrint('XiaomiAuth: ✓ Found Huami service 0xFEE0 with ${huamiService.characteristics.length} characteristics');

      // Find auth characteristic (0x0009)
      BluetoothCharacteristic? authChar;
      for (final char in huamiService.characteristics) {
        if (char.uuid == _huamiAuthChar) {
          authChar = char;
          break;
        }
      }

      if (authChar == null) {
        return XiaomiAuthResult.failed('Auth characteristic (0x0009) not found');
      }

      // Enable notifications on auth characteristic
      if (authChar.properties.notify) {
        await authChar.setNotifyValue(true);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // ============================================================
      // STEP 1: Send secret key to device
      // From InitOperation.java line 75:
      //   byte[] sendKey = ArrayUtils.addAll(
      //     new byte[]{AUTH_SEND_KEY, authFlags}, getSecretKey());
      // ============================================================
      debugPrint('XiaomiAuth: Step 1 — Sending secret key');
      final step1Cmd = Uint8List(2 + secretKey.length);
      step1Cmd[0] = _authSendKey; // 0x01
      step1Cmd[1] = _authByte;   // 0x08 (auth flags)
      step1Cmd.setAll(2, secretKey);

      await _writeAuthChar(authChar, step1Cmd);

      // Wait for response
      final step1Response = await _waitForAuthResponse(authChar);
      if (step1Response == null) {
        return XiaomiAuthResult.failed('Step 1: No response from device');
      }

      debugPrint('XiaomiAuth: Step 1 response: ${step1Response.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

      if (step1Response[0] != _authResponse || step1Response[1] != _authSendKey || step1Response[2] != _authSuccess) {
        return XiaomiAuthResult.failed('Step 1: Auth key rejected (response: ${step1Response[2].toRadixString(16)})');
      }

      // ============================================================
      // STEP 2: Request random auth number
      // From InitOperation.java line 86:
      //   return new byte[]{AUTH_REQUEST_RANDOM_AUTH_NUMBER, authFlags};
      // ============================================================
      debugPrint('XiaomiAuth: Step 2 — Requesting random nonce');
      final step2Cmd = Uint8List(2);
      step2Cmd[0] = _authRequestRandom; // 0x02
      step2Cmd[1] = _authByte;         // 0x08

      await _writeAuthChar(authChar, step2Cmd);

      // Wait for response with random nonce
      final step2Response = await _waitForAuthResponse(authChar);
      if (step2Response == null) {
        return XiaomiAuthResult.failed('Step 2: No random nonce received');
      }

      debugPrint('XiaomiAuth: Step 2 response: ${step2Response.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

      if (step2Response[0] != _authResponse || (step2Response[1] & 0x0F) != _authRequestRandom || step2Response[2] != _authSuccess) {
        return XiaomiAuthResult.failed('Step 2: Random auth request failed');
      }

      // Extract 16-byte random nonce (bytes 3..18)
      if (step2Response.length < 19) {
        return XiaomiAuthResult.failed('Step 2: Nonce too short (${step2Response.length} bytes)');
      }
      final randomNonce = Uint8List.fromList(step2Response.sublist(3, 19));

      // ============================================================
      // STEP 3: Encrypt nonce with AES/ECB and send back
      // From InitOperation.java line 174-179:
      //   byte[] mValue = Arrays.copyOfRange(value, 3, 19);
      //   Cipher ecipher = Cipher.getInstance("AES/ECB/NoPadding");
      //   SecretKeySpec newKey = new SecretKeySpec(secretKey, "AES");
      //   ecipher.init(Cipher.ENCRYPT_MODE, newKey);
      //   return ecipher.doFinal(mValue);
      // ============================================================
      debugPrint('XiaomiAuth: Step 3 — Encrypting nonce with AES/ECB');
      final encryptedNonce = _aesEcbEncrypt(secretKey, randomNonce);

      final step3Cmd = Uint8List(2 + encryptedNonce.length);
      step3Cmd[0] = _authSendEncrypted; // 0x03
      step3Cmd[1] = _authByte;         // 0x08
      step3Cmd.setAll(2, encryptedNonce);

      await _writeAuthChar(authChar, step3Cmd);

      // Wait for final confirmation
      final step3Response = await _waitForAuthResponse(authChar);
      if (step3Response == null) {
        return XiaomiAuthResult.failed('Step 3: No confirmation received');
      }

      debugPrint('XiaomiAuth: Step 3 response: ${step3Response.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

      if (step3Response[0] == _authResponse && (step3Response[1] & 0x0F) == _authSendEncrypted && step3Response[2] == _authSuccess) {
        _authenticated[deviceId] = true;
        debugPrint('XiaomiAuth: ✅ Huami auth SUCCESS for ${device.platformName}');
        return XiaomiAuthResult.success('Amazfit/Mi Band authenticated successfully');
      } else if (step3Response[2] == _authFail) {
        return XiaomiAuthResult.failed('Step 3: Auth failed — wrong key?');
      } else {
        return XiaomiAuthResult.failed('Step 3: Unexpected response');
      }
    } catch (e) {
      debugPrint('XiaomiAuth: Huami auth error: $e');
      return XiaomiAuthResult.failed('Auth error: $e');
    }
  }

  // ====================================================================
  // AUTO-DETECT & AUTHENTICATE
  // ====================================================================

  /// Auto-detect device protocol and authenticate.
  /// Pass deviceName so native side can set correct authFlags/cryptFlags.
  Future<XiaomiAuthResult> authenticate(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;

    // Prevent multiple simultaneous auth attempts
    if (_authenticated.containsKey(deviceId)) {
      return XiaomiAuthResult.success('Already authenticated');
    }

    // Load secret key
    final secretKey = await _loadSecretKey(deviceId);
    final keyHex = secretKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // Get device name for auto-detection of authFlags/cryptFlags
    final deviceName = device.platformName.isNotEmpty ? device.platformName : '';

    // Call native Xiaomi auth manager
    try {
      final platform = MethodChannel('com.zapfit/xiaomi_auth');
      final result = await platform.invokeMethod('connectAndAuth', {
        'macAddress': deviceId,
        'authKey': keyHex,
        'deviceName': deviceName,
      });

      final success = result['success'] as bool;
      final message = result['message'] as String;

      if (success) {
        _authenticated[deviceId] = true;
        debugPrint('XiaomiAuth: ✓ $message');
        return XiaomiAuthResult.success(message);
      } else {
        debugPrint('XiaomiAuth: ✗ $message');
        return XiaomiAuthResult.failed(message);
      }
    } catch (e) {
      debugPrint('XiaomiAuth: Error calling native auth: $e');
      return XiaomiAuthResult.failed('Native auth error: $e');
    }
  }

  // ====================================================================
  // BLE HELPERS
  // ====================================================================

  Future<void> _writeAuthChar(BluetoothCharacteristic char, Uint8List data) async {
    if (char.properties.writeWithoutResponse) {
      await char.write(data, withoutResponse: true);
    } else if (char.properties.write) {
      await char.write(data);
    }
  }

  /// Wait for auth response on the auth characteristic.
  Future<Uint8List?> _waitForAuthResponse(BluetoothCharacteristic char, {Duration timeout = const Duration(seconds: 5)}) async {
    final completer = Completer<Uint8List?>();
    StreamSubscription<List<int>>? sub;

    sub = char.lastValueStream.listen((value) {
      if (value.isNotEmpty && !completer.isCompleted) {
        completer.complete(Uint8List.fromList(value));
      }
    });

    final result = await completer.future.timeout(
      timeout,
      onTimeout: () {
        sub?.cancel();
        return null;
      },
    );

    await sub?.cancel();
    return result;
  }

  // ====================================================================
  // AES/ECB ENCRYPTION (exact Gadgetbridge implementation)
  // ====================================================================

  /// AES/ECB/NoPadding encryption — exact replica of InitOperation.handleAESAuth()
  Uint8List _aesEcbEncrypt(Uint8List key, Uint8List data) {
    // Pad data to 16 bytes if needed (AES block size)
    final paddedData = Uint8List(16);
    paddedData.setAll(0, data);

    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(
        encrypt_lib.Key(key),
        mode: encrypt_lib.AESMode.ecb,
        padding: null, // NoPadding
      ),
    );

    final encrypted = encrypter.encryptBytes(paddedData.toList());
    return encrypted.bytes;
  }

  // ====================================================================
  // KEY MANAGEMENT
  // ====================================================================

  Future<Uint8List> _loadSecretKey(String deviceId) async {
    _prefs ??= await SharedPreferences.getInstance();
    final hex = _prefs!.getString('huami_auth_key_$deviceId');
    if (hex != null && hex.length == 32) {
      return Uint8List.fromList(List.generate(16, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
    }
    return _defaultSecretKey;
  }

  Future<void> saveSecretKey(String deviceId, Uint8List key) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('huami_auth_key_$deviceId', key.map((b) => b.toRadixString(16).padLeft(2, '0')).join());
  }

  /// Clear auth state for a device.
  Future<void> clearAuth(String deviceId) async {
    _authenticated.remove(deviceId);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove('huami_auth_key_$deviceId');
  }
}

/// Result of Xiaomi BLE authentication.
class XiaomiAuthResult {
  final bool isSuccess;
  final String message;

  const XiaomiAuthResult({required this.isSuccess, required this.message});

  factory XiaomiAuthResult.success(String msg) => XiaomiAuthResult(isSuccess: true, message: msg);
  factory XiaomiAuthResult.failed(String msg) => XiaomiAuthResult(isSuccess: false, message: msg);
}
