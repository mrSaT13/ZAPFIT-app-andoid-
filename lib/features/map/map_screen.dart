import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/services/activity_tracking_service.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/location_service.dart';
import 'package:zapfit/core/services/voice_coach_service.dart';
import 'package:zapfit/core/services/training_metrics_service.dart';
import 'package:zapfit/core/constants/map_constants.dart';
import 'package:zapfit/features/map/widgets/activity_panel.dart';
import 'package:zapfit/l10n/app_localizations.dart';
import 'package:zapfit/core/services/offline_tile_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final ActivityTrackingService _trackingService = ActivityTrackingService.instance;
  final AppSettingsController _settings = AppSettingsController.instance;
  final LocalActivityRepository _repository = LocalActivityRepository.instance;

  ll.LatLng _currentLocation = const ll.LatLng(
    MapConstants.defaultLatitude,
    MapConstants.defaultLongitude,
  );

  bool _isLoadingLocation = false;
  bool _hasLocationPermission = false;
  bool _isLocationLocked = false;
  double _heading = 0.0;
  double _smoothedHeading = 0.0;
  double _bearing = 0.0;
  double _currentSpeed = 0.0;
  double _avgSpeed = 0.0;
  double _gpsAccuracy = 0.0;

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<TrackingSnapshot>? _trackingSubscription;
  TrackingSnapshot _trackingSnapshot = TrackingSnapshot.empty;
  List<ll.LatLng> _liveTrackPolyline = const [];
  ll.LatLng? _lastTrackedPoint;
  bool _mapReady = false;

  late AnimationController _pulseController;
  int _countdownValue = 0;
  Timer? _countdownTimer;
  double _panelHeight = 200;
  static const double _panelMinHeight = 80;
  static const double _panelMaxRatio = 0.70;
  String? _offlineBaseDir;
  TileProvider? _offlineProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _initOfflineProvider();
    _tryGetLastKnownLocation();
    _startCompassUpdates();

    _trackingService.tryRestoreOngoingActivity().then((_) {
      if (!mounted) return;
      setState(() => _trackingSnapshot = _trackingService.currentSnapshot);
      if (_trackingSnapshot.activityId != null) _refreshLiveTrack(_trackingSnapshot.activityId!);
    });
    _trackingSnapshot = _trackingService.currentSnapshot;
    _trackingSubscription = _trackingService.snapshotStream.listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _trackingSnapshot = snapshot;
        if (snapshot.elapsedSeconds > 0 && snapshot.distanceMeters > 0) {
          final hours = snapshot.elapsedSeconds / 3600;
          _avgSpeed = (snapshot.distanceMeters / 1000) / hours;
        }
      });
      if (snapshot.activityId != null) {
        _refreshLiveTrack(snapshot.activityId!);
      }
    });

    _settings.addListener(_onSettingsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _mapReady = true);
    });

    if (_settings.mapDynamicBehavior != MapDynamicBehavior.off ||
        _trackingSnapshot.isRecording) {
      _isLocationLocked = true;
    }
    _initLocation();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    // Restart position updates if behavior changed
    if (_settings.mapDynamicBehavior != MapDynamicBehavior.off) {
      if (!_isLocationLocked) {
        _isLocationLocked = true;
        _startPositionUpdates();
      }
    }
    setState(() {});
  }

  Future<void> _initOfflineProvider() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final base = p.join(dir.path, 'offline_maps');
      if (!mounted) return;
      setState(() {
        _offlineBaseDir = base;
        // оффлайн провайдер только при записи — создаём заранее чтобы был готов
        _offlineProvider = OfflineTileProvider(baseDirPath: base, template: _getEffectiveTileUrl(context));
      });
    } catch (_) {}
  }

  Future<void> _tryGetLastKnownLocation() async {
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        setState(() {
          _currentLocation = ll.LatLng(lastPos.latitude, lastPos.longitude);
        });
        _mapController.move(_currentLocation, MapConstants.defaultZoom);
      }
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _startPositionUpdates();
        return;
      }
      _hasLocationPermission = true;
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos != null && mounted) {
        final p = pos;
        setState(() {
          _currentLocation = ll.LatLng(p.latitude, p.longitude);
          _gpsAccuracy = p.accuracy;
          _isLocationLocked = true;
        });
        _mapController.move(_currentLocation, _mapController.camera.zoom);
      }
    } catch (_) {}
    _startPositionUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _countdownTimer?.cancel();
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    _trackingSubscription?.cancel();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _compassSubscription?.cancel();
      _compassSubscription = null;
      _positionSubscription?.cancel();
      _positionSubscription = null;
    } else if (state == AppLifecycleState.resumed) {
      _startCompassUpdates();
      // Восстановление снапшота если процесс был убит в фоне/на локскрине
      _trackingService.tryRestoreOngoingActivity().then((_) {
        if (!mounted) return;
        setState(() => _trackingSnapshot = _trackingService.currentSnapshot);
        if (_trackingSnapshot.isRecording && _trackingSnapshot.activityId != null) {
          _refreshLiveTrack(_trackingSnapshot.activityId!);
        }
      });
      if (_trackingSnapshot.isRecording || _trackingService.currentSnapshot.isRecording) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isLocationLocked) _startPositionUpdates();
        });
      }
    }
  }

  bool _isMapDark(BuildContext context) {
    switch (_settings.mapTheme) {
      case MapTheme.light:
        return false;
      case MapTheme.dark:
        return true;
      case MapTheme.auto:
        return Theme.of(context).brightness == Brightness.dark;
    }
  }

  String _getEffectiveTileUrl(BuildContext context) {
    switch (_settings.mapProvider) {
      case MapProvider.esriSatellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapProvider.tomapo:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case MapProvider.cartoDark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case MapProvider.osm:
        break;
    }
    if (_settings.mapStyle == MapStyle.topographic) {
      return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
    }
    if (_isMapDark(context)) {
      return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
    }
    return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  Future<void> _onTrackingActionPressed() async {
    if (!_trackingSnapshot.isRecording) {
      final kind = await showDialog<ActivityKind>(
        context: context,
        builder: (context) => const _ActivitySelectionDialog(initialKind: ActivityKind.run),
      );
      if (kind != null) _startCountdown(kind);
      return;
    }
    if (_trackingSnapshot.isPaused) {
      await _trackingService.resume();
      setState(() => _isLocationLocked = true);
      _mapController.move(_currentLocation, _mapController.camera.zoom);
      if (_settings.voiceCoachEnabled) {
        VoiceCoachService.instance.speak("Продолжаем тренировку");
      }
    } else {
      await _trackingService.pause();
      if (_settings.voiceCoachEnabled) {
        VoiceCoachService.instance.speak("Пауза");
      }
    }
  }

  void _startCountdown(ActivityKind kind) async {
    await _waitForGPSSatellites();
    if (!mounted) return;

    setState(() {
      _countdownValue = 5;
      _isLocationLocked = true;
    });
    _mapController.move(_currentLocation, _mapController.camera.zoom);

    if (_settings.voiceCoachEnabled && _settings.voiceCoachAnnounceCountdown) {
      VoiceCoachService.instance.speak("Старт через пять секунд");
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_countdownValue > 1) {
        setState(() => _countdownValue--);
        if (_settings.voiceCoachEnabled && _settings.voiceCoachAnnounceCountdown) {
          VoiceCoachService.instance.speak("$_countdownValue");
        }
      } else {
        timer.cancel();
        setState(() => _countdownValue = 0);

        await _trackingService.start(kind);
        _startPositionUpdates();

        if (_settings.voiceCoachEnabled) {
          VoiceCoachService.instance.speak("Поехали!");
        }

        // Панель стартует свёрнутой — пользователь разворачивает вручную
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _panelHeight = _panelMinHeight);
        });
      }
    });
  }

  Future<void> _waitForGPSSatellites() async {
    final completer = Completer<bool>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Поиск спутников GPS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Ожидание сигнала GPS...', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('Точность: ${_gpsAccuracy > 0 ? _gpsAccuracy.toStringAsFixed(1) + "м" : "поиск..."}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!completer.isCompleted) completer.complete(true);
              Navigator.pop(context);
            },
            child: const Text('Начать сейчас (пропустить)'),
          ),
        ],
      ),
    );

    final sub = _locationService.getPositionStream(accuracyMode: 'high').listen((p) {
      if (mounted) setState(() => _gpsAccuracy = p.accuracy);
      if (p.accuracy < 25 && !completer.isCompleted) {
        completer.complete(true);
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    });

    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.complete(true);
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    });

    return completer.future.then((v) {
      sub.cancel();
      return v;
    });
  }

  double _deg2rad(double deg) => deg * math.pi / 180.0;

  double _computeBearing(ll.LatLng from, ll.LatLng to) {
    final phi1 = _deg2rad(from.latitude);
    final phi2 = _deg2rad(to.latitude);
    final dLon = _deg2rad(to.longitude - from.longitude);
    final y = math.sin(dLon) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLon);
    final brng = math.atan2(y, x);
    return (brng * 180 / math.pi + 360) % 360;
  }

  void _startPositionUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = _locationService.getPositionStream(
      accuracyMode: _settings.gpsAccuracy,
      distanceFilterMeters: _settings.gpsDistanceFilter,
      intervalSeconds: _settings.gpsUpdateIntervalSeconds,
    ).listen((pos) {
      if (!mounted) return;
      final newLoc = ll.LatLng(pos.latitude, pos.longitude);
      final prev = _lastTrackedPoint;
      if (prev != null && pos.speed > 1.0) {
        _bearing = _computeBearing(prev, newLoc);
      }
      _lastTrackedPoint = newLoc;
      setState(() {
        _currentLocation = newLoc;
        _currentSpeed = pos.speed * 3.6;
        _gpsAccuracy = pos.accuracy;
        _hasLocationPermission = true;
      });
      _applyDynamicCamera();
    });
  }

  void _applyDynamicCamera() {
    if (!_mapReady || !_isLocationLocked) return;
    final behavior = _settings.mapDynamicBehavior;
    
    final screenHeight = MediaQuery.of(context).size.height;
    final offsetLat = 0.00005 * (screenHeight * 0.25 / 100);
    final offsetLoc = ll.LatLng(_currentLocation.latitude - offsetLat, _currentLocation.longitude);
    
    switch (behavior) {
      case MapDynamicBehavior.off:
        break;
      case MapDynamicBehavior.follow:
        _mapController.move(offsetLoc, _mapController.camera.zoom);
        break;
      case MapDynamicBehavior.followWithHeading:
        _mapController.moveAndRotate(
          offsetLoc,
          _mapController.camera.zoom,
          _smoothedHeading,
        );
        break;
    }
  }

  Future<void> _refreshLiveTrack(int activityId) async {
    final points = await _repository.getPoints(activityId);
    if (!mounted) return;
    // Sort by timestamp to prevent visual backtrack from out-of-order inserts
    points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    setState(() {
      _liveTrackPolyline = points.map((p) => ll.LatLng(p.latitude, p.longitude)).toList();
    });
  }

  void _startCompassUpdates() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (mounted && event.heading != null) {
        final raw = event.heading!;
        double diff = raw - _smoothedHeading;
        if (diff > 180) diff -= 360;
        if (diff < -180) diff += 360;
        _smoothedHeading = (_smoothedHeading + diff * 0.15) % 360;
        if (_smoothedHeading < 0) _smoothedHeading += 360;
        setState(() {
          _heading = raw;
        });
        if (_settings.mapDynamicBehavior == MapDynamicBehavior.followWithHeading) {
          _applyDynamicCamera();
        }
      }
    });
  }

  Future<void> _requestLocationAndLock() async {
    setState(() => _isLoadingLocation = true);
    final pos = await _locationService.getCurrentPosition();
    if (mounted) {
      if (pos != null) {
        setState(() {
          _currentLocation = ll.LatLng(pos.latitude, pos.longitude);
          _gpsAccuracy = pos.accuracy;
          _hasLocationPermission = true;
          _isLocationLocked = true;
          _isLoadingLocation = false;
        });
        _mapController.move(_currentLocation, _mapController.camera.zoom);
        _startPositionUpdates();
      } else {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = _trackingSnapshot.isRecording;

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;

            if (isLandscape) {
              return Row(
                children: [
                  Expanded(flex: 2, child: _buildMapArea()),
                  Expanded(flex: 1, child: _buildLandscapePanel()),
                ],
              );
            }

            return Stack(
              children: [
                _buildMapArea(),

                // GPS-индикатор — только когда НЕ записываем
                if (!isRecording)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    right: 16,
                    child: _buildGpsIndicator(),
                  ),

                // Кнопка старта
                if (!isRecording)
                  Center(child: _buildStartButton()),

                // Обратный отсчёт
                if (_countdownValue > 0) _buildCountdownOverlay(),

                // Панель метрик при записи — toggle кнопкой
                if (isRecording) _buildRecordingPanel(),

                // Кнопка "вернуться к позиции" когда камера отстёгнута
                if (isRecording && !_isLocationLocked)
                  Positioned(
                    bottom: 220,
                    right: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'recenter',
                      onPressed: () {
                        setState(() => _isLocationLocked = true);
                        _mapController.move(_currentLocation, _mapController.camera.zoom);
                      },
                      child: const Icon(Icons.my_location),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleStop() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.stopActivityConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.stop),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final activityId = await _trackingService.stop();
      setState(() {
        _isLocationLocked = false;
        _positionSubscription?.cancel();
      });
      setState(() => _panelHeight = _panelMinHeight);
      if (activityId != null && mounted) {
        _showPostWorkoutSurvey(activityId);
      }
    }
  }

  void _showPostWorkoutSurvey(int activityId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Как прошла тренировка?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Оцените ваши ощущения', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _surveyOption(ctx, activityId, 1, Icons.sentiment_very_satisfied, 'Легко', Colors.green),
                _surveyOption(ctx, activityId, 2, Icons.sentiment_neutral, 'Нормально', Colors.amber),
                _surveyOption(ctx, activityId, 3, Icons.sentiment_very_dissatisfied, 'Тяжело', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _surveyOption(BuildContext ctx, int activityId, int rpe, IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () async {
        await TrainingMetricsService.instance.saveTss(
          activityId,
          TrainingMetricsService.instance.calculateTss(
            (await LocalActivityRepository.instance.getActivity(activityId))!,
          ),
          (await LocalActivityRepository.instance.getActivity(activityId))?.durationSeconds ?? 0,
          rpe: rpe,
        );
        if (mounted) Navigator.pop(ctx);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRecordingPanel() {
    final maxH = MediaQuery.of(context).size.height * _panelMaxRatio;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      left: 0,
      right: 0,
      bottom: 0,
      height: _panelHeight.clamp(_panelMinHeight, maxH),
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _panelHeight = (_panelHeight - details.delta.dy).clamp(_panelMinHeight, maxH);
          });
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -200) {
              setState(() => _panelHeight = maxH);
            } else if (details.primaryVelocity! > 200) {
              setState(() => _panelHeight = _panelMinHeight);
            }
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -2))],
          ),
          child: Column(
            children: [
              // Handle bar + toggle — вся строка кликабельна для сворачивания
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final maxH = MediaQuery.of(context).size.height * _panelMaxRatio;
                  setState(() => _panelHeight = _panelHeight > _panelMinHeight + 50 ? _panelMinHeight : maxH);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        _panelHeight > _panelMinHeight + 50 ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                        size: 28,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ActivityPanel(
                  scrollController: ScrollController(),
                  snapshot: _trackingSnapshot,
                  currentSpeed: _currentSpeed,
                  avgSpeed: _avgSpeed,
                  gpsAccuracy: _gpsAccuracy,
                  currentHeartRate: _trackingSnapshot.currentHeartRate,
                  maxHeartRate: _settings.userMaxHeartRate,
                  currentCadence: _trackingSnapshot.currentCadence,
                  onPauseResume: _onTrackingActionPressed,
                  onStop: _handleStop,
                  onRecenter: () {
                    setState(() => _isLocationLocked = true);
                    _mapController.move(_currentLocation, _mapController.camera.zoom);
                  },
                  onToggleVoice: () {
                    _settings.setVoiceCoachEnabled(!_settings.voiceCoachEnabled);
                  },
                  isPaused: _trackingSnapshot.isPaused,
                  isLocationLocked: _isLocationLocked,
                  voiceEnabled: _settings.voiceCoachEnabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapePanel() {
    if (!_trackingSnapshot.isRecording) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: ActivityPanel(
        scrollController: ScrollController(),
        snapshot: _trackingSnapshot,
        currentSpeed: _currentSpeed,
        avgSpeed: _avgSpeed,
        gpsAccuracy: _gpsAccuracy,
        currentHeartRate: _trackingSnapshot.currentHeartRate,
        maxHeartRate: _settings.userMaxHeartRate,
        currentCadence: _trackingSnapshot.currentCadence,
        onPauseResume: _onTrackingActionPressed,
        onStop: _handleStop,
        onRecenter: () {
          setState(() => _isLocationLocked = true);
          _mapController.move(_currentLocation, _mapController.camera.zoom);
        },
        onToggleVoice: () {
          _settings.setVoiceCoachEnabled(!_settings.voiceCoachEnabled);
        },
        isPaused: _trackingSnapshot.isPaused,
        isLocationLocked: _isLocationLocked,
        voiceEnabled: _settings.voiceCoachEnabled,
      ),
    );
  }

  Widget _buildMapArea() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation,
        initialZoom: MapConstants.defaultZoom,
        onPositionChanged: (pos, gesture) {
          if (gesture && _isLocationLocked) {
            setState(() => _isLocationLocked = false);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: _getEffectiveTileUrl(context),
          userAgentPackageName: MapConstants.userAgent,
          subdomains: _settings.mapProvider == MapProvider.esriSatellite
              ? const []
              : const ['a', 'b', 'c'],
          // Оффлайн-тайлы подставляются только при записи активности
          tileProvider: _trackingSnapshot.isRecording && _offlineProvider != null
              ? _offlineProvider!
              : NetworkTileProvider(),
        ),
        if (_liveTrackPolyline.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _liveTrackPolyline,
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 6,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: _currentLocation,
              width: 60,
              height: 60,
              child: Transform.rotate(
                angle: _heading * math.pi / 180,
                child: Icon(Icons.navigation, color: Theme.of(context).colorScheme.primary, size: 40),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('${_currentSpeed.toStringAsFixed(1)}', 'km/h'),
          _statItem(_formatDuration(_trackingSnapshot.elapsedSeconds), 'time'),
          _statItem(
            '${(_trackingSnapshot.distanceMeters / 1000).toStringAsFixed(2)}',
            'km',
          ),
        ],
      ),
    );
  }

  Widget _buildGpsIndicator() {
    final accuracyColor = _gpsAccuracy < 8
        ? Colors.green
        : (_gpsAccuracy < 25 ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gps_fixed, size: 14, color: accuracyColor),
              const SizedBox(width: 6),
              Text(
                "Сигнал: ${_gpsAccuracy < 10 ? 'Отличный' : (_gpsAccuracy < 30 ? 'Средний' : 'Слабый')}",
                style: TextStyle(fontSize: 12, color: accuracyColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            "Спутники: ${_gpsAccuracy <= 0 ? '--' : (_gpsAccuracy < 5 ? '>12' : (_gpsAccuracy < 15 ? '8-10' : '4-6'))}",
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedometerOverlay() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: (_currentSpeed / 40).clamp(0.0, 1.0),
            strokeWidth: 4,
            backgroundColor: Colors.white10,
            color: Theme.of(context).colorScheme.primary,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _currentSpeed.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                "km/h",
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3 * (1 - _pulseController.value)),
                  blurRadius: 20 * _pulseController.value,
                  spreadRadius: 12 * _pulseController.value,
                )
              ],
            ),
            child: Opacity(
              opacity: 0.92,
              child: FloatingActionButton.large(
                heroTag: 'main_action',
                onPressed: _countdownValue > 0 ? null : _onTrackingActionPressed,
                child: const Icon(Icons.play_arrow, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Text(
          "$_countdownValue",
          style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _statItem(String val, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    return "${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }
}

class _ActivitySelectionDialog extends StatefulWidget {
  final ActivityKind initialKind;
  const _ActivitySelectionDialog({required this.initialKind});

  @override
  State<_ActivitySelectionDialog> createState() => _ActivitySelectionDialogState();
}

class _ActivitySelectionDialogState extends State<_ActivitySelectionDialog> {
  late ActivityKind _selectedKind;
  final TextEditingController _searchController = TextEditingController();
  List<ActivityKind> _filteredKinds = ActivityKind.values;

  @override
  void initState() {
    super.initState();
    _selectedKind = widget.initialKind;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredKinds = ActivityKind.values.where((k) {
        return k.labelRu.toLowerCase().contains(query) || k.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.startActivity),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Поиск активности...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredKinds.length,
                itemBuilder: (context, index) {
                  final kind = _filteredKinds[index];
                  return ListTile(
                    title: Text(kind.labelRu),
                    selected: _selectedKind == kind,
                    trailing: _selectedKind == kind ? const Icon(Icons.check_circle) : null,
                    onTap: () {
                      setState(() => _selectedKind = kind);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedKind),
          child: Text(l10n.start),
        ),
      ],
    );
  }
}
