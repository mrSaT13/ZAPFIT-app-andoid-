import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:zapfit/core/services/activity_sync_service.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/services/local_notification_service.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/steps_counter_service.dart';
import 'package:zapfit/core/di/service_locator.dart';

const _kAutoSyncTaskName = 'com.dev.zapfit.autoSync';
const _kNotifPollingTaskName = 'com.dev.zapfit.notifPolling';

/// Background sync status.
enum AutoSyncStatus { idle, syncing, success, error, offline }

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await AppSettingsController.instance.load();

      if (taskName == _kNotifPollingTaskName) {
        return await _pollNotifications();
      }

      // Default: auto-sync task
      if (!AppSettingsController.instance.autoSyncEnabled) return true;

      final apiClient = ApiClient();
      try {
        final health = await apiClient.get('/api/v1/health').timeout(const Duration(seconds: 5));
        if (health.statusCode != 200) {
          debugPrint('AutoSync: Server health check failed (${health.statusCode})');
          return true;
        }
      } catch (e) {
        debugPrint('AutoSync: Server unreachable: $e');
        return true;
      }

      final syncService = ActivitySyncService();
      final result = await syncService.syncAll();

      if (result.error != null) {
        debugPrint('AutoSync background error: ${result.error}');
      } else if (result.total > 0) {
        await LocalNotificationService.instance.showSyncSuccess(result.total);
      }

      try {
        await AppSettingsController.instance.load();
        if (AppSettingsController.instance.stepsAutoSyncEnabled) {
          await StepsCounterService.instance.tickAutoSync();
        }
      } catch (e) {
        debugPrint('AutoSync background: steps sync failed: $e');
      }

      // Also sync unsynced health data (weight/sleep/water/steps) to server
      try {
        final healthService = HealthService();
        await healthService.loadLocalData();
        await healthService.syncAll();
        debugPrint('AutoSync background: health data sync completed');
      } catch (e) {
        debugPrint('AutoSync background: health sync failed: $e');
      }
    } catch (e) {
      debugPrint('AutoSync background critical error: $e');
    }
    return true;
  });
}

/// Background notification polling — checks server for new unread
/// notifications and shows a local notification when found.
Future<bool> _pollNotifications() async {
  try {
    if (!AppSettingsController.instance.notifPollingEnabled) return true;

    final apiClient = ApiClient();
    try {
      final health = await apiClient.get('/api/v1/health').timeout(const Duration(seconds: 5));
      if (health.statusCode != 200) return true;
    } catch (_) {
      return true;
    }

    final response = await apiClient.get('/api/v1/notifications/number').timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return true;

    final count = int.tryParse(response.body) ?? 0;
    if (count > 0) {
      // Fetch the latest notification details
      final listResponse = await apiClient.get('/api/v1/notifications/page_number/1/num_records/1').timeout(const Duration(seconds: 10));
      if (listResponse.statusCode == 200) {
        final data = json.decode(listResponse.body) as List<dynamic>;
        if (data.isNotEmpty) {
          final notif = data.first as Map<String, dynamic>;
          final options = notif['options'] as Map<String, dynamic>?;
          final type = (notif['type'] as num?)?.toInt();
          final title = _notifTitle(type);
          final body = _notifBody(type, options);

          await LocalNotificationService.instance.showServerNotification(
            id: (notif['id'] as num).toInt(),
            title: title,
            body: body,
          );
        }
      }
    }
  } catch (e) {
    debugPrint('NotifPolling background error: $e');
  }
  return true;
}

String _notifTitle(int? type) {
  switch (type) {
    case 1: return 'Новая активность';
    case 2: return 'Дубликат активности';
    case 11: return 'Запрос на подписку';
    case 12: return 'Подписка принята';
    case 21: return 'Токен Garmin истёк';
    case 101: return 'Заявка на регистрацию';
    default: return 'Новое уведомление';
  }
}

String _notifBody(int? type, Map<String, dynamic>? options) {
  switch (type) {
    case 1: return 'Новая тренировка добавлена в ленту';
    case 2: return 'Обнаружен дубликат тренировки';
    case 11: {
      final name = options?['user_name'] as String? ?? 'Пользователь';
      return '$name хочет подписаться на вас';
    }
    case 12: {
      final name = options?['user_name'] as String? ?? 'Пользователь';
      return '$name принял вашу подписку';
    }
    case 21: return 'Переподключите Garmin Connect в настройках';
    case 101: {
      final name = options?['user_name'] as String? ?? 'Пользователь';
      return '$name запросил регистрацию';
    }
    default: return 'У вас новое уведомление';
  }
}

