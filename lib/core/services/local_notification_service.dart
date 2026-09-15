import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Handles all local (device) notifications: ongoing activity, sync status, upload success.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const int _activityNotifId = 1;
  static const int _syncNotifId = 2;
  static const int _uploadNotifId = 3;
  static const int _errorNotifId = 4;

  static const String _activityChannelId = 'activity_tracking';
  static const String _syncChannelId = 'sync_status';
  static const String _errorChannelId = 'error_reports';
  static const String _serverChannelId = 'server_notifications';
  static const String _gearWearChannelId = 'gear_wear';
  static const int _gearWearNotifId = 6;
  static const String _goalChannelId = 'goal_achievements';
  static const int _goalNotifId = 7;

  void Function()? _onPauseAction;
  void Function()? _onResumeAction;
  void Function()? _onStopAction;

  void setActivityCallbacks({
    required void Function() onPause,
    required void Function() onResume,
    required void Function() onStop,
  }) {
    _onPauseAction = onPause;
    _onResumeAction = onResume;
    _onStopAction = onStop;
  }

  void clearActivityCallbacks() {
    _onPauseAction = null;
    _onResumeAction = null;
    _onStopAction = null;
  }

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _backgroundResponseHandler,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _activityChannelId,
        'Запись активности',
        description: 'Текущая тренировка',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _syncChannelId,
        'Синхронизация',
        description: 'Статус синхронизации с сервером',
        importance: Importance.defaultImportance,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _errorChannelId,
        'Ошибки и предупреждения',
        importance: Importance.high,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _serverChannelId,
        'Уведомления сервера',
        description: 'Новые уведомления с сервера ZAPFIT',
        importance: Importance.high,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _gearWearChannelId,
        'Износ снаряжения',
        description: 'Предупреждения об износе компонентов снаряжения',
        importance: Importance.high,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _goalChannelId,
        'Достижение целей',
        description: 'Уведомления о достижении целей',
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  void _onResponse(NotificationResponse response) {
    switch (response.actionId) {
      case 'pause':
        _onPauseAction?.call();
      case 'resume':
        _onResumeAction?.call();
      case 'stop':
        _onStopAction?.call();
    }
  }

  Future<void> showActivityNotification({
    required String kindLabel,
    required double distanceKm,
    required int elapsedSeconds,
    required bool isPaused,
  }) async {
    if (!_initialized) await init();
    await _doShowActivity(kindLabel, distanceKm, elapsedSeconds, isPaused);
  }

  void updateActivityNotification({
    required String kindLabel,
    required double distanceKm,
    required int elapsedSeconds,
    required bool isPaused,
  }) {
    if (!_initialized) return;
    _doShowActivity(kindLabel, distanceKm, elapsedSeconds, isPaused);
  }

  Future<void> cancelActivityNotification() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_activityNotifId);
    } catch (e) {
      debugPrint('Error cancelling activity notification: $e');
    }
  }

  Future<void> _doShowActivity(
    String kindLabel,
    double distanceKm,
    int elapsedSeconds,
    bool isPaused,
  ) async {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    final time = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    final androidDetails = AndroidNotificationDetails(
      _activityChannelId,
      'Запись активности',
      channelDescription: 'Текущая тренировка',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      icon: 'ic_notification',
      actions: [
        if (isPaused)
          const AndroidNotificationAction('resume', 'Продолжить', showsUserInterface: true)
        else
          const AndroidNotificationAction('pause', 'Пауза', showsUserInterface: true),
        const AndroidNotificationAction('stop', 'Стоп', showsUserInterface: true, cancelNotification: false),
      ],
    );

    try {
      await _plugin.show(
        _activityNotifId,
        isPaused ? '⏸ $kindLabel — пауза' : '● $kindLabel',
        '${distanceKm.toStringAsFixed(2)} км · $time',
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Error showing activity notification: $e');
    }
  }

  Future<void> showSyncSuccess(int count) async {
    if (!_initialized) await init();
    final msg = count == 0
        ? 'Нет новых активностей'
        : 'Обновлено: $count ${_plural(count, 'активность', 'активности', 'активностей')}';
    try {
      await _plugin.show(
        _syncNotifId,
        'Синхронизация завершена',
        msg,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _syncChannelId,
            'Синхронизация',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            autoCancel: true,
            icon: 'ic_notification',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing sync notification: $e');
    }
  }

  Future<void> showSyncError(String message) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        _syncNotifId,
        'Ошибка синхронизации',
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _syncChannelId,
            'Синхронизация',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            autoCancel: true,
            icon: 'ic_notification',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing sync error notification: $e');
    }
  }

  Future<void> showError(String title, String message) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        _errorNotifId,
        title,
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _errorChannelId,
            'Ошибки',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing error notification: $e');
    }
  }

  Future<void> showUploadSuccess(String activityTitle) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        _uploadNotifId,
        '✓ Активность загружена',
        activityTitle,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _syncChannelId,
            'Синхронизация',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            autoCancel: true,
            icon: 'ic_notification',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing upload notification: $e');
    }
  }

  Future<void> showServerNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _serverChannelId,
            'Уведомления сервера',
            channelDescription: 'Новые уведомления с сервера ZAPFIT',
            importance: Importance.high,
            priority: Priority.high,
            autoCancel: true,
            icon: 'ic_notification',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing server notification: $e');
    }
  }

  /// Schedule a daily weight reminder notification at exact time
  void scheduleWeightReminder(DateTime scheduledDate, int hour, int minute) async {
    try {
      if (!_initialized) await init();

      // Cancel any existing weight reminder first
      await _plugin.cancel(5);

      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'weight_reminders',
        'Напоминания о весе',
        channelDescription: 'Ежедневные напоминания о взвешивании',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
      );
      const details = NotificationDetails(android: androidDetails);

      await _plugin.zonedSchedule(
        5,
        'Взвешивание',
        'Не забудьте взвеситься!',
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Error scheduling weight reminder: $e');
      // Fallback: use periodicallyShow if zonedSchedule fails
      try {
        const androidDetails = AndroidNotificationDetails(
          'weight_reminders',
          'Напоминания о весе',
          channelDescription: 'Ежедневные напоминания о взвешивании',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        );
        const details = NotificationDetails(android: androidDetails);
        _plugin.periodicallyShow(
          5,
          'Взвешивание',
          'Не забудьте взвеситься!',
          RepeatInterval.daily,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e2) {
        debugPrint('Fallback weight reminder also failed: $e2');
      }
    }
  }

  /// Cancel weight reminder
  void cancelWeightReminder() {
    _plugin.cancel(5);
  }

  /// Show gear wear warning notification
  Future<void> showGearWearWarning(String title, String body) async {
    if (!_initialized) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _gearWearChannelId,
        'Износ снаряжения',
        icon: 'ic_notification',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(_gearWearNotifId, title, body, details);
  }

  /// Show goal achieved notification
  Future<void> showGoalAchieved(String title, String body) async {
    if (!_initialized) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _goalChannelId,
        'Достижение целей',
        icon: 'ic_notification',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(_goalNotifId, title, body, details);
  }

  String _plural(int n, String one, String few, String many) {
    if (n % 100 >= 11 && n % 100 <= 19) return many;
    switch (n % 10) {
      case 1: return one;
      case 2:
      case 3:
      case 4: return few;
      default: return many;
    }
  }
}

@pragma('vm:entry-point')
void _backgroundResponseHandler(NotificationResponse response) {}
