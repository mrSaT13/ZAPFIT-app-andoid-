import 'package:get_it/get_it.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/auth_service.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/services/activity_sync_service.dart';
import 'package:zapfit/core/services/steps_counter_service.dart';

final getIt = GetIt.instance;
final serviceLocator = getIt;

void setupServiceLocator() {
  serviceLocator.registerLazySingleton<ApiClient>(() => ApiClient());
  serviceLocator.registerLazySingleton<AuthService>(() => AuthService());
  serviceLocator.registerLazySingleton<HealthService>(() => HealthService());
  serviceLocator.registerLazySingleton<ActivitySyncService>(() => ActivitySyncService());
  serviceLocator.registerLazySingleton<StepsCounterService>(() => StepsCounterService.instance);
}
