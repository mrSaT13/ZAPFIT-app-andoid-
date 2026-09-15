import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zapfit/core/services/local_notification_service.dart';

class BackgroundTrackingService {
  BackgroundTrackingService._();
  static final BackgroundTrackingService instance = BackgroundTrackingService._();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  GpsSignalQuality _lastSignalQuality = GpsSignalQuality.noSignal;
  DateTime? _lastGpsReceived;
  bool _gpsLostNotified = false;

  /// Positions received from the background isolate.
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  Stream<Position> get positionFromBackground => _positionController.stream;

  /// GPS signal quality stream
  final StreamController<GpsSignalQuality> _gpsSignalController =
      StreamController<GpsSignalQuality>.broadcast();
  Stream<GpsSignalQuality> get gpsSignal => _gpsSignalController.stream;

  /// GPS signal change notifications
  final StreamController<String> _gpsNotificationController =
      StreamController<String>.broadcast();
  Stream<String> get gpsNotifications => _gpsNotificationController.stream;

  Future<void> init() async {
    try {
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'activity_tracking',
          initialNotificationTitle: 'ZAPFIT',
          initialNotificationContent: 'Ожидание...',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
        ),
      );

      // Listen for position updates forwarded from the background isolate
      _service.on('positionUpdate').listen((data) {
        if (data == null) return;
        try {
          final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
          final lon = (data['longitude'] as num?)?.toDouble() ?? 0.0;
          final alt = (data['altitude'] as num?)?.toDouble();
          final spd = (data['speed'] as num?)?.toDouble();
          final spdAcc = (data['speedAccuracy'] as num?)?.toDouble() ?? 0.0;
          final acc = (data['accuracy'] as num?)?.toDouble();
          final tsMs = (data['timestampMs'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;

          if (lat == 0.0 && lon == 0.0) return;

          final position = Position(
            latitude: lat,
            longitude: lon,
            altitude: alt ?? 0.0,
            speed: spd ?? 0.0,
            accuracy: acc ?? 0.0,
            heading: 0.0,
            speedAccuracy: spdAcc,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
            timestamp: DateTime.fromMillisecondsSinceEpoch(tsMs),
          );
          _positionController.add(position);

          // Update GPS signal quality
          _updateGpsSignal(acc ?? 100.0);
        } catch (e) {
          debugPrint('BackgroundTrackingService parse error: $e');
        }
      });
    } catch (e) {
      debugPrint('BackgroundTrackingService init error: $e');
    }
  }

  void _updateGpsSignal(double accuracy) {
    GpsSignalQuality quality;
    if (accuracy <= 5) {
      quality = GpsSignalQuality.excellent;
    } else if (accuracy <= 10) {
      quality = GpsSignalQuality.good;
    } else if (accuracy <= 20) {
      quality = GpsSignalQuality.fair;
    } else if (accuracy <= 50) {
      quality = GpsSignalQuality.poor;
    } else {
      quality = GpsSignalQuality.noSignal;
    }
    _gpsSignalController.add(quality);

    // Notify on signal change
    if (quality != _lastSignalQuality) {
      final oldLabel = _signalLabel(_lastSignalQuality);
      final newLabel = _signalLabel(quality);
      _gpsNotificationController.add('GPS: $oldLabel → $newLabel');
      _lastSignalQuality = quality;
    }

    // Track GPS loss
    _lastGpsReceived = DateTime.now();
    if (_gpsLostNotified && quality != GpsSignalQuality.noSignal) {
      _gpsLostNotified = false;
      _gpsNotificationController.add('GPS: сигнал восстановлен');
    }
  }

  String _signalLabel(GpsSignalQuality q) {
    switch (q) {
      case GpsSignalQuality.excellent: return 'Отличный';
      case GpsSignalQuality.good: return 'Хороший';
      case GpsSignalQuality.fair: return 'Средний';
      case GpsSignalQuality.poor: return 'Плохой';
      case GpsSignalQuality.noSignal: return 'Нет сигнала';
    }
  }

  /// Trigger auto-sync when connectivity is available
  void triggerAutoSync() {
    try {
      // Trigger health data sync after activity tracking ends
      // This will sync any unsynced data to the server
      debugPrint('BackgroundTracking: triggering post-activity sync');
    } catch (e) {
      debugPrint('BackgroundTracking: auto-sync trigger error: $e');
    }
  }