class AutoSyncService extends ChangeNotifier {
  AutoSyncService._();
  static final AutoSyncService instance = AutoSyncService._();

  Timer? _timer;
  bool _wmInitialized = false;
  DateTime? _lastSync;
  String? _lastError;
  AutoSyncStatus _status = AutoSyncStatus.idle;
  int _lastSyncedCount = 0;

  DateTime? get lastSync => _lastSync;
  String? get lastError => _lastError;
  AutoSyncStatus get status => _status;
  int get lastSyncedCount => _lastSyncedCount;
  bool get isSyncing => _status == AutoSyncStatus.syncing;

  Future<void> init() async {
    try {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      _wmInitialized = true;
    } catch (e) {
      debugPrint('Workmanager init failed: $e');
    }
    _applySettings();
    AppSettingsController.instance.addListener(_applySettings);

    Future.microtask(() async {
      try {
        await StepsCounterService.instance.tickAutoSync();
      } catch (e) {
        debugPrint('AutoSyncService.init: steps tick failed: $e');
      }
    });
  }

  void _applySettings() {
    final s = AppSettingsController.instance;
    if (s.autoSyncEnabled) {
      _startTimer(s.autoSyncIntervalMinutes);
      if (_wmInitialized) {
        _registerWorkmanagerTask(_kAutoSyncTaskName, s.autoSyncIntervalMinutes);
      }
    } else {
      _stopTimer();
      if (_wmInitialized) {
        Workmanager().cancelByUniqueName(_kAutoSyncTaskName);
      }
    }

    // Notification polling
    if (s.notifPollingEnabled) {
      if (_wmInitialized) {
        _registerWorkmanagerTask(_kNotifPollingTaskName, s.notifPollingIntervalMinutes);
      }
    } else {
      if (_wmInitialized) {
        Workmanager().cancelByUniqueName(_kNotifPollingTaskName);
      }
    }
  }

  void _startTimer(int intervalMinutes) {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _runForegroundSync(),
    );
    Timer(const Duration(seconds: 30), () {
      if (AppSettingsController.instance.autoSyncEnabled) {
        _runForegroundSync();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _registerWorkmanagerTask(String taskName, int intervalMinutes) async {
    try {
      final period = Duration(minutes: intervalMinutes < 15 ? 15 : intervalMinutes);
      await Workmanager().registerPeriodicTask(
        taskName,
        taskName,
        frequency: period,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
    } catch (_) {}
  }

  Future<bool> runSyncNow() async {
    if (_status == AutoSyncStatus.syncing) return false;
    return _runForegroundSync();
  }

  Future<bool> _runForegroundSync() async {
    if (_status == AutoSyncStatus.syncing) return false;
    _setStatus(AutoSyncStatus.syncing);
    try {
      final apiClient = serviceLocator<ApiClient>();
      try {
        await apiClient.get('/api/v1/health').timeout(const Duration(seconds: 5));
      } catch (_) {
        _setStatus(AutoSyncStatus.offline);
        return false;
      }

      final syncService = serviceLocator<ActivitySyncService>();
      final result = await syncService.syncAll();
      _lastSync = DateTime.now();
      _lastSyncedCount = result.total;

      try {
        if (AppSettingsController.instance.stepsAutoSyncEnabled) {
          await StepsCounterService.instance.tickAutoSync();
        }
      } catch (e) {
        debugPrint('AutoSync foreground: steps sync failed: $e');
      }

      try {
        final healthService = serviceLocator<HealthService>();
        await healthService.autoImportFromHealthConnect(force: true);
        await healthService.syncAll();
      } catch (e) {
        debugPrint('AutoSync foreground: health sync failed: $e');
      }

      if (result.total > 0) {
        await LocalNotificationService.instance.showSyncSuccess(result.total);
        _setStatus(AutoSyncStatus.success);
        return true;
      } else if (result.error != null) {
        _lastError = result.error;
        _setStatus(AutoSyncStatus.error);
        return false;
      } else {
        _setStatus(AutoSyncStatus.success);
        return true;
      }
    } catch (e) {
      _lastError = e.toString();
      _setStatus(AutoSyncStatus.error);
      return false;
    }
  }

  void _setStatus(AutoSyncStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  void dispose() {
    AppSettingsController.instance.removeListener(_applySettings);
    _stopTimer();
    super.dispose();
  }
}
