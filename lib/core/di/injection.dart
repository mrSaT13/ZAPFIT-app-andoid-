import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/services/bluetooth_sensor_service.dart';
import 'package:zapfit/core/services/scale_ble_service.dart';
// import 'package:zapfit/core/services/google_fit_service.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/services/activity_sync_service.dart';
import 'package:zapfit/core/services/auth_service.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/user_service.dart';
import 'package:zapfit/core/services/gear_service.dart';
import 'package:zapfit/core/services/feed_service.dart';
import 'package:zapfit/core/services/notification_service.dart';
import 'package:zapfit/core/services/activity_stream_service.dart';
import 'package:zapfit/core/services/websocket_service.dart';
import 'package:zapfit/core/services/goals_service.dart';
import 'package:flutter/foundation.dart';

/// Initialize and register singletons used by the app.
///
/// [comment removed - encoding corrupted]
/// [comment removed - encoding corrupted]
/// [comment removed - encoding corrupted]
/// [comment removed - encoding corrupted]
Future<void> initServiceLocator() async {
  // [comment removed - encoding corrupted]
  serviceLocator.registerLazySingleton<AuthService>(() => AuthService());
  serviceLocator.registerLazySingleton<ApiClient>(() => ApiClient());
  serviceLocator.registerLazySingleton<UserService>(() => UserService());
  serviceLocator.registerLazySingleton<GearService>(() => GearService());
  serviceLocator.registerLazySingleton<FeedService>(() => FeedService());
  serviceLocator.registerLazySingleton<NotificationService>(() => NotificationService());
  serviceLocator.registerLazySingleton<WebSocketService>(() => WebSocketService());
  serviceLocator.registerLazySingleton<ActivitySyncService>(() => ActivitySyncService());
  serviceLocator.registerLazySingleton<ActivityStreamService>(() => ActivityStreamService());
  serviceLocator.registerLazySingleton<HealthService>(() => HealthService());

  // [comment removed - encoding corrupted]
  // [comment removed - encoding corrupted]
  serviceLocator.registerLazySingleton<BluetoothSensorService>(() {
    final ble = BluetoothSensorService();
    ble.init().catchError((e) => debugPrint('BLE Init background error: $e'));
    return ble;
  });

  serviceLocator.registerLazySingleton<ScaleBleService>(() => ScaleBleService());

  // serviceLocator.registerLazySingleton<GoogleFitService>(() {
  //   final gf = GoogleFitService();
  //   gf.init().catchError((e) => debugPrint('GoogleFit init error: $e'));
  //   return gf;
  // });

  serviceLocator.registerLazySingleton<GoalsService>(() => GoalsService.instance);
}
