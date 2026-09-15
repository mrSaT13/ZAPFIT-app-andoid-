import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/local_notification_service.dart';
import 'package:zapfit/core/services/location_service.dart';
import 'package:zapfit/core/services/bluetooth_sensor_service.dart';
import 'package:zapfit/core/services/gear_service.dart';
import 'package:zapfit/core/services/goals_service.dart';
import 'package:zapfit/core/services/background_tracking_service.dart';
import 'package:zapfit/core/services/voice_coach_service.dart';
import 'package:zapfit/core/utils/gps_kalman_filter.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class ActivityTrackingService {
  ActivityTrackingService._();

  static final ActivityTrackingService instance = ActivityTrackingService._();

  final LocalActivityRepository _repository = LocalActivityRepository.instance;
  final LocationService _locationService = LocationService();
  final StreamController<TrackingSnapshot> _snapshotController =
      StreamController<TrackingSnapshot>.broadcast();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Position>? _bgPositionSubscription;
  StreamSubscription<int>? _hrSubscription;
  StreamSubscription<int>? _cadenceSubscription;
  StreamSubscription<double>? _powerSubscription;
  Timer? _ticker;

  TrackingSnapshot _snapshot = TrackingSnapshot.empty;
  ActivityPoint? _lastPoint;
  DateTime? _startedAt;
  Duration _pauseTotal = Duration.zero;
  DateTime? _pausedAt;

  double _totalDistance = 0.0;
  int _pointsCount = 0;
  int _lastAnnouncedKm = 0;
  DateTime _lastPaceAnnounceTime = DateTime(0);

  int? _currentHeartRate;
  int? _currentCadence;
  double? _currentPower;

  int _notifTick = 0;

  // Auto-pause state
  DateTime? _lowSpeedSince;
  DateTime? _autoPauseStartedAt; // когда начался авто-пауз
  bool _isAutoPaused = false;

  // Timestamp of the last background-forwarded position, used to reject
  // stale foreground positions that arrive after returning from background.
  DateTime? _lastBgTimestamp;
  final GpsKalmanFilter _kalman = GpsKalmanFilter();

  Stream<TrackingSnapshot> get snapshotStream => _snapshotController.stream;
  TrackingSnapshot get currentSnapshot => _snapshot;

  // === Persist для восстановления после убийства процесса (переключение/блокировка) ===
  static const _kOngoingKey = 'ongoing_activity_v1';
  bool _isRestoring = false;

  Future<void> tryRestoreOngoingActivity() async {
    if (_isRestoring) return;
    _isRestoring = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kOngoingKey);
      if (raw == null) return;
      // ожидаем что в БД есть незавершённая активность (ended_at_ms IS NULL)
      final parts = raw.split('|');
      if (parts.length < 4) return;
      final id = int.tryParse(parts[0]);
      final kindName = parts[1];
      final startedAtMs = int.tryParse(parts[2]);
      final pauseTotalSec = int.tryParse(parts[3]) ?? 0;
      if (id == null || startedAtMs == null) return;
      if (_snapshot.isRecording) return; // уже идёт

      final record = await _repository.getActivity(id);
      if (record == null || record.endedAt != null) {
        await prefs.remove(_kOngoingKey);
        return;
      }
      final points = await _repository.getPoints(id);
      double dist = 0;
      if (points.isNotEmpty) {
        dist = points.last.distanceFromStartMeters;
        if (dist == 0 && points.length >= 2) dist = _recomputeDistanceFromPoints(points);
      }
      final kind = ActivityKind.values.firstWhere((k) => k.name == kindName, orElse: () => record.kind);
      _snapshot = TrackingSnapshot(
        isRecording: true,
        isPaused: record.endedAt != null ? false : _pausedAt != null,
        activityId: id,
        kind: kind,
        startedAt: DateTime.fromMillisecondsSinceEpoch(startedAtMs),
        distanceMeters: dist,
        elapsedSeconds: DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(startedAtMs)).inSeconds - pauseTotalSec,
        pointsCount: points.length,
      );
      _startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
      _pauseTotal = Duration(seconds: pauseTotalSec);
      _totalDistance = dist;
      _pointsCount = points.length;
      _lastPoint = points.isNotEmpty ? points.last : null;
      // восстановить bg подписку и тикер
      _kalman.reset();
      _restartBgPositionSubscription();
      _startTicker();
      AppSettingsController.instance.addListener(_handleSettingsChanged);
      LocalNotificationService.instance.setActivityCallbacks(onPause: () { pause(); }, onResume: () { resume(); }, onStop: () { stop(); });
      // проверить что фоновый сервис жив — если нет, перезапустить
      try {
        final bg = BackgroundTrackingService.instance;
        final running = await bg.isServiceRunning();
        if (!running) {
          await bg.init();
          await bg.startTracking(kindLabel: kind.labelRu, activityId: id, distanceFilterMeters: AppSettingsController.instance.gpsDistanceFilter, intervalSeconds: AppSettingsController.instance.gpsUpdateIntervalSeconds);
          _restartBgPositionSubscription();
        }
      } catch (_) {}
      _emit();
      debugPrint('TrackingService: restored ongoing activity $id dist=$dist pts=${points.length}');
    } catch (e) {
      debugPrint('Restore ongoing failed: $e');
    } finally {
      _isRestoring = false;
    }
  }

  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_snapshot.isRecording || _snapshot.activityId == null || _startedAt == null) {
        await prefs.remove(_kOngoingKey);
        return;
      }
      final v = '${_snapshot.activityId}|${_snapshot.kind?.name ?? ''}|${_startedAt!.millisecondsSinceEpoch}|${_pauseTotal.inSeconds}|${_snapshot.isPaused ? 1 : 0}';
      await prefs.setString(_kOngoingKey, v);
    } catch (_) {}
  }

  Future<void> _clearPersistedState() async {
    try { final p = await SharedPreferences.getInstance(); await p.remove(_kOngoingKey); } catch (_) {}
  }

  void _handleSettingsChanged() {
    if (_snapshot.isRecording && !_snapshot.isPaused) {
      debugPrint('TrackingService: settings changed, restarting GPS stream');
      _restartPositionSubscription();
    }
  }

  Future<void> _ensureBackgroundLocationPermission() async {
    try {
      // Сначала убеждаемся что foreground разрешён
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      // Android 12+ FIX: проверка точного местоположения (Precise vs Approximate)
      // Samsung с Approximate даёт city-level координаты -> 0.06км вместо 4.12км
      try {
        final accuracyStatus = await Geolocator.getLocationAccuracy();
        final isPrecise = accuracyStatus.toString().contains('precise');
        if (!isPrecise) {
          debugPrint('WARNING: LocationAccuracy is REDUCED (approximate) — distance will be wrong! Requesting precise...');
          // Повторный запрос часто триггерит системный диалог уточнения
          await Geolocator.requestPermission();
          final retryStatus = await Geolocator.getLocationAccuracy();
          if (!retryStatus.toString().contains('precise')) {
            debugPrint('Precise location still not granted — user must enable Точное местоположение in settings');
          }
        }
      } catch (_) {
        // API not available on Android <12, ignore
      }
      // Пробуем запросить always через permission_handler (нужно для записи с выкл экраном)
      // Samsung Android 12 без always режет GPS в фоне -> 0.06км
      if (await Permission.locationWhenInUse.isGranted) {
        final alwaysStatus = await Permission.locationAlways.status;
        if (alwaysStatus.isDenied) {
          debugPrint('Requesting ACCESS_BACKGROUND_LOCATION for Samsung/Android12...');
          final res = await Permission.locationAlways.request();
          if (res.isPermanentlyDenied || res.isDenied) {
            debugPrint('BACKGROUND_LOCATION denied — background tracking will be throttled on Samsung!');
          }
        }
      }
      // Запрос игнорирования оптимизации батареи (Doze) — критично для Xiaomi/Samsung
      if (await Permission.ignoreBatteryOptimizations.status.isDenied) {
        debugPrint('Requesting ignoreBatteryOptimizations...');
        final res = await Permission.ignoreBatteryOptimizations.request();
        if (res.isDenied) {
          debugPrint('Battery optimization still enabled — background GPS may be throttled on Xiaomi/Samsung');
        }
      }
    } catch (e) {
      debugPrint('Background permission check error: $e');
    }
  }

  Future<void> start(ActivityKind kind) async {
    if (_snapshot.isRecording) return;

    try {
      final now = DateTime.now();
      final title = '${kind.labelRu} ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      debugPrint('TrackingService: STARTING activity $kind');

      // [comment removed - encoding corrupted]
      _snapshot = TrackingSnapshot(
        isRecording: true,
        isPaused: false,
        activityId: null,
        kind: kind,
        startedAt: now,
        distanceMeters: 0,
        elapsedSeconds: 0,
        pointsCount: 0,
      );
      _emit();
      unawaited(_persistState());

      // [comment removed - encoding corrupted]
      _startedAt = now;
      _pauseTotal = Duration.zero;
      _pausedAt = null;
      _lastPoint = null;
      _totalDistance = 0.0;
      _pointsCount = 0;
      _lastAnnouncedKm = 0;
      _lastPaceAnnounceTime = DateTime(0);
      _notifTick = 0;
      _currentHeartRate = null;
      _currentCadence = null;
      _currentPower = null;

      // Pre-fill with last known BLE values
      try {
        final ble = serviceLocator<BluetoothSensorService>();
        if (ble.lastHeartRate != null) _currentHeartRate = ble.lastHeartRate;
      } catch (_) {}
      _lastBgTimestamp = null;
      _lowSpeedSince = null;
      _autoPauseStartedAt = null;
      _isAutoPaused = false;
      _kalman.reset();

      // [comment removed - encoding corrupted]
      final activityId = await _repository.createActivity(
        ActivityRecord(
          title: title,
          kind: kind,
          startedAt: now,
        ),
      ).catchError((e) {
        debugPrint('TrackingService: DB Error creating activity: $e');
        return null;
      });

      if (activityId == null) {
        debugPrint('TrackingService: Failed to create activity, aborting');
        return;
      }

      _snapshot = _snapshot.copyWith(activityId: activityId);
      _emit();
      unawaited(_persistState());
      _applyDefaultGear(kind, activityId);

      // [comment removed - encoding corrupted]
      LocalNotificationService.instance.setActivityCallbacks(
        onPause: () { pause(); },
        onResume: () { resume(); },
        onStop: () { stop(); },
      );
      
      // [comment removed - encoding corrupted]
      LocalNotificationService.instance.showActivityNotification(
        kindLabel: kind.labelRu,
        distanceKm: 0,
        elapsedSeconds: 0,
        isPaused: false,
      ).catchError((e) => debugPrint('TrackingService: Notif error: $e'));

      // Permissions: ensure background location for locked screen
      await _ensureBackgroundLocationPermission();

      // [comment removed - encoding corrupted]
      _startSensorSubscriptions();
      await _restartPositionSubscription();
      // Live реагирование на изменение интервала/фильтра в настройках
      AppSettingsController.instance.addListener(_handleSettingsChanged);
      _startTicker();

      // Start background tracking service and subscribe to its position updates
      try {
        final bgService = BackgroundTrackingService.instance;
        await bgService.init();
        await bgService.startTracking(
          kindLabel: kind.labelRu,
          activityId: activityId,
          distanceFilterMeters: AppSettingsController.instance.gpsDistanceFilter,
          intervalSeconds: AppSettingsController.instance.gpsUpdateIntervalSeconds,
        );

        // Subscribe to positions forwarded from the background isolate.
        // This ensures distance keeps accumulating when the app is backgrounded
        // and the main position stream stops.
        _bgPositionSubscription?.cancel();
        _bgPositionSubscription = bgService.positionFromBackground.listen((position) {
          if (_snapshot.activityId != null && _snapshot.isRecording && !_snapshot.isPaused) {
            _lastBgTimestamp = position.timestamp;
            _processNewPosition(position, _snapshot.activityId!);
          }
        });
      } catch (e) {
        debugPrint('Background tracking start failed: $e');
      }

      debugPrint('TrackingService: Activity start sequence complete');
    } catch (e, stack) {
      debugPrint('TrackingService: CRITICAL START ERROR: $e\n$stack');
      _snapshot = TrackingSnapshot.empty;
      _emit();
      rethrow;
    }
  }

  Future<void> _applyDefaultGear(ActivityKind kind, int activityId) async {
    try {
      final gearService = serviceLocator<GearService>();
      String? gearKey;
      if (kind == ActivityKind.run || kind == ActivityKind.trackRun || kind == ActivityKind.treadmillRun) {
        gearKey = 'run_gear_id';
      } else if (kind == ActivityKind.trailRun) {
        gearKey = 'trail_run_gear_id';
      } else if (kind == ActivityKind.roadCycling) {
        gearKey = 'ride_gear_id';
      } else if (kind == ActivityKind.mtbCycling) {
        gearKey = 'mtb_ride_gear_id';
      } else if (kind == ActivityKind.gravelCycling) {
        gearKey = 'gravel_ride_gear_id';
      } else if (kind == ActivityKind.walk || kind == ActivityKind.indoorWalk) {
        gearKey = 'walk_gear_id';
      } else if (kind == ActivityKind.hike) {
        gearKey = 'hike_gear_id';
      }

      if (gearKey != null) {
        final gearId = gearService.defaultGears[gearKey];
        if (gearId != null) {
          final record = await _repository.getActivity(activityId);
          if (record != null) {
            await _repository.updateActivity(record.copyWith(gearId: gearId));
          }
        }
      }
    } catch (_) {}
  }

  void _startSensorSubscriptions() {
    try {
      final ble = serviceLocator<BluetoothSensorService>();
      _hrSubscription?.cancel();
      _hrSubscription = ble.heartRate.listen((hr) {
        _currentHeartRate = hr;
        _checkHrAlert();
      });
      _cadenceSubscription?.cancel();
      _cadenceSubscription = ble.cadence.listen((cad) {
        _currentCadence = cad;
      });
      _powerSubscription?.cancel();
      _powerSubscription = ble.power.listen((pwr) {
        _currentPower = pwr;
      });
    } catch (e) {
      debugPrint('TrackingService: Sensors error: $e');
    }
  }

  void _stopSensorSubscriptions() {
    _hrSubscription?.cancel();
    _hrSubscription = null;
    _cadenceSubscription?.cancel();
    _cadenceSubscription = null;
    _powerSubscription?.cancel();
    _powerSubscription = null;
  }

  Future<void> pause() async {
    if (!_snapshot.isRecording || _snapshot.isPaused) return;
    _pausedAt = DateTime.now();
    _snapshot = _snapshot.copyWith(isPaused: true);
    unawaited(_persistState());
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    _bgPositionSubscription?.cancel();
    _bgPositionSubscription = null;
    _ticker?.cancel();
    _ticker = null;
    _emit();
    LocalNotificationService.instance.updateActivityNotification(
      kindLabel: _snapshot.kind?.labelRu ?? 'Активность',
      distanceKm: _snapshot.distanceMeters / 1000,
      elapsedSeconds: _snapshot.elapsedSeconds,
      isPaused: true,
    );
    try {
      BackgroundTrackingService.instance.updateNotification(
        kindLabel: _snapshot.kind?.labelRu ?? 'Активность',
        distanceKm: _snapshot.distanceMeters / 1000,
        elapsedSeconds: _snapshot.elapsedSeconds,
        isPaused: true,
      );
    } catch (_) {}
  }

  Future<void> resume() async {
    if (!_snapshot.isRecording || !_snapshot.isPaused) return;
    if (_pausedAt != null) _pauseTotal += DateTime.now().difference(_pausedAt!);
    _pausedAt = null;
    _snapshot = _snapshot.copyWith(isPaused: false);
    unawaited(_persistState());
    await _restartPositionSubscription();
    _restartBgPositionSubscription();
    _startTicker();
    _emit();
    LocalNotificationService.instance.updateActivityNotification(
      kindLabel: _snapshot.kind?.labelRu ?? 'Активность',
      distanceKm: _snapshot.distanceMeters / 1000,
      elapsedSeconds: _snapshot.elapsedSeconds,
      isPaused: false,
    );
    try {
      BackgroundTrackingService.instance.updateNotification(
        kindLabel: _snapshot.kind?.labelRu ?? 'Активность',
        distanceKm: _snapshot.distanceMeters / 1000,
        elapsedSeconds: _snapshot.elapsedSeconds,
        isPaused: false,
      );
    } catch (_) {}
  }

  Future<int?> stop({bool discard = false}) async {
    final activityId = _snapshot.activityId;
    if (!_snapshot.isRecording) return null;

    final durationSeconds = _computeElapsedSeconds();
    bool shouldDiscard = discard || durationSeconds < 5;

    try { AppSettingsController.instance.removeListener(_handleSettingsChanged); } catch (_) {}
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    _bgPositionSubscription?.cancel();
    _bgPositionSubscription = null;
    _ticker?.cancel();
    _ticker = null;
    _stopSensorSubscriptions();

    int? savedActivityId;

    if (activityId != null) {
      if (shouldDiscard) {
        await _repository.deleteActivity(activityId);
      } else {
        final points = await _repository.getPoints(activityId);
        int? avgHr;
        int? maxHr;
        if (points.isNotEmpty) {
          final hrPoints = points.where((p) => p.heartRate != null && p.heartRate! > 0).map((p) => p.heartRate!);
          if (hrPoints.isNotEmpty) {
            avgHr = (hrPoints.reduce((a, b) => a + b) / hrPoints.length).round();
            maxHr = hrPoints.reduce((a, b) => a > b ? a : b);
          }
        }

        final record = await _repository.getActivity(activityId);
        if (record != null) {
          // Пересчёт дистанции по точкам — защита от потерь фона/джиттера
          double finalDistance = _totalDistance;
          if (points.length >= 2) {
            final recomputed = _recomputeDistanceFromPoints(points);
            // если расхождение >5% и >3м — берём пересчитанную
            if ((recomputed - finalDistance).abs() > 3 &&
                (finalDistance == 0 || (recomputed - finalDistance).abs() / (finalDistance == 0 ? 1 : finalDistance) > 0.05)) {
              debugPrint('Distance recomputed: $_totalDistance -> $recomputed (${points.length} pts)');
              finalDistance = recomputed;
            }
          }
          await _repository.updateActivity(
            record.copyWith(
              endedAt: DateTime.now(),
              distanceMeters: finalDistance,
              durationSeconds: durationSeconds,
              avgHeartRate: avgHr,
              maxHeartRate: maxHr,
            ),
          );
        }
        savedActivityId = activityId;
        _announceFinish();
      }
    } else {
      shouldDiscard = true;
    }

    _snapshot = TrackingSnapshot.empty;
    _lastPoint = null;
    _startedAt = null;
    _totalDistance = 0.0;
    _pointsCount = 0;
    _pauseTotal = Duration.zero;
    _pausedAt = null;
    _emit();
    unawaited(_clearPersistedState());

    LocalNotificationService.instance.cancelActivityNotification();
    LocalNotificationService.instance.clearActivityCallbacks();

    if (!shouldDiscard) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_activity_end_ms', DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}

      // Check if any goal was achieved after this activity
      _checkGoalsAchieved();
    }

    // Stop background tracking service (foreground notification)
    try {
      await BackgroundTrackingService.instance.stopTracking();
    } catch (_) {}

    return shouldDiscard ? null : savedActivityId;
  }

  Future<void> _checkGoalsAchieved() async {
    try {
      final goalsService = serviceLocator<GoalsService>();
      final progress = await goalsService.fetchGoalsProgress();
      for (final g in progress) {
        if ((g.percentageCompleted ?? 0) >= 100) {
          await LocalNotificationService.instance.showGoalAchieved(
            'Цель достигнута! 🎯',
            '${g.activityType} — ${g.goalType} (${g.interval})',
          );
        }
      }
    } catch (e) {
      debugPrint('Goals check error: $e');
    }
  }

  Timer? _gpsWatchdog;
  DateTime? _lastPositionTime;

  Future<void> _restartPositionSubscription() async {
    await _positionSubscription?.cancel();
    _gpsWatchdog?.cancel();
    _lastPositionTime = DateTime.now();
    final settings = AppSettingsController.instance;
    final kindName = _snapshot.kind?.name;
    // Для ходьбы/похода форсим минимальный фильтр чтобы не терять шаги
    final effectiveFilter = (kindName == 'walk' || kindName == 'indoorWalk' || kindName == 'hike')
        ? settings.gpsDistanceFilter.clamp(0, 1)
        : settings.gpsDistanceFilter;
    _positionSubscription = _locationService.getPositionStream(
      accuracyMode: settings.gpsAccuracy,
      distanceFilterMeters: effectiveFilter,
      intervalSeconds: settings.gpsUpdateIntervalSeconds,
      activityKind: kindName,
    ).listen((position) {
      _lastPositionTime = DateTime.now();
      if (_snapshot.activityId != null) {
        _processNewPosition(position, _snapshot.activityId!);
      }
    }, onError: (e) => debugPrint('TrackingService: GPS Error: $e'));

    // Watchdog: если нет фикса >8с — пробуем getCurrentPosition
    _gpsWatchdog = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!_snapshot.isRecording || _snapshot.isPaused) return;
      if (_lastPositionTime == null) return;
      final elapsed = DateTime.now().difference(_lastPositionTime!);
      if (elapsed.inSeconds < 8) return;
      try {
        final pos = await _locationService.getCurrentPosition();
        if (pos != null && _snapshot.activityId != null) {
          _lastPositionTime = DateTime.now();
          _processNewPosition(pos, _snapshot.activityId!);
        }
      } catch (_) {}
    });
  }

  void _restartBgPositionSubscription() {
    _bgPositionSubscription?.cancel();
    try {
      final bgService = BackgroundTrackingService.instance;
      if (bgService.isRunning) {
        _bgPositionSubscription = bgService.positionFromBackground.listen((position) {
          if (_snapshot.activityId != null && _snapshot.isRecording && !_snapshot.isPaused) {
            _lastBgTimestamp = position.timestamp;
            _processNewPosition(position, _snapshot.activityId!);
          }
        });
      }
    } catch (_) {}
  }

  void _processNewPosition(Position position, int activityId) async {
    // Kalman: сгладить и отбросить выбросы. Идея из GPSSignalIndicator.java / TrackrecordDao
    final filtered = _kalman.filter(position.latitude, position.longitude, position.accuracy);
    if (filtered == null) {
      debugPrint('GPS Kalman: выброс отброшен acc=${position.accuracy}');
      return;
    }
    // подменяем координаты отфильтрованными, скорость/alt оставляем
    position = Position(
      latitude: filtered.lat,
      longitude: filtered.lon,
      altitude: position.altitude,
      speed: position.speed,
      accuracy: position.accuracy,
      heading: position.heading,
      speedAccuracy: position.speedAccuracy,
      altitudeAccuracy: position.altitudeAccuracy,
      headingAccuracy: position.headingAccuracy,
      timestamp: position.timestamp,
    );
    // Guard: reject positions with timestamp older than the last processed point.
    // This prevents stale foreground GPS fixes (queued while backgrounded)
    // from overwriting the background isolate's accurate positions.
    if (_lastPoint != null && position.timestamp.isBefore(_lastPoint!.timestamp)) {
      return;
    }

    // speedAccuracy фильтр: если точность скорости плохая — игнорируем чип
    final rawChipSpeed = position.speed;
    final speedAcc = position.speedAccuracy;
    final isChipSpeedValid = rawChipSpeed != null &&
        rawChipSpeed.isFinite &&
        rawChipSpeed >= 0 &&
        (speedAcc == 0 || speedAcc <= 5.0);
    double? speed = isChipSpeedValid ? rawChipSpeed : null;

    if (_lastPoint != null) {
      final dDist = Geolocator.distanceBetween(
        _lastPoint!.latitude, _lastPoint!.longitude,
        position.latitude, position.longitude,
      );
      final dTime = position.timestamp.difference(_lastPoint!.timestamp).inMilliseconds / 1000.0;

      // Дедупликация по timestamp (точнее чем dTime<0.8)
      final isDuplicateTimestamp = dTime.abs() < 0.45 && dDist < 1.2;
      if (isDuplicateTimestamp) {
        // дубликат foreground+background — точку не добавляем к дистанции
      } else if (dTime > 0.3) {
        double calcSpeed = dTime > 0 ? dDist / dTime : 0;
        final maxSpeedMps = _maxSpeedForKind(_snapshot.kind);
        // reject jumps: кап по виду активности (ходьба 3 м/с) + общий 60 м/с
        if (dDist > 500 || calcSpeed > maxSpeedMps) {
          debugPrint('GPS jump rejected kind=${_snapshot.kind?.name} dDist=$dDist calcSpeed=$calcSpeed max=$maxSpeedMps');
          return;
        }
        // Динамический minDist: ходьба 1м, иначе 0.7/1.5; low-confidence джиттер
        final minDist = _dynamicMinDist(position.accuracy, _snapshot.kind);
        // low-confidence: при большой accuracy и маленьком смещении скорость — это джиттер
        final uncertainty = position.accuracy.clamp(3.0, 80.0);
        final isWalkOrRun = _snapshot.kind == ActivityKind.walk ||
            _snapshot.kind == ActivityKind.indoorWalk ||
            _snapshot.kind == ActivityKind.hike ||
            _snapshot.kind == ActivityKind.run;
        final reportedSpd = speed ?? calcSpeed;
        final lowConf = isWalkOrRun &&
            uncertainty >= 12 &&
            dDist <= uncertainty * 1.15 &&
            reportedSpd <= 2.6;
        if (lowConf) {
          debugPrint('GPS lowConf reject dDist=$dDist acc=$uncertainty spd=$reportedSpd');
          return;
        }
        final shouldAdd = dDist >= minDist && dTime < 30 && !lowConf;
        if (shouldAdd) {
          _totalDistance += dDist;
          if ((speed == null || speed <= 0.3) && calcSpeed > 0.5 && calcSpeed <= maxSpeedMps) {
            speed = calcSpeed;
          }
          // Сглаживаем скорость скользящим средним (предыдущая + текущая)
          if (_lastPoint!.speed != null && speed != null) {
            speed = (_lastPoint!.speed! * 0.6 + speed * 0.4);
          }
          // Announce km milestones
          final kmInterval = AppSettingsController.instance.voiceCoachKmInterval;
          final currentKm = (_totalDistance / 1000).floor();
          final lastAnnounced = _lastAnnouncedKm;
          if (currentKm > lastAnnounced && currentKm > 0 && currentKm % kmInterval == 0) {
            _lastAnnouncedKm = currentKm;
            _announceKm(currentKm);
          }
        } else if (dDist < minDist) {
          if ((speed == null || speed <= 0.3) && calcSpeed > 0.5 && calcSpeed <= maxSpeedMps) {
            speed = calcSpeed;
          }
        }

        // --- Auto-pause detection ---
        final settings = AppSettingsController.instance;
        if (settings.autoPauseEnabled && !_isAutoPaused) {
          final speedKmh = (speed ?? 0) * 3.6;
          if (speedKmh < settings.autoPauseSpeedThreshold) {
            if (_lowSpeedSince == null) {
              _lowSpeedSince = position.timestamp;
            } else {
              final lowSpeedDuration = position.timestamp.difference(_lowSpeedSince!);
              if (lowSpeedDuration.inSeconds >= settings.autoPauseDelaySeconds) {
                _isAutoPaused = true;
                _autoPauseStartedAt = DateTime.now();
                _lowSpeedSince = null;
                _pausedAt = DateTime.now();
                _snapshot = _snapshot.copyWith(isPaused: true);
                _emit();
                VoiceCoachService.instance.speak('Авто-пауза');
                LocalNotificationService.instance.updateActivityNotification(
                  kindLabel: _snapshot.kind?.labelRu ?? 'Активность',
                  distanceKm: _snapshot.distanceMeters / 1000,
                  elapsedSeconds: _snapshot.elapsedSeconds,
                  isPaused: true,
                );
              }
            }
          } else {
            _lowSpeedSince = null;
          }
        }

        // --- Auto-resume detection ---
        if (_isAutoPaused) {
          final speedKmh = (speed ?? 0) * 3.6;
          final autoPauseDuration = _autoPauseStartedAt != null
              ? DateTime.now().difference(_autoPauseStartedAt!).inSeconds
              : 0;
          if (speedKmh >= settings.autoPauseSpeedThreshold || autoPauseDuration > 30) {
            _isAutoPaused = false;
            _autoPauseStartedAt = null;
            if (_pausedAt != null) _pauseTotal += DateTime.now().difference(_pausedAt!);
            _pausedAt = null;
            _snapshot = _snapshot.copyWith(isPaused: false);
            _emit();
            VoiceCoachService.instance.speak('Продолжаем');
            LocalNotificationService.instance.updateActivityNotification(
              kindLabel: _snapshot.kind?.labelRu ?? 'Активность',
              distanceKm: _snapshot.distanceMeters / 1000,
              elapsedSeconds: _snapshot.elapsedSeconds,
              isPaused: false,
            );
          }
        }
      } else {
        // dTime 0.8-0.3 range but small — keep point without distance
      }
    }
    _pointsCount++;
    final point = ActivityPoint(
      activityId: activityId,
      timestamp: position.timestamp,
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speed: speed,
      accuracy: position.accuracy,
      distanceFromStartMeters: _totalDistance,
      heartRate: _currentHeartRate,
      cadence: _currentCadence,
      power: _currentPower,
    );
    _lastPoint = point;
    await _repository.addPoint(point);
    _snapshot = _snapshot.copyWith(
      distanceMeters: _totalDistance,
      elapsedSeconds: _computeElapsedSeconds(),
      pointsCount: _pointsCount,
      currentHeartRate: _currentHeartRate,
      currentCadence: _currentCadence,
    );
    _emit();
    if (_pointsCount % 10 == 0) unawaited(_persistState());
    // Проверка пульса после каждой точки (покрывает случай когда HR пришёл без BLE потока)
    _checkHrAlert();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_snapshot.isRecording || _snapshot.isPaused) return;
      _snapshot = _snapshot.copyWith(
        elapsedSeconds: _computeElapsedSeconds(),
        currentHeartRate: _currentHeartRate,
        currentCadence: _currentCadence,
      );
      _emit();
      _notifTick++;
      if (_notifTick % 5 == 0) {
        LocalNotificationService.instance.updateActivityNotification(
          kindLabel: _snapshot.kind?.labelRu ?? 'Активность',
          distanceKm: _snapshot.distanceMeters / 1000,
          elapsedSeconds: _snapshot.elapsedSeconds,
          isPaused: false,
        );
        try {
          BackgroundTrackingService.instance.updateNotification(
            kindLabel: _snapshot.kind?.labelRu ?? 'Активность',
            distanceKm: _snapshot.distanceMeters / 1000,
            elapsedSeconds: _snapshot.elapsedSeconds,
            isPaused: false,
          );
        } catch (_) {}
      }
      // Pace announcement every 60 seconds
      if (_notifTick % 60 == 0 && _snapshot.distanceMeters > 10) {
        _announcePace();
      }
    });
  }

  int _computeElapsedSeconds() {
    final startedAt = _startedAt;
    if (startedAt == null) return 0;
    final elapsed = DateTime.now().difference(startedAt) - _pauseTotal;
    return elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  }

  void _emit() {
    if (!_snapshotController.isClosed) _snapshotController.add(_snapshot);
  }

  String _kmDeclension(int km) {
    final m10 = km % 10;
    final m100 = km % 100;
    if (m10 == 1 && m100 != 11) return 'километр';
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'километра';
    return 'километров';
  }

  String _phraseForKm(int km, ActivityKind? kind) {
    final isSwim = kind == ActivityKind.openWaterSwimming || kind == ActivityKind.indoorSwimming;
    if (isSwim) {
      final meters = km * 1000;
      if (km <= 10) {
        const swimPhrases = [
          'Тысяча метров',
          'Две тысячи метров',
          'Три тысячи метров',
          'Четыре тысячи метров',
          'Пять тысяч метров',
          'Шесть тысяч метров',
          'Семь тысяч метров',
          'Восемь тысяч метров',
          'Девять тысяч метров',
          'Десять тысяч метров',
        ];
        return swimPhrases[km - 1];
      }
      return '$meters метров';
    }
    // бег / вело / ходьба — нейтрально без "проехан"
    if (km <= 10) {
      const base = [
        'Один километр',
        'Два километра',
        'Три километра',
        'Четыре километра',
        'Пять километров',
        'Шесть километров',
        'Семь километров',
        'Восемь километров',
        'Девять километров',
        'Десять километров',
      ];
      return base[km - 1];
    }
    return '$km ${_kmDeclension(km)}';
  }

  DateTime _lastHrAlertTime = DateTime.fromMillisecondsSinceEpoch(0);
  void _checkHrAlert() {
    try {
      final settings = AppSettingsController.instance;
      if (!settings.voiceCoachEnabled) return;
      if (!settings.voiceCoachHrAlertEnabled) return;
      final hr = _currentHeartRate;
      if (hr == null || hr <= 0) return;
      final maxHr = settings.userMaxHeartRate;
      if (maxHr <= 0) return;
      if (hr <= maxHr) return;
      final now = DateTime.now();
      if (now.difference(_lastHrAlertTime).inSeconds < settings.voiceCoachHrCooldownSeconds) return;
      _lastHrAlertTime = now;
      final over = hr - maxHr;
      String phrase;
      if (over >= 20) {
        phrase = 'Внимание! Пульс $hr, превышение на $over. Сбавьте темп!';
      } else if (over >= 10) {
        phrase = 'Пульс $hr, выше максимума $maxHr. Сбавьте темп.';
      } else {
        phrase = 'Пульс $hr, немного выше нормы. Следите за нагрузкой.';
      }
      VoiceCoachService.instance.speakImmediate(phrase);
    } catch (e) {
      debugPrint('HR alert error: $e');
    }
  }

  void _announceKm(int km) {
    try {
      final settings = AppSettingsController.instance;
      if (!settings.voiceCoachEnabled) return;
      if (!settings.voiceCoachAnnounceKm) return;

      String phrase = _phraseForKm(km, _snapshot.kind);

      if (settings.voiceCoachAnnounceMilestones) {
        final interval = settings.voiceCoachMilestoneInterval;
        if (interval > 0 && km % interval == 0) {
          final encouragements = ['Молодец!', 'Отлично!', 'Продолжай!', 'Так держать!', 'Здорово!'];
          final encourage = encouragements[(km ~/ interval) % encouragements.length];
          phrase = '$phrase. $encourage';
        }
      }

      VoiceCoachService.instance.speak(phrase);
    } catch (e) {
      debugPrint('VoiceCoach km announce error: $e');
    }
  }

  void _announceFinish() {
    try {
      final settings = AppSettingsController.instance;
      if (!settings.voiceCoachEnabled) return;
      if (!settings.voiceCoachAnnounceFinish) return;
      final km = (_totalDistance / 1000).toStringAsFixed(1);
      final min = _computeElapsedSeconds() ~/ 60;
      VoiceCoachService.instance.speak('Тренировка завершена! $km километра за $min минут. Отличная работа!');
    } catch (e) {
      debugPrint('Finish announce error: $e');
    }
  }

  void _announcePace() {
    try {
      final settings = AppSettingsController.instance;
      if (!settings.voiceCoachEnabled) return;
      if (!settings.voiceCoachAnnouncePace) return;
      if (_totalDistance < 10) return;

      final paceSeconds = _snapshot.elapsedSeconds / (_totalDistance / 1000);
      final paceMin = (paceSeconds / 60).floor();
      final paceSec = (paceSeconds % 60).floor();
      final paceStr = '${paceMin}\'${paceSec.toString().padLeft(2, '0')}"';

      VoiceCoachService.instance.speak('Текущий темп: $paceStr на километр');
    } catch (e) {
      debugPrint('VoiceCoach pace announce error: $e');
    }
  }

  double _maxSpeedForKind(ActivityKind? kind) {
    // м/с — по виду активности (walk 10.8 км/ч, run 46 км/ч)
    // FIX Samsung offline bug: был 22 для вело -> GPS джиттер 30м за 1с считался выбросом и отбрасывался,
    // distance терялась. Старый рабочий билд 8.3(22) имел 80. Ставим 35 как в tracking_session_engine (126 км/ч)
    switch (kind) {
      case ActivityKind.walk:
      case ActivityKind.indoorWalk:
      case ActivityKind.hike:
        return 3.0;
      case ActivityKind.run:
      case ActivityKind.trailRun:
      case ActivityKind.trackRun:
        return 13.0;
      case ActivityKind.roadCycling:
      case ActivityKind.gravelCycling:
      case ActivityKind.mtbCycling:
      case ActivityKind.eBikeCycling:
        return 35.0;
      default:
        return 25.0;
    }
  }

  double _dynamicMinDist(double accuracy, ActivityKind? kind) {
    final isWalk = kind == ActivityKind.walk ||
        kind == ActivityKind.indoorWalk ||
        kind == ActivityKind.hike;
    if (isWalk) {
      // ходьба медленная — 1м при хорошей точности, иначе 1.8
      return accuracy > 20 ? 1.8 : 1.0;
    }
    final isCycling = kind == ActivityKind.roadCycling ||
        kind == ActivityKind.gravelCycling ||
        kind == ActivityKind.mtbCycling ||
        kind == ActivityKind.eBikeCycling;
    if (isCycling) {
      // FIX Samsung: Kalman сглаживает 4.7м/с -> 3.7м, фильтр 0.7 был пограничным, ставим 0.5
      // при accuracy>20 оставляем 1.2 вместо 1.5 чтобы не терять точки офлайн
      return accuracy > 20 ? 1.2 : 0.5;
    }
    return accuracy > 20 ? 1.5 : 0.7;
  }

  double _recomputeDistanceFromPoints(List<ActivityPoint> pts) {
    if (pts.length < 2) return 0;
    double sum = 0;
    for (var i = 1; i < pts.length; i++) {
      sum += Geolocator.distanceBetween(
        pts[i - 1].latitude, pts[i - 1].longitude,
        pts[i].latitude, pts[i].longitude,
      );
    }
    return sum;
  }

  void dispose() {
    _positionSubscription?.cancel();
    _gpsWatchdog?.cancel();
    _bgPositionSubscription?.cancel();
    _hrSubscription?.cancel();
    _cadenceSubscription?.cancel();
    _powerSubscription?.cancel();
    _ticker?.cancel();
    _snapshotController.close();
  }
}

extension on TrackingSnapshot {
  TrackingSnapshot copyWith({
    int? activityId,
    bool? isPaused, 
    int? elapsedSeconds,
    double? distanceMeters,
    int? pointsCount,
    int? currentHeartRate,
    int? currentCadence,
  }) {
    return TrackingSnapshot(
      isRecording: isRecording,
      isPaused: isPaused ?? this.isPaused,
      activityId: activityId ?? this.activityId,
      kind: kind,
      startedAt: startedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      pointsCount: pointsCount ?? this.pointsCount,
      currentHeartRate: currentHeartRate ?? this.currentHeartRate,
      currentCadence: currentCadence ?? this.currentCadence,
    );
  }
}