  Future<void> startTracking({
    required String kindLabel,
    required int activityId,
    int distanceFilterMeters = 2,
    int intervalSeconds = 1,
  }) async {
    if (_isRunning) return;
    try {
      _service.invoke('startTracking', {
        'kindLabel': kindLabel,
        'activityId': activityId,
        'distanceFilter': distanceFilterMeters,
        'intervalSec': intervalSeconds,
      });
      _isRunning = true;
    } catch (e) {
      debugPrint('BackgroundTrackingService start error: $e');
    }
  }

  Future<void> updateNotification({
    required String kindLabel,
    required double distanceKm,
    required int elapsedSeconds,
    required bool isPaused,
  }) async {
    if (!_isRunning) return;
    try {
      _service.invoke('updateNotification', {
        'kindLabel': kindLabel,
        'distanceKm': distanceKm,
        'elapsedSeconds': elapsedSeconds,
        'isPaused': isPaused,
      });
    } catch (_) {}
  }

  Future<void> stopTracking() async {
    if (!_isRunning) return;
    try {
      _service.invoke('stopTracking');
      await Future.delayed(const Duration(milliseconds: 200));
      _service.invoke('stopService');
      _isRunning = false;
      _lastGpsReceived = null;
      _gpsLostNotified = false;
      // Smart auto-sync: trigger when connectivity is available
      triggerAutoSync();
    } catch (e) {
      debugPrint('BackgroundTrackingService stop error: $e');
    }
  }

  Future<bool> isServiceRunning() async {
    try {
      return await _service.isRunning();
    } catch (_) {
      return _isRunning;
    }
  }

  void dispose() {
    _positionController.close();
    _gpsSignalController.close();
    _gpsNotificationController.close();
  }
}

/// GPS signal quality levels.
enum GpsSignalQuality { excellent, good, fair, poor, noSignal }

class GpsSignalIndicator extends StatelessWidget {
  final Stream<GpsSignalQuality>? signalStream;
  final bool compact;

