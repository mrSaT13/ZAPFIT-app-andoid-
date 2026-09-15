import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:zapfit/core/models/device_coordinator.dart';
import 'package:zapfit/core/models/device_model.dart';
import 'miband_coordinator.dart';
import 'huami_coordinator.dart';
import 'huawei_coordinator.dart';
import 'polar_coordinator.dart';

/// Registry of all device coordinators.
/// Auto-detects which coordinator handles a scanned device.
/// Mirrors Gadgetbridge's DeviceTypeCoordinator discovery logic.
class CoordinatorRegistry {
  CoordinatorRegistry._();
  static final CoordinatorRegistry instance = CoordinatorRegistry._();

  final List<DeviceCoordinator> _coordinators = [
    HuamiCoordinator(), // Mi Band 2+, Amazfit Bip, etc.
    MiBandCoordinator(), // Mi Band 1/1A/1S
    HuaweiCoordinator(), // Huawei Band/Watch
    PolarCoordinator(), // Polar H7/H9/H10
    // Add more coordinators here as needed:
    // GarminCoordinator(),
    // CasioCoordinator(),
    // PineTimeCoordinator(),
    // BangleJSCoordinator(),
    // InfiniTimeCoordinator(),
  ];

  List<DeviceCoordinator> get coordinators => List.unmodifiable(_coordinators);

  /// Find the best coordinator for a scanned device.
  /// Returns null if no coordinator supports this device.
  DeviceCoordinator? resolve(ScanResult candidate) {
    for (final coordinator in _coordinators) {
      if (coordinator.supports(candidate)) {
        return coordinator;
      }
    }
    return null;
  }

  /// Find coordinator by id.
  DeviceCoordinator? getById(String id) {
    for (final coordinator in _coordinators) {
      if (coordinator.id == id) return coordinator;
    }
    return null;
  }

  /// Detect brand from device name (quick heuristic before full scan).
  static DeviceBrand detectBrand(String name) {
    return TrackedDevice.detectBrand(name);
  }

  /// Get all scan filter UUIDs for initial filtered scan.
  /// Includes coordinator UUIDs + standard BLE sports services
  /// (HR 180D, CSC 1816, RSC 1814, Power 1818) so generic
  /// Chinese HR straps / cadence / power meters are found.
  List<Guid> getAllScanFilterUuids() {
    final uuids = <Guid>{};
    for (final c in _coordinators) {
      uuids.addAll(c.scanFilterUuids);
    }
    // Generic sports sensors — must be included or pure CSC/Power
    // devices advertising only 1816/1814/1818 are invisible in filtered scan.
    uuids.addAll([
      Guid('0000180d-0000-1000-8000-00805f9b34fb'), // HR
      Guid('00001816-0000-1000-8000-00805f9b34fb'), // CSC
      Guid('00001814-0000-1000-8000-00805f9b34fb'), // RSC
      Guid('00001818-0000-1000-8000-00805f9b34fb'), // Power
    ]);
    return uuids.toList();
  }

  /// Get all scan filter UUIDs as Guid strings for unfiltered scan fallback.
  List<Guid> getStandardServiceUuids() {
    return [
      Guid('0000180d-0000-1000-8000-00805f9b34fb'), // Heart Rate
      Guid('00001816-0000-1000-8000-00805f9b34fb'), // Cycling Speed & Cadence
      Guid('00001814-0000-1000-8000-00805f9b34fb'), // Running Speed & Cadence
      Guid('00001818-0000-1000-8000-00805f9b34fb'), // Cycling Power
      Guid('0000fee0-0000-1000-8000-00805f9b34fb'), // Mi Band 1
      Guid('0000fee1-0000-1000-8000-00805f9b34fb'), // Mi Band 2+ / Huami
    ];
  }
}