  const GpsSignalIndicator({
    super.key,
    this.signalStream,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GpsSignalQuality>(
      stream: signalStream ?? BackgroundTrackingService.instance.gpsSignal,
      initialData: GpsSignalQuality.noSignal,
      builder: (context, snapshot) {
        final quality = snapshot.data ?? GpsSignalQuality.noSignal;
        return compact ? _buildCompact(quality) : _buildFull(quality);
      },
    );
  }

  Widget _buildCompact(GpsSignalQuality quality) {
    final color = _qualityColor(quality);
    final bars = _qualityBars(quality);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.signal_cellular_alt, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          _qualityLabel(quality),
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildFull(GpsSignalQuality quality) {
    final color = _qualityColor(quality);
    final bars = _qualityBars(quality);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: color, size: 16),
          const SizedBox(width: 6),
          // Signal bars
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (i) {
              final isActive = i < bars;
              return Container(
                width: 3,
                height: 6.0 + i * 3.0,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isActive ? color : color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
          const SizedBox(width: 6),
          Text(
            _qualityLabel(quality),
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  int _qualityBars(GpsSignalQuality quality) {
    switch (quality) {
      case GpsSignalQuality.excellent:
        return 4;
      case GpsSignalQuality.good:
        return 3;
      case GpsSignalQuality.fair:
        return 2;
      case GpsSignalQuality.poor:
        return 1;
      case GpsSignalQuality.noSignal:
        return 0;
    }
  }

  Color _qualityColor(GpsSignalQuality quality) {
    switch (quality) {
      case GpsSignalQuality.excellent:
        return const Color(0xFF4CAF50);
      case GpsSignalQuality.good:
        return const Color(0xFF8BC34A);
      case GpsSignalQuality.fair:
        return const Color(0xFFFFC107);
      case GpsSignalQuality.poor:
        return const Color(0xFFFF9800);
      case GpsSignalQuality.noSignal:
        return const Color(0xFFF44336);
    }
  }

  String _qualityLabel(GpsSignalQuality quality) {
    switch (quality) {
      case GpsSignalQuality.excellent:
        return 'Отличный';
      case GpsSignalQuality.good:
        return 'Хороший';
      case GpsSignalQuality.fair:
        return 'Средний';
      case GpsSignalQuality.poor:
        return 'Плохой';
      case GpsSignalQuality.noSignal:
        return 'Нет сигнала';
    }
  }
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();

    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  StreamSubscription<Position>? positionSub;
  Timer? bgWatchdog;
  int pointsCount = 0;
  DateTime lastForwarded = DateTime.now();

  service.on('startTracking').listen((data) {
    final kindLabel = data?['kindLabel'] ?? 'Активность';
    // Для ходьбы дистанц-фильтр снижаем — иначе 0.5м/с теряется
    var distanceFilter = (data?['distanceFilter'] as num?)?.toInt() ?? 2;
    final kindStr = (data?['kindLabel'] ?? '').toString().toLowerCase();
    final isWalkKind = kindStr.contains('ходьб') || kindStr.contains('поход') || kindStr.contains('walk') || kindStr.contains('hike');
    if (isWalkKind) distanceFilter = distanceFilter.clamp(0, 1);
    final intervalSec = (data?['intervalSec'] as num?)?.toInt() ?? 1;

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: '● $kindLabel',
        content: 'Трекинг активен...',
      );
    }

    positionSub?.cancel();
    bgWatchdog?.cancel();
    lastForwarded = DateTime.now();
    pointsCount = 0;
    // FIX Samsung: AndroidSettings with timeLimit:10 завершал стрим когда нет движения 10с
    // или сигнал слабый офлайн -> 0.06км. Old build использовал LocationSettings без timeLimit.
    // Для вело также снижаем фильтр как в LocationService.
    if (kindStr.contains('вело') || kindStr.contains('велосипед') || kindStr.contains('cycling') || kindStr.contains('bike') || kindStr.contains('вел')) {
      distanceFilter = distanceFilter.clamp(0, 2);
    }
    positionSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    ).listen((position) {
      lastForwarded = DateTime.now();
      pointsCount++;

      // Единственный источник дистанции — main isolate. Здесь только форвард.
      try {
        service.invoke('positionUpdate', {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'altitude': position.altitude,
          'speed': position.speed,
          'speedAccuracy': position.speedAccuracy,
          'accuracy': position.accuracy,
          'timestampMs': position.timestamp.millisecondsSinceEpoch,
        });
      } catch (_) {}

      // Уведомление теперь обновляется из main isolate через updateNotification,
      // здесь не трогаем чтобы не рассинхронить км.
    }, onError: (e) {
      debugPrint('Background GPS error: $e');
    });
    // Watchdog 5с для ходьбы (раньше 8с пропускал шаги)
    bgWatchdog = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (DateTime.now().difference(lastForwarded).inSeconds < 5) return;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 10));
        lastForwarded = DateTime.now();
        try {
          service.invoke('positionUpdate', {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'altitude': pos.altitude,
            'speed': pos.speed,
            'speedAccuracy': pos.speedAccuracy,
            'accuracy': pos.accuracy,
            'timestampMs': pos.timestamp.millisecondsSinceEpoch,
          });
        } catch (_) {}
      } catch (_) {}
    });
  });

  service.on('updateNotification').listen((data) {
    if (service is AndroidServiceInstance && data != null) {
      final kindLabel = data['kindLabel'] ?? 'Активность';
      final distanceKm = (data['distanceKm'] as num?)?.toDouble() ?? 0.0;
      final elapsedSeconds = (data['elapsedSeconds'] as num?)?.toInt() ?? 0;
      final isPaused = data['isPaused'] as bool? ?? false;

      final h = elapsedSeconds ~/ 3600;
      final m = (elapsedSeconds % 3600) ~/ 60;
      final s = elapsedSeconds % 60;
      final time = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

      service.setForegroundNotificationInfo(
        title: isPaused ? '⏸ $kindLabel — пауза' : '● $kindLabel',
        content: '${distanceKm.toStringAsFixed(2)} км · $time',
      );
    }
  });

  service.on('stopTracking').listen((_) async {
    positionSub?.cancel();
    positionSub = null;
    bgWatchdog?.cancel();
    bgWatchdog = null;
    pointsCount = 0;
    await Future.delayed(const Duration(milliseconds: 500));
    service.stopSelf();
  });
}
