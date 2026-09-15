import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/models/activity_media_model.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/services/activity_stream_service.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/activity_sync_service.dart';
import 'package:zapfit/core/services/gear_service.dart';
import 'package:zapfit/core/models/gear_model.dart';
import 'package:zapfit/core/constants/map_constants.dart';
import 'package:zapfit/shared/widgets/secure_image.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/features/activities/edit_activity_screen.dart';
import 'package:zapfit/features/activities/similar_activities_screen.dart';
import 'package:zapfit/core/services/training_analysis_service.dart';
import 'package:zapfit/core/services/ollama_service.dart';
import 'package:zapfit/features/activities/widgets/activity_share_card.dart';
// === ZAPFIT metrics ===
import 'package:zapfit/core/utils/trimp_calculator.dart';
import 'package:zapfit/core/utils/pace_zones_calculator.dart';
import 'package:zapfit/core/utils/power_zones_calculator.dart';
import 'package:zapfit/core/utils/css_calculator.dart';
import 'package:zapfit/core/utils/cadence_calculator.dart';
import 'package:zapfit/core/utils/epoc_calculator.dart';
import 'package:zapfit/core/utils/running_power.dart';
import 'package:zapfit/core/utils/riegel_predictor.dart';
import 'package:zapfit/core/utils/vdot_calculator.dart';
import 'package:zapfit/core/utils/suffer_score_calculator.dart';
import 'package:zapfit/core/utils/training_effect_calculator.dart';
import 'package:zapfit/core/services/training_metrics_service.dart';
import 'package:zapfit/core/utils/rpe_to_tss_calculator.dart';

class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({super.key, required this.activity, this.isOwnActivity = true});

  final ActivityRecord activity;
  final bool isOwnActivity;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final LocalActivityRepository _repository = LocalActivityRepository.instance;
  final SecureStorageService _storage = SecureStorageService();
  final AppSettingsController _settings = AppSettingsController.instance;
  final ActivityStreamService _streamService = serviceLocator<ActivityStreamService>();
  final ApiClient _apiClient = serviceLocator<ApiClient>();
  final GearService _gearService = serviceLocator<GearService>();
  final ImagePicker _picker = ImagePicker();
  final MapController _mapController = MapController();

  late ActivityRecord _activity;
  bool _isLoading = true;
  String? _errorMessage;
  List<ActivityPoint> _points = [];
  List<GearRecord> _availableGears = [];
  List<ActivityMedia> _media = [];
  String _tileServerUrl = MapConstants.defaultTileServerUrl;
  double _currentZoom = 14.0;

  double _maxSpeed = 0.0;
  double _maxAltitude = 0.0;
  double _minAltitude = 0.0;
  double _totalAscent = 0.0;
  double _totalDescent = 0.0;
  int _movingTimeSeconds = 0;
  int _pausedTimeSeconds = 0;
  int _avgHeartRate = 0;
  int _maxHeartRate = 0;
  List<int> _heartRateValues = [];
  List<int> _cadenceValues = [];
  List<double> _powerValues = [];
  double _avgCadence = 0;
  double _avgPower = 0;
  double _bestPace = 0;
  double _avgPace = 0;
  int _estimatedSteps = 0;
  double _avgStrideLength = 0;
  double _estimatedVO2max = 0;
  int _estimatedCalories = 0;
  List<_KilometerSplit> _kmSplits = [];
  double _maxAscentRate = 0;
  double _maxDescentRate = 0;
  TrainingAnalysis? _analysis;
  bool _isAnalysisLoading = false;

  // === Ollama AI допись ===
  String? _aiComment;
  bool _aiLoading = false;
  String? _aiError;

  // In-memory cache for instant open
  static final Map<int, _DetailCache> _cache = {};

  // === ZAPFIT metrics ===
  double? _zTss;
  double? _zHrTss;
  double? _zTrimpBanister;
  double? _zTrimpEdwards;
  double? _zTrimpSimplified;
  double? _zIF;
  double? _zNP;
  double? _zFtp;
  double? _zEF;
  double? _zDecoupling;
  double? _zTrainingEffect;
  double? _zVdot;
  double? _zEpoc;
  int? _zSufferScore;
  double? _zRunningPower;
  double? _zStrideLength;
  double? _zHydrationMl;
  int? _savedRpe;
  String? _zCss;
  Map<String, double>? _zRaceTimes;
  Map<String, double>? _zVdotEquiv;
  Map<String, String>? _zPaceZones;
  Map<String, String>? _zPowerZones;
  List<double>? _zEdwardsZoneMinutes;
  List<double>? _zKarvonenZoneMinutes;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final sw = Stopwatch()..start();
    try {
      // 0. Cache hit -> instant
      if (_activity.id != null && _cache.containsKey(_activity.id)) {
        final c = _cache[_activity.id]!;
        if (DateTime.now().difference(c.timestamp).inMinutes < 10) {
          _points = c.points;
          _analysis = c.analysis;
          if (c.totalAscent != null) {
            _totalAscent = c.totalAscent!;
            _totalDescent = c.totalDescent ?? 0;
          }
          _calculateStats();
          if (mounted) setState(() => _isLoading = false);
          // refresh heavy metrics in background without blocking
          unawaited(_computeZapfitMetrics().then((_) { if (mounted) setState(() {}); }));
          if (_analysis == null) {
            _isAnalysisLoading = true;
            TrainingAnalysisService.instance.analyze(_activity).then((a) {
              if (!mounted) return;
              setState(() { _analysis = a; _isAnalysisLoading = false; });
              if (_activity.id != null) _cache[_activity.id!] = _DetailCache(points: _points, analysis: a, totalAscent: _totalAscent, totalDescent: _totalDescent, timestamp: DateTime.now());
            });
          }
          if (_activity.serverId != null) unawaited(_fetchMedia().then((_) { if (mounted) setState(() {}); }));
          debugPrint('Detail cache hit id=${_activity.id} ${sw.elapsedMilliseconds}ms');
          return;
        }
      }

      // 1. Parallel IO (points, gears, tileUrl) — not blocking each other
      final pointsFuture = _activity.id != null ? _repository.getPoints(_activity.id!) : Future.value(<ActivityPoint>[]);
      final gearsFuture = _gearService.fetchGears().then((_) => _gearService.gears).catchError((_) => <GearRecord>[]);
      final tileFuture = _storage.getTileServerUrl();

      final results = await Future.wait([pointsFuture, gearsFuture, tileFuture]);
      _points = results[0] as List<ActivityPoint>;
      _availableGears = results[1] as List<GearRecord>;
      final tileServer = results[2] as String?;
      if (tileServer != null && tileServer.isNotEmpty) _tileServerUrl = tileServer;

      if (_points.isEmpty && _activity.serverId != null) {
        try {
          _points = await _streamService.getStreamPoints(_activity.serverId!).timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('stream fallback error: $e');
        }
      }

      _calculateStats();
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Detail phase1 ${sw.elapsedMilliseconds}ms points=${_points.length}');

      // 2. Heavy work off critical path
      unawaited(_computeZapfitMetrics().then((_) { if (mounted) setState(() {}); }));
      _isAnalysisLoading = true;
      if (mounted) setState(() {});
      TrainingAnalysisService.instance.analyze(_activity).then((a) {
        if (!mounted) return;
        setState(() { _analysis = a; _isAnalysisLoading = false; });
        if (_activity.id != null) _cache[_activity.id!] = _DetailCache(points: _points, analysis: a, totalAscent: _totalAscent, totalDescent: _totalDescent, timestamp: DateTime.now());
      }).catchError((_) { if (mounted) setState(() => _isAnalysisLoading = false); });

      if (_activity.serverId != null) {
        unawaited(_fetchMedia().then((_) { if (mounted) setState(() {}); }));
      }
    } catch (e) {
      debugPrint('ActivityDetailScreen _load error: $e');
      if (mounted) setState(() => _errorMessage = 'Ошибка загрузки данных поездки: $e');
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMedia() async {
    try {
      final response = await _apiClient.get('/api/v1/activities_media/activity_id/${_activity.serverId}');
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        if (decoded is List) {
          setState(() {
            _media = decoded.map((m) => ActivityMedia.fromJson(m as Map<String, dynamic>)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching media: $e');
    }
  }

  void _calculateStats() {
    if (_points.isEmpty) {
      _maxSpeed = 0; _maxAltitude = 0; _minAltitude = 0; _totalAscent = 0; _totalDescent = 0;
      _movingTimeSeconds = 0; _pausedTimeSeconds = 0;
      if (_activity.startedAt != null && _activity.endedAt != null) {
        _pausedTimeSeconds = _activity.endedAt!.difference(_activity.startedAt).inSeconds - _activity.durationSeconds;
        if (_pausedTimeSeconds < 0) _pausedTimeSeconds = 0;
      }
      return;
    }

    try {
      // maxSpeed: если speed в точках 0 (старый трек), считаем по derived speed = dist/dt
      final speeds = <double>[];
      for (int i = 0; i < _points.length; i++) {
        double s = _points[i].speed ?? 0.0;
        if (s <= 0.1 && i > 0) {
          final dt = _points[i].timestamp.difference(_points[i-1].timestamp).inMilliseconds / 1000.0;
          if (dt > 0.2 && dt < 30) {
            final d = _points[i].distanceFromStartMeters - _points[i-1].distanceFromStartMeters;
            if (d > 0) s = d / dt;
          }
        }
        if (!s.isNaN && !s.isInfinite) speeds.add(s);
      }
      _maxSpeed = (speeds.isEmpty ? 0.0 : speeds.reduce(math.max)) * 3.6;

      final altitudes = _points
          .where((p) => p.altitude != null && !p.altitude!.isNaN && !p.altitude!.isInfinite)
          .map((p) => p.altitude!)
          .toList();

      if (altitudes.isNotEmpty) {
        _maxAltitude = altitudes.reduce(math.max);
        _minAltitude = altitudes.reduce(math.min);
      }

      _totalAscent = 0;
      _totalDescent = 0;
      _movingTimeSeconds = 0;
      _pausedTimeSeconds = 0;
      _maxAscentRate = 0;
      _maxDescentRate = 0;
      int pausedSegments = 0;

      // Km splits tracking
      double accumulatedDistance = 0;
      int currentKmStartMs = 0;
      bool inKmSegment = false;

      for (int i = 1; i < _points.length; i++) {
        final currentAlt = _points[i].altitude;
        final prevAlt = _points[i-1].altitude;

        if (currentAlt != null && prevAlt != null && !currentAlt.isNaN && !prevAlt.isNaN) {
          final diff = currentAlt - prevAlt;
          if (diff > 0.5) _totalAscent += diff;
          if (diff < -0.5) _totalDescent += diff.abs();

          // Vertical speed (m/s)
          final dt = _points[i].timestamp.difference(_points[i-1].timestamp).inMilliseconds / 1000.0;
          if (dt > 0) {
            final vertRate = diff.abs() / dt;
            if (diff > 0 && vertRate > _maxAscentRate) _maxAscentRate = vertRate;
            if (diff < 0 && vertRate > _maxDescentRate) _maxDescentRate = vertRate;
          }
        }

        final speed = _points[i].speed ?? 0.0;
        final int dur = _points[i].timestamp.difference(_points[i-1].timestamp).inSeconds;
        if (dur > 0 && dur < 30) {
          if (speed > 0.5 && !speed.isNaN && !speed.isInfinite) {
            _movingTimeSeconds += dur;
            if (pausedSegments > 0) {
              _pausedTimeSeconds += pausedSegments;
              pausedSegments = 0;
            }
          } else {
            pausedSegments += dur;
          }
        }

        // Kilometer splits
        final dDist = _points[i].distanceFromStartMeters;
        final currentKm = (dDist / 1000).floor();
        if (!inKmSegment && currentKm >= 1) {
          currentKmStartMs = _points[i].timestamp.millisecondsSinceEpoch;
          inKmSegment = true;
        }
        if (inKmSegment && dDist >= (currentKm + 1) * 1000) {
          final splitEndMs = _points[i].timestamp.millisecondsSinceEpoch;
          final splitDurSec = (splitEndMs - currentKmStartMs) / 1000.0;
          if (splitDurSec > 0) {
            final splitPace = splitDurSec / 60.0; // min per km
            final splitSpeed = 3600.0 / splitDurSec; // km/h
            _kmSplits.add(_KilometerSplit(
              km: currentKm + 1,
              durationSeconds: splitDurSec,
              paceMinPerKm: splitPace,
              speedKmh: splitSpeed,
            ));
          }
          currentKmStartMs = splitEndMs;
        }
      }
      _pausedTimeSeconds += pausedSegments;

      // HR stats
      _heartRateValues = _points
          .where((p) => p.heartRate != null && p.heartRate! > 0)
          .map((p) => p.heartRate!)
          .toList();
      if (_heartRateValues.isNotEmpty) {
        _avgHeartRate = (_heartRateValues.reduce((a, b) => a + b) / _heartRateValues.length).round();
        _maxHeartRate = _heartRateValues.reduce(math.max);
      }

      // Cadence stats
      _cadenceValues = _points
          .where((p) => p.cadence != null && p.cadence! > 0)
          .map((p) => p.cadence!)
          .toList();
      if (_cadenceValues.isNotEmpty) {
        _avgCadence = _cadenceValues.reduce((a, b) => a + b) / _cadenceValues.length;
      }

      // Power stats
      _powerValues = _points
          .where((p) => p.power != null && p.power! > 0)
          .map((p) => p.power!)
          .toList();
      if (_powerValues.isNotEmpty) {
        _avgPower = _powerValues.reduce((a, b) => a + b) / _powerValues.length;
      }

      // Pace calculation
      final distanceKm = _activity.distanceMeters / 1000;
      final durationMin = _activity.durationSeconds / 60.0;
      if (distanceKm > 0 && durationMin > 0) {
        _avgPace = durationMin / distanceKm;
        final paceValues = <double>[];
        for (int i = 1; i < _points.length; i++) {
          final speed = _points[i].speed ?? 0.0;
          final int dur = _points[i].timestamp.difference(_points[i-1].timestamp).inSeconds;
          if (dur > 0 && speed > 0.5 && !speed.isNaN && !speed.isInfinite) {
            final speedKmh = speed * 3.6;
            if (speedKmh > 0) paceValues.add(60.0 / speedKmh);
          }
        }
        if (paceValues.isNotEmpty) _bestPace = paceValues.reduce(math.min);
      }

      // Estimated steps (running/walking)
      final isRunWalk = _activity.kind == ActivityKind.run ||
          _activity.kind == ActivityKind.trailRun ||
          _activity.kind == ActivityKind.walk ||
          _activity.kind == ActivityKind.hike;
      if (isRunWalk) {
        if (_avgCadence > 0 && _movingTimeSeconds > 0) {
          // Steps from cadence: cadence is steps/min, movingTime in seconds
          _estimatedSteps = (_avgCadence * _movingTimeSeconds / 60).round();
        } else {
          _estimatedSteps = (distanceKm * 1312).round();
        }
      }

      // Stride length (cm) = distance(m) / steps * 100
      if (_estimatedSteps > 0 && distanceKm > 0) {
        _avgStrideLength = (distanceKm * 1000 / _estimatedSteps) * 100;
      }

      // VO2max estimation (Keytel et al. formula simplified)
      // For running: VO2max ≈ -4.60 + 0.182258 * HRmax + 0.000104 * HRmax^2 - 0.002054 * age + ...
      // Simplified: based on speed at avg HR
      if (_avgHeartRate > 0 && _movingTimeSeconds > 0) {
        final avgSpeedMs = (_activity.distanceMeters / _movingTimeSeconds);
        final hrReserve = _avgHeartRate / (_settings.userMaxHeartRate > 0 ? _settings.userMaxHeartRate : 185);
        // Rough VO2max from speed and HR efficiency
        if (hrReserve > 0 && avgSpeedMs > 0) {
          _estimatedVO2max = (avgSpeedMs * 100 * 3.5) / hrReserve;
          _estimatedVO2max = _estimatedVO2max.clamp(20.0, 85.0);
        }
      }

      // Calories estimation (Keytel et al. 2005 + HR correction)
      final weight = _settings.userWeight;
      final durationHours = _activity.durationSeconds / 3600.0;
      final baseCalories = durationHours * weight * 8;
      // HR-based correction: higher HR = more calories
      if (_avgHeartRate > 0) {
        final hrFactor = 0.7 + (_avgHeartRate / (_settings.userMaxHeartRate > 0 ? _settings.userMaxHeartRate : 185)) * 0.6;
        _estimatedCalories = (baseCalories * hrFactor).round();
      } else {
        _estimatedCalories = baseCalories.round();
      }

    } catch (e) {
      debugPrint('Error calculating stats: $e');
    }
  }

  // === ZAPFIT metrics ===
  int _zoneIndex(double pct) {
    if (pct < 0.5) return -1;
    if (pct < 0.6) return 0;
    if (pct < 0.7) return 1;
    if (pct < 0.8) return 2;
    if (pct < 0.9) return 3;
    return 4;
  }

  Future<void> _computeZapfitMetrics() async {
    try {
      final maxHr = _settings.userMaxHeartRate.toDouble();
      final restingHr = _settings.userRestingHeartRate.toDouble();
      final weight = _settings.userWeight;
      final age = _settings.userAge ?? 30;
      final durationMin = _activity.durationSeconds / 60.0;
      final avgHr = _avgHeartRate > 0
          ? _avgHeartRate.toDouble()
          : (_activity.avgHeartRate?.toDouble() ?? 0);

      final hrSamples = _points
          .where((p) => p.heartRate != null && p.heartRate! > 0)
          .map((p) => (p.timestamp.millisecondsSinceEpoch, p.heartRate!))
          .toList();
      final powerSamples = _points
          .where((p) => p.power != null && p.power! > 0)
          .map((p) => (p.timestamp.millisecondsSinceEpoch, p.power!))
          .toList();

      _zTss = TrainingMetricsService.instance.calculateTss(_activity);
      if (_activity.id != null) {
        try { _savedRpe = await TrainingMetricsService.instance.getRpe(_activity.id!); } catch (_) {}
        if (_savedRpe != null && _savedRpe! > 0) {
          final rpeTss = RpeToTssCalculator.convert(durationMinutes: (_activity.durationSeconds/60).round(), rpe: _savedRpe!);
          if (rpeTss > 0) _zTss = rpeTss;
        }
      }

      if (_activity.durationSeconds > 0 && avgHr > 0 && maxHr > restingHr) {
        _zHrTss = TrimpCalculator.hrTss(
          durationMinutes: durationMin.round(),
          avgHr: avgHr,
          restingHr: restingHr,
          maxHr: maxHr,
        );
        _zTrimpBanister = TrimpCalculator.banister(
          durationMinutes: durationMin.round(),
          avgHr: avgHr,
          restingHr: restingHr,
          maxHr: maxHr,
        );
        _zTrimpSimplified = TrimpCalculator.simplified(
          durationMinutes: durationMin.round(),
          avgHr: avgHr,
          maxHr: maxHr,
        );
      }

      if (hrSamples.length >= 2) {
        final edwardsZones = List.filled(5, 0.0);
        final karvonenZones = List.filled(5, 0.0);
        for (int i = 0; i < hrSamples.length; i++) {
          final hr = hrSamples[i].$2.toDouble();
          double dt;
          if (i < hrSamples.length - 1) {
            dt = (hrSamples[i + 1].$1 - hrSamples[i].$1) / 60000.0;
          } else if (i > 0) {
            dt = (hrSamples[i].$1 - hrSamples[i - 1].$1) / 60000.0;
          } else {
            dt = 0;
          }
          if (dt < 0 || dt > 5) dt = 0;
          final pctMax = hr / maxHr;
          final z = _zoneIndex(pctMax);
          if (z >= 0) edwardsZones[z] += dt;
          if (maxHr > restingHr) {
            final pctR = (hr - restingHr) / (maxHr - restingHr);
            final kz = _zoneIndex(pctR);
            if (kz >= 0) karvonenZones[kz] += dt;
          }
        }
        _zEdwardsZoneMinutes = edwardsZones;
        _zKarvonenZoneMinutes = karvonenZones;
        if (durationMin > 0) {
          _zTrimpEdwards = TrimpCalculator.edwards(
            durationMinutes: durationMin.round(),
            zoneTimesMinutes: edwardsZones,
          );
          _zSufferScore = SufferScoreCalculator.calculate(
            zoneMinutes: edwardsZones,
            durationMinutes: durationMin.round(),
          );
        }
      }

      if (_activity.durationSeconds > 0 && avgHr > 0) {
        _zEpoc = EpocCalculator.estimate(
          durationMinutes: durationMin.round(),
          avgHrPercentMax: avgHr / maxHr,
          age: age,
        );
      }

      _zEF = TrainingMetricsService.instance.calculateEfficiencyFactor(_activity);
      if (hrSamples.length >= 4) {
        _zDecoupling = TrainingMetricsService.instance.calculateDecoupling(_activity, hrSamples);
      }

      if (_zTss != null && _zTss! > 0) {
        _zTrainingEffect = TrainingEffectCalculator.aerobic(
          tss: _zTss,
          hrvResponse: null,
          atl: null,
          ctl: null,
        );
      }

      if (powerSamples.length >= 2) {
        _zNP = TrainingMetricsService.instance.calculateNormalizedPower(powerSamples);
        final ftp = await TrainingMetricsService.instance.detectFtp([_activity]);
        _zFtp = ftp;
        if (ftp != null && ftp > 0 && _zNP != null) {
          _zIF = TrainingMetricsService.instance.calculateIntensityFactor(_zNP, ftp);
          _zPowerZones = PowerZonesCalculator.calculateZones(ftp);
        }
      }

      final isRunWalk = _activity.kind == ActivityKind.run ||
          _activity.kind == ActivityKind.trailRun ||
          _activity.kind == ActivityKind.walk ||
          _activity.kind == ActivityKind.hike;

      if (isRunWalk && _bestPace > 0) {
        _zPaceZones = PaceZonesCalculator.calculateZones(_bestPace);
      }

      if ((_activity.kind == ActivityKind.indoorSwimming ||
              _activity.kind == ActivityKind.openWaterSwimming) &&
          _activity.distanceMeters > 0) {
        final avgPaceSecPer100m = _activity.durationSeconds / (_activity.distanceMeters / 100);
        _zCss = CssCalculator.formatCss(100 / avgPaceSecPer100m);
      }

      if (_avgPace > 0 && _avgCadence > 0) {
        _zStrideLength = CadenceCalculator.strideLength(
          paceSecPerKm: _avgPace,
          cadenceSpm: _avgCadence.round(),
        );
      }

      if (isRunWalk && _avgPace > 0 && weight > 0) {
        _zRunningPower = RunningPowerCalculator.estimate(
          paceSecPerKm: _avgPace,
          weightKg: weight,
        );
      }

      final distanceM = _activity.distanceMeters;
      if (distanceM > 0 && _activity.durationSeconds > 0) {
        _zRaceTimes = RiegelPredictor.predictAll(
          timeSeconds: _activity.durationSeconds.toDouble(),
          knownDistanceMeters: distanceM,
        );
        _zVdot = VdotCalculator.estimateVdot(
          timeSeconds: _activity.durationSeconds.toDouble(),
          distanceMeters: distanceM,
        );
        if (_zVdot != null && _zVdot! > 0) {
          _zVdotEquiv = VdotCalculator.equivalentPerformances(_zVdot!);
        }
      }

      if (_activity.durationSeconds > 0 && weight > 0) {
        final hours = _activity.durationSeconds / 3600.0;
        _zHydrationMl = hours * weight * 6; // 6 мл/кг/ч
      }

      // Persist computed ZAPFIT metrics to ActivityRecord for sync (offline -> server)
      if (_activity.id != null) {
        final cur = _activity;
        double? newVo2 = _estimatedVO2max > 0 ? _estimatedVO2max.clamp(0.0, 100.0) : null;
        int? newTss = _zTss != null && _zTss! > 0 ? _zTss!.round().clamp(0, 500) : null;
        int? newHrTss = _zHrTss != null && _zHrTss! > 0 ? _zHrTss!.round().clamp(0, 500) : null;
        int? newTrimp = (_zTrimpBanister ?? _zTrimpEdwards ?? _zTrimpSimplified)?.round();
        if (newTrimp != null) newTrimp = newTrimp.clamp(0, 1000);
        double? newIf = _zIF != null ? (_zIF!.clamp(0.0, 2.0)) : null;
        double? newAerobic = _zTrainingEffect != null ? (_zTrainingEffect!.clamp(0.0, 5.0)) : null;
        double? newEpoc = _zEpoc;
        int? newSuffer = _zSufferScore != null ? _zSufferScore!.clamp(0, 100) : null;
        double? newEf = _zEF;
        bool changed = false;
        if (newVo2 != null && cur.vo2max != newVo2) changed = true;
        if (newTss != null && cur.tss != newTss) changed = true;
        if (newHrTss != null && cur.hrTss != newHrTss) changed = true;
        if (newTrimp != null && cur.trimp != newTrimp) changed = true;
        if (newIf != null && cur.intensityFactor != newIf) changed = true;
        if (newAerobic != null && cur.aerobicTe != newAerobic) changed = true;
        if (newEpoc != null && cur.epoc != newEpoc) changed = true;
        if (newSuffer != null && cur.sufferScore != newSuffer) changed = true;
        if (newEf != null && cur.efficiencyFactor != newEf) changed = true;
        if ((cur.vo2max == null && newVo2 != null) || (cur.tss == null && newTss != null)) changed = true;
        if (changed) {
          final updated = cur.copyWith(
            vo2max: newVo2 ?? cur.vo2max,
            tss: newTss ?? cur.tss,
            hrTss: newHrTss ?? cur.hrTss,
            trimp: newTrimp ?? cur.trimp,
            intensityFactor: newIf ?? cur.intensityFactor,
            aerobicTe: newAerobic ?? cur.aerobicTe,
            epoc: newEpoc ?? cur.epoc,
            sufferScore: newSuffer ?? cur.sufferScore,
            efficiencyFactor: newEf ?? cur.efficiencyFactor,
            uploadStatus: UploadStatus.pending,
          );
          try {
            await _repository.updateActivity(updated);
            _activity = updated;
            debugPrint("ZAPFIT persist: vo2=$newVo2 tss=$newTss hrTss=$newHrTss trimp=$newTrimp if=$newIf");
          } catch (e) {
            debugPrint("ZAPFIT persist error: $e");
          }
        }
      }
    } catch (e) {
      debugPrint('ZAPFIT metrics error: $e');
    }
  }

  Future<void> _pickImage() async {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: cs.primary.withOpacity(0.12), shape: BoxShape.circle), child: Icon(Icons.photo_camera_outlined, color: cs.primary)),
                title: const Text('Камера'),
                subtitle: const Text('Сделать фото'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: cs.primary.withOpacity(0.12), shape: BoxShape.circle), child: Icon(Icons.photo_library_outlined, color: cs.primary)),
                title: const Text('Галерея'),
                subtitle: const Text('Выбрать из галереи / файлов'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    await _pickImageFromSource(source);
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image != null) {
        setState(() => _isLoading = true);
        if (_activity.serverId != null) {
          final res = await _apiClient.uploadFile('/api/v1/activities_media/upload/activity_id/${_activity.serverId}', image.path, 'file');
          if (res.statusCode != 200 && res.statusCode != 201) {
            throw Exception('Ошибка сервера при загрузке фото');
          }
          await _fetchMedia();
        }

        final updated = _activity.copyWith(photoPath: image.path);
        if (_activity.id != null) await _repository.updateActivity(updated);
        setState(() {
          _activity = updated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки фото: $e')));
      }
    }
  }

  Future<void> _editActivity() async {
    final result = await Navigator.push<ActivityRecord>(
      context,
      MaterialPageRoute(
        builder: (context) => EditActivityScreen(
          activity: _activity,
          points: _points,
          availableGears: _availableGears,
          media: _media,
        ),
      ),
    );

    if (result != null) {
      // invalidate cache - иначе _load() вернет старые точки из _cache и карта не обновится
      if (result.id != null) _cache.remove(result.id);
      if (_activity.id != null) _cache.remove(_activity.id);
      setState(() => _activity = result);
      await _load();
    }
  }

  Future<void> _shareActivity() async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityShareCard(
          activity: _activity,
          points: _points,
          avgHeartRate: _avgHeartRate,
          maxHeartRate: _maxHeartRate,
          avgSpeed: _activity.durationSeconds > 0
              ? (_activity.distanceMeters / 1000) / (_activity.durationSeconds / 3600)
              : 0,
          maxSpeed: _maxSpeed,
          totalAscent: _totalAscent,
          movingTimeSeconds: _movingTimeSeconds,
          pausedTimeSeconds: _pausedTimeSeconds,
          estimatedCalories: _estimatedCalories.toDouble(),
        ),
      ),
    );
  }

  bool get _needsUpload =>
      _activity.uploadStatus == UploadStatus.pending ||
      _activity.uploadStatus == UploadStatus.failed;

  Future<void> _sendToServer() async {
    if (!_needsUpload) return;
    if (_activity.id == null) return;
    setState(() => _isLoading = true);
    try {
      final syncService = serviceLocator<ActivitySyncService>();
      final result = await syncService.forcePushActivity(_activity.id!);
      if (mounted) {
        if (result.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка отправки: ${result.error}'), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Отправлено на сервер'), backgroundColor: Colors.green),
          );
          if (_activity.id != null) _cache.remove(_activity.id);
          // refresh local record after successful upload (serverId updated)
          final refreshed = await _repository.getActivity(_activity.id!);
          if (refreshed != null) _activity = refreshed;
        }
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteActivity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete activity?'),
        content: const Text('It will be deleted locally. Server will be cleaned if reachable.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _isLoading = true);
      String? serverError;
      if (_activity.serverId != null) {
        try {
          await _apiClient.delete('/api/v1/activities/${_activity.serverId}/delete').timeout(const Duration(seconds: 12));
        } catch (e) { serverError = e.toString(); debugPrint('Server delete failed: $e'); }
      }
      try {
        if (_activity.id != null) { await _repository.deleteActivity(_activity.id!); }
        if (mounted) {
          if (serverError != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted locally, server: $serverError'), backgroundColor: Colors.orange, duration: const Duration(seconds: 4))); }
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e'))); }
      }
    }
  }
  String _getEffectiveTileUrl() {
    switch (_settings.mapProvider) {
      case MapProvider.esriSatellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapProvider.tomapo:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case MapProvider.cartoDark:
        return 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png';
      case MapProvider.osm:
        break;
    }
    if (_settings.mapStyle == MapStyle.topographic) return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
    // Respect user's explicit map theme setting
    switch (_settings.mapTheme) {
      case MapTheme.light:
        return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapTheme.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png';
      case MapTheme.auto:
        if (Theme.of(context).brightness == Brightness.dark) {
          return 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png';
        }
        return _tileServerUrl;
    }
  }

  bool _isValidNumber(double? value) {
    return value != null && !value.isNaN && !value.isInfinite;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _load, child: const Text('Попробовать снова')),
              ],
            ),
          ),
        ),
      );
    }

    // [comment removed - encoding corrupted]
    try {
      return _buildContent(context);
    } catch (e, st) {
      debugPrint('ActivityDetailScreen build error: $e\n$st');
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка отображения')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bug_report_outlined, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'Не удалось отобразить активность:\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Назад')),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context) {

    final validPoints = _points.where((p) {
      if (p.latitude == null || p.longitude == null) return false;
      final lat = p.latitude!;
      final lon = p.longitude!;
      return !lat.isNaN && !lon.isNaN &&
          lat >= -90 && lat <= 90 &&
          lon >= -180 && lon <= 180;
    }).toList();

    final polylinePoints = validPoints.map((p) => ll.LatLng(p.latitude!, p.longitude!)).toList();
    final center = polylinePoints.isNotEmpty
        ? polylinePoints.last
        : const ll.LatLng(MapConstants.defaultLatitude, MapConstants.defaultLongitude);

    final speedSpots = validPoints.where((p) =>
      _isValidNumber(p.speed) && _isValidNumber(p.distanceFromStartMeters)
    ).map((p) => FlSpot(p.distanceFromStartMeters! / 1000, p.speed! * 3.6)).toList();

    final altitudeSpots = validPoints.where((p) =>
      _isValidNumber(p.altitude) && _isValidNumber(p.distanceFromStartMeters)
    ).map((p) => FlSpot(p.distanceFromStartMeters! / 1000, p.altitude!)).toList();

    return Scaffold(
        appBar: AppBar(
        title: Text(_activity.title ?? 'Активность'),
        actions: [
          if (widget.isOwnActivity) IconButton(icon: const Icon(Icons.share_outlined), onPressed: _shareActivity),
          if (widget.isOwnActivity) IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editActivity),
          if (widget.isOwnActivity) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _deleteActivity),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeroImage(),
            if (_media.isNotEmpty) ...[const SizedBox(height: 12), _buildMediaGallery()],
            const SizedBox(height: 16),
            _buildMapCard(center, polylinePoints),
            const SizedBox(height: 20),
            _buildStatsGrid(),
            const SizedBox(height: 20),
            if (_heartRateValues.isNotEmpty) ...[
              _buildHeartRateZones(),
              const SizedBox(height: 20),
            ],
            if (validPoints.length > 5 && _hasAltitudeData()) ...[
              _buildGradientDistribution(),
              const SizedBox(height: 20),
            ],
            if (widget.isOwnActivity) ...[
              if (_analysis != null)
                _buildAnalysisCard(_analysis!)
              else if (_isAnalysisLoading)
                _buildAnalysisLoadingCard(),
              if (_analysis != null || _isAnalysisLoading) const SizedBox(height: 12),
              _buildAiAnalysisCard(),
              const SizedBox(height: 20),
            ],
            _buildNotesCard(),
            // === ZAPFIT metrics ===
            const SizedBox(height: 20),
            _buildSportsMetricsCard(),
            if (validPoints.length > 5) ...[
              const SizedBox(height: 24),
              _buildChartSection("Скорость", Colors.blue, speedSpots, "км/ч"),
              const SizedBox(height: 24),
              _buildChartSection("Высота", Colors.green, altitudeSpots, "м"),
              if (_heartRateValues.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildHrChart(),
              ],
            ],
            const SizedBox(height: 40),
            if (_needsUpload)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sendToServer,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Отправить на сервер'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    try {
      if (_activity.photoPath != null && _activity.photoPath!.isNotEmpty) {
        final file = File(_activity.photoPath!);
        if (file.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.file(file, height: 240, width: double.infinity, fit: BoxFit.cover),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading hero image: $e');
    }

    if (_activity.thumbnailUrl != null && _activity.thumbnailUrl!.isNotEmpty) {
      return SecureImage(imageUrl: _activity.thumbnailUrl, height: 240, borderRadius: 24);
    }

    return OutlinedButton.icon(
      onPressed: _pickImage,
      icon: const Icon(Icons.add_a_photo_outlined),
      label: const Text("Добавить фото"),
      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 120), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    );
  }

  Widget _buildMediaGallery() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _media.length,
        itemBuilder: (context, index) {
          final media = _media[index];
          if (media.mediaPath == null || media.mediaPath!.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SecureImage(imageUrl: media.mediaPath, width: 100, height: 100, borderRadius: 16, fit: BoxFit.cover),
          );
        },
      ),
    );
  }

  Widget _buildMapCard(ll.LatLng center, List<ll.LatLng> polylinePoints) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14,
            onPositionChanged: (pos, gesture) {
              if (mounted && pos.zoom != null && pos.zoom != _currentZoom && !pos.zoom!.isNaN) {
                setState(() => _currentZoom = pos.zoom!);
              }
            },
          ),
          children: [
            TileLayer(urlTemplate: _getEffectiveTileUrl(), userAgentPackageName: MapConstants.userAgent),
            if (polylinePoints.isNotEmpty) ...[
              PolylineLayer(polylines: [
                Polyline(points: polylinePoints, strokeWidth: 4, color: Theme.of(context).colorScheme.primary),
              ]),
              if (_currentZoom >= 15.5)
                MarkerLayer(
                  markers: polylinePoints.map((point) => Marker(
                    point: point,
                    width: 10, height: 10,
                    child: Container(decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1))),
                  )).toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    double safeDistance = _activity.distanceMeters ?? 0;
    if (safeDistance.isNaN || safeDistance.isInfinite || safeDistance < 0) safeDistance = 0;

    int safeDuration = _activity.durationSeconds ?? 0;
    if (safeDuration < 0) safeDuration = 0;

    final distanceKm = (safeDistance / 1000).toStringAsFixed(2);
    final avgSpeed = safeDuration > 0 ? (safeDistance / safeDuration) * 3.6 : 0.0;

    final bool hasPoints = _points.isNotEmpty;
    final double displayMaxSpeed = hasPoints ? _maxSpeed : 0.0;
    final int displayMovingTime = hasPoints ? _movingTimeSeconds : safeDuration;
    final double displayAscent = hasPoints ? _totalAscent : 0.0;
    final double displayDescent = hasPoints ? _totalDescent : 0.0;

    // Total elapsed time
    int totalElapsed = safeDuration;
    if (_activity.startedAt != null && _activity.endedAt != null) {
      totalElapsed = _activity.endedAt!.difference(_activity.startedAt).inSeconds;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main stats grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _statCard("Дистанция", "$distanceKm км", Icons.straighten),
            _statCard("Общее время", _formatDuration(totalElapsed), Icons.timer_outlined),
            _statCard("Время тренировки", _formatDuration(safeDuration), Icons.play_arrow),
            if (_pausedTimeSeconds > 0)
              _statCard("Время пауз", _formatDuration(_pausedTimeSeconds), Icons.pause),
            _statCard("Макс. скор.", "${displayMaxSpeed.toStringAsFixed(1)} км/ч", Icons.bolt),
            _statCard("Сред. скор.", "${avgSpeed.toStringAsFixed(1)} км/ч", Icons.trending_up),
            if (_avgHeartRate > 0)
              _statCard("Сред. пульс", "$_avgHeartRate уд/мин", Icons.favorite, color: Colors.red),
            if (_maxHeartRate > 0)
              _statCard("Макс. пульс", "$_maxHeartRate уд/мин", Icons.favorite_border, color: Colors.red),
            _statCard("Набор высоты", "+${displayAscent.toInt()} м", Icons.filter_hdr_outlined),
            if (displayDescent > 0)
              _statCard("Сброс высоты", "-${displayDescent.toInt()} м", Icons.terrain),
          ],
        ),
        // Pace + steps + stride (for running/walking)
        if (_activity.kind == ActivityKind.run ||
            _activity.kind == ActivityKind.trailRun ||
            _activity.kind == ActivityKind.walk ||
            _activity.kind == ActivityKind.hike) ...[
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              if (_avgPace > 0)
                _statCard("Сред. темп", "${_formatPace(_avgPace)}/км", Icons.speed),
              if (_bestPace > 0)
                _statCard("Лучший темп", "${_formatPace(_bestPace)}/км", Icons.bolt),
              if (_estimatedSteps > 0)
                _statCard("Шаги", "~$_estimatedSteps", Icons.directions_walk),
              if (_avgStrideLength > 0)
                _statCard("Длина шага", "${_avgStrideLength.toStringAsFixed(0)} см", Icons.straighten),
            ],
          ),
        ],
        // Cadence and power
        if (_avgCadence > 0 || _avgPower > 0) ...[
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              if (_avgCadence > 0)
                _statCard("Сред. каденс", "${_avgCadence.round()} шаг/мин", Icons.sync),
              if (_avgPower > 0)
                _statCard("Сред. мощность", "${_avgPower.round()} Вт", Icons.flash_on),
            ],
          ),
        ],
        // VO2max + Calories
        if (_estimatedVO2max > 0 || _estimatedCalories > 0) ...[
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              if (_estimatedCalories > 0)
                _statCard("Калории", "~$_estimatedCalories ккал", Icons.local_fire_department, color: Colors.orange),
              if (_estimatedVO2max > 0)
                _statCard("VO2max", "~${_estimatedVO2max.toStringAsFixed(1)} мл", Icons.air, color: Colors.teal),
            ],
          ),
        ],
        // Vertical speed
        if (_maxAscentRate > 0 || _maxDescentRate > 0) ...[
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              if (_maxAscentRate > 0)
                _statCard("Макс. набор", "${(_maxAscentRate * 3600).toStringAsFixed(0)} м/ч", Icons.arrow_upward),
              if (_maxDescentRate > 0)
                _statCard("Макс. сброс", "${(_maxDescentRate * 3600).toStringAsFixed(0)} м/ч", Icons.arrow_downward),
            ],
          ),
        ],
        // Kilometer splits
        if (_kmSplits.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildKmSplitsSection(),
        ],
      ],
    );
  }

  Widget _buildKmSplitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Сплиты по километрам', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        ...List.generate(_kmSplits.length, (i) {
          final split = _kmSplits[i];
          final d = Duration(seconds: split.durationSeconds.round());
          final timeStr = d.inMinutes > 0
              ? '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}'
              : '${d.inSeconds}с';
          final paceMin = split.paceMinPerKm.floor();
          final paceSec = ((split.paceMinPerKm - paceMin) * 60).round();
          final paceStr = '$paceMin:${paceSec.toString().padLeft(2, '0')}';

          // Color based on pace (faster = green, slower = red)
          final avgPace = _avgPace > 0 ? _avgPace : 6.0;
          final diff = split.paceMinPerKm - avgPace;
          Color paceColor;
          if (diff < -0.15) {
            paceColor = Colors.green;
          } else if (diff > 0.15) {
            paceColor = Colors.red;
          } else {
            paceColor = Colors.grey;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${split.km}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 4, height: 24,
                  decoration: BoxDecoration(color: paceColor, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(timeStr, style: const TextStyle(fontSize: 14)),
                ),
                Text(
                  '$paceStr /км',
                  style: TextStyle(fontSize: 13, color: paceColor, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Text(
                  '${split.speedKmh.toStringAsFixed(1)} км/ч',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, {Color? color}) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    final notes = _activity.notes ?? '';
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3))),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text("Заметки", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(notes.isEmpty ? "Нет заметок" : notes),
        trailing: const Icon(Icons.info_outline, size: 20),
      ),
    );
  }

  // === ZAPFIT metrics ===
  Widget _buildSportsMetricsCard() {
    final rows = <Widget>[];

    void add(String label, String value, {Color? valueColor}) {
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ),
            Expanded(
              flex: 3,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor),
              ),
            ),
          ],
        ),
      ));
    }

    void section(String title) {
      rows.add(const SizedBox(height: 12));
      rows.add(Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)));
      rows.add(const SizedBox(height: 4));
    }

    section('Нагрузка (TSS / TRIMP)');
    if (_zTss != null) add('TSS', _zTss!.toStringAsFixed(0));
    if (_zHrTss != null) add('hrTSS', _zHrTss!.toStringAsFixed(1));
    if (_zTrimpBanister != null) add('TRIMP (Banister)', _zTrimpBanister!.toStringAsFixed(1));
    if (_zTrimpEdwards != null) add('TRIMP (Edwards)', _zTrimpEdwards!.toStringAsFixed(1));
    if (_zTrimpSimplified != null) add('TRIMP (упрощённый)', _zTrimpSimplified!.toStringAsFixed(1));

    if (_zNP != null || _zIF != null || _zPowerZones != null) {
      section('Мощность');
      if (_zNP != null) add('NP (норм. мощность)', '${_zNP!.round()} Вт');
      if (_zIF != null) add('IF (интенсивность)', _zIF!.toStringAsFixed(2));
      if (_zFtp != null) add('FTP (оценка)', '${_zFtp!.round()} Вт');
      if (_zPowerZones != null) {
        for (final e in _zPowerZones!.entries) {
          add(e.key, e.value, valueColor: Colors.orange);
        }
      }
    }

    if (_zKarvonenZoneMinutes != null) {
      section('Зоны пульса (Карвонен)');
      const names = ['Z1 50–60%', 'Z2 60–70%', 'Z3 70–80%', 'Z4 80–90%', 'Z5 90–100%'];
      for (int i = 0; i < _zKarvonenZoneMinutes!.length; i++) {
        final m = _zKarvonenZoneMinutes![i];
        final mm = m.floor();
        final ss = ((m - mm) * 60).round();
        add(names[i], m > 0 ? '$mm:${ss.toString().padLeft(2, '0')}' : '—');
      }
    }

    if (_zPaceZones != null) {
      section('Зоны темпа');
      for (final e in _zPaceZones!.entries) {
        add(e.key, e.value);
      }
    }
    if (_zCss != null) add('CSS (плавание)', _zCss!);

    section('Эффективность');
    if (_zEF != null) add('EF (Efficiency Factor)', _zEF!.toStringAsFixed(3));
    if (_zDecoupling != null) add('Pa:HR расцепление', '${_zDecoupling!.toStringAsFixed(1)}%');

    if (_zTrainingEffect != null) {
      section('Эффект тренировки');
      add(
        'Training Effect',
        '${_zTrainingEffect!.toStringAsFixed(1)} / 5 — ${TrainingEffectCalculator.classifyAerobic(_zTrainingEffect!)}',
      );
    }

    if (_zRaceTimes != null && _zRaceTimes!.isNotEmpty) {
      section('Прогноз времени (Riegel)');
      for (final e in _zRaceTimes!.entries) {
        add(e.key, RiegelPredictor.formatTime(e.value));
      }
    }
    if (_zVdot != null && _zVdot! > 0) {
      section('VDOT (Дж. Дэниелс)');
      add('VDOT', _zVdot!.toStringAsFixed(1));
      if (_zVdotEquiv != null) {
        for (final e in _zVdotEquiv!.entries) {
          add('${e.key} (экв.)', RiegelPredictor.formatTime(e.value));
        }
      }
    }

    section('Восстановление / нагрузка');
    if (_zEpoc != null) add('EPOC', '${_zEpoc!.toStringAsFixed(0)} ккал (${EpocCalculator.classify(_zEpoc!)})');
    if (_zSufferScore != null) {
      add('Suffer Score', '$_zSufferScore (${SufferScoreCalculator.classify(_zSufferScore!)})');
    }

    if (_avgCadence > 0 || _zStrideLength != null || _zRunningPower != null) {
      section('Каденс и шаг');
      if (_avgCadence > 0) add('Сред. каденс', '${_avgCadence.round()} шаг/мин');
      if (_zStrideLength != null) add('Длина шага', CadenceCalculator.formatStride(_zStrideLength!));
      if (_zRunningPower != null) add('Оценка мощности бега', '${_zRunningPower!.round()} Вт');
    }

    if (_zHydrationMl != null) {
      section('Гидратация');
      add('Рекомендуемо за активность', '${(_zHydrationMl! / 1000).toStringAsFixed(2)} л');
    }

    // Server-side ZAPFIT metrics (from API)
    final a = _activity;
    if (a.vo2max != null || a.tss != null || a.hrTss != null || a.trimp != null ||
        a.intensityFactor != null || a.aerobicTe != null || a.anaerobicTe != null ||
        a.epoc != null || a.sufferScore != null || a.efficiencyFactor != null) {
      section('ZAPFIT метрики (сервер)');
      if (a.vo2max != null) add('VO2max', '${a.vo2max!.toStringAsFixed(1)} мл/кг/мин', valueColor: Colors.green);
      if (a.tss != null) add('TSS', '${a.tss}', valueColor: Colors.blue);
      if (a.hrTss != null) add('hrTSS', '${a.hrTss}', valueColor: Colors.blue);
      if (a.trimp != null) add('TRIMP', '${a.trimp}', valueColor: Colors.blue);
      if (a.intensityFactor != null) add('IF', a.intensityFactor!.toStringAsFixed(3), valueColor: Colors.blue);
      if (a.aerobicTe != null) add('Aerobic TE', a.aerobicTe!.toStringAsFixed(1), valueColor: Colors.amber);
      if (a.anaerobicTe != null) add('Anaerobic TE', a.anaerobicTe!.toStringAsFixed(1), valueColor: Colors.amber);
      if (a.epoc != null) add('EPOC', '${a.epoc!.toStringAsFixed(0)} ккал', valueColor: Colors.red);
      if (a.sufferScore != null) add('Suffer Score', '${a.sufferScore}', valueColor: Colors.red);
      if (a.efficiencyFactor != null) add('EF', a.efficiencyFactor!.toStringAsFixed(3), valueColor: Colors.teal);
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Спортивные метрики', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(String title, Color color, List<FlSpot> spots, String unit) {
    if (spots.isEmpty) return const SizedBox.shrink();

    final safeSpots = spots.where((s) => !s.x.isNaN && !s.x.isInfinite && !s.y.isNaN && !s.y.isInfinite).toList();
    if (safeSpots.isEmpty) return const SizedBox.shrink();

    double minX = safeSpots.map((s) => s.x).reduce(math.min);
    double maxX = safeSpots.map((s) => s.x).reduce(math.max);
    double minY = safeSpots.map((s) => s.y).reduce(math.min);
    double maxY = safeSpots.map((s) => s.y).reduce(math.max);

    if (minX == maxX) {
      minX -= 1;
      maxX += 1;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    bool showBelowBar = safeSpots.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: safeSpots,
                  isCurved: false,
                  color: color,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: showBelowBar, color: color.withOpacity(0.1)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHrChart() {
    if (_heartRateValues.isEmpty) return const SizedBox.shrink();

    final spots = _heartRateValues
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();

    final minY = _heartRateValues.reduce(math.min).toDouble() - 10;
    final maxY = _heartRateValues.reduce(math.max).toDouble() + 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Пульс', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Row(
          children: [
            _hrStat('Средний', '$_avgHeartRate'),
            const SizedBox(width: 16),
            _hrStat('Макс.', '$_maxHeartRate'),
            const SizedBox(width: 16),
            _hrStat('Точек', '${_heartRateValues.length}'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.red,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.1)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _hrStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildHeartRateZones() {
    if (_heartRateValues.isEmpty || _avgHeartRate == 0) return const SizedBox.shrink();

    final maxHr = AppSettingsController.instance.userMaxHeartRate;
    final restingHr = AppSettingsController.instance.userRestingHeartRate;

    // Define HR zones based on % of max HR (Karvonen method)
    final zones = <_HrZone>[
      _HrZone('Покой', 0.0, 0.5, Colors.grey),
      _HrZone('Легкая', 0.5, 0.6, Colors.blue),
      _HrZone('Интенсивная', 0.6, 0.7, Colors.green),
      _HrZone('Аэробная', 0.7, 0.8, Colors.yellow.shade700),
      _HrZone('Анаэробная', 0.8, 0.9, Colors.orange),
      _HrZone('МПК', 0.9, 1.0, Colors.red),
    ];

    // Count seconds in each zone
    final zoneSeconds = List.filled(zones.length, 0);
    for (int i = 0; i < _heartRateValues.length; i++) {
      final hr = _heartRateValues[i];
      final pct = (hr - restingHr) / (maxHr - restingHr);
      for (int z = zones.length - 1; z >= 0; z--) {
        if (pct >= zones[z].minPct) {
          zoneSeconds[z]++;
          break;
        }
      }
    }

    final totalSeconds = zoneSeconds.fold(0, (a, b) => a + b);
    if (totalSeconds == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Зоны пульса', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        ...List.generate(zones.length, (i) {
          final zone = zones[i];
          final seconds = zoneSeconds[i];
          final pct = totalSeconds > 0 ? (seconds / totalSeconds * 100) : 0.0;
          final hrMin = (restingHr + zone.minPct * (maxHr - restingHr)).round();
          final hrMax = (restingHr + zone.maxPct * (maxHr - restingHr)).round();
          final d = Duration(seconds: seconds);
          final timeStr = '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(zone.name, style: TextStyle(fontSize: 12, color: zone.color, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$hrMin-$hrMax уд/мин', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 2),
                      LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: Colors.grey.withValues(alpha: 0.15),
                        color: zone.color,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text('${pct.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 45,
                  child: Text(timeStr, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  bool _hasAltitudeData() {
    return _points.any((p) => p.altitude != null && !p.altitude!.isNaN && p.altitude! != 0);
  }

  Widget _buildGradientDistribution() {
    int climbSeconds = 0;
    int flatSeconds = 0;
    int descendSeconds = 0;

    for (int i = 1; i < _points.length; i++) {
      final currentAlt = _points[i].altitude;
      final prevAlt = _points[i - 1].altitude;
      if (currentAlt == null || prevAlt == null) continue;
      if (currentAlt.isNaN || prevAlt.isNaN) continue;

      final diff = currentAlt - prevAlt;
      final dur = _points[i].timestamp.difference(_points[i - 1].timestamp).inSeconds;
      if (dur <= 0 || dur > 30) continue;

      if (diff > 0.5) {
        climbSeconds += dur;
      } else if (diff < -0.5) {
        descendSeconds += dur;
      } else {
        flatSeconds += dur;
      }
    }

    final total = climbSeconds + flatSeconds + descendSeconds;
    if (total == 0) return const SizedBox.shrink();

    final climbPct = climbSeconds / total;
    final flatPct = flatSeconds / total;
    final descendPct = descendSeconds / total;

    String fmt(int s) {
      final d = Duration(seconds: s);
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final sec = d.inSeconds % 60;
      if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
      return '$m:${sec.toString().padLeft(2, '0')}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Распределение градиента', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(
                  painter: _GradientDonutPainter(
                    climbPct: climbPct,
                    flatPct: flatPct,
                    descendPct: descendPct,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _gradientLegend(Colors.orange, 'Подъём', fmt(climbSeconds), '${(climbPct * 100).toStringAsFixed(0)}%'),
                  const SizedBox(height: 8),
                  _gradientLegend(Colors.yellow.shade700, 'Плоский', fmt(flatSeconds), '${(flatPct * 100).toStringAsFixed(0)}%'),
                  const SizedBox(height: 8),
                  _gradientLegend(Colors.blue, 'Спуск', fmt(descendSeconds), '${(descendPct * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradientLegend(Color color, String label, String time, String pct) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 8),
        Text(pct, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAnalysisCard(TrainingAnalysis analysis) {
    final theme = Theme.of(context);
    final Color cardColor = analysis.speedDelta != null
        ? (analysis.speedDelta! > 0 ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08))
        : Colors.blue.withOpacity(0.08);
    final Color borderColor = analysis.speedDelta != null
        ? (analysis.speedDelta! > 0 ? Colors.green : Colors.orange)
        : Colors.blue;

    final bool hasSimilar = analysis.similarCount > 0;
    final Widget card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: borderColor.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(analysis.icon, size: 18, color: borderColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Анализ тренировки',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: borderColor,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (hasSimilar)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.primary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            analysis.verdict,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            analysis.details,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          if (analysis.similarCount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _analysisStat('Похожих тренировок', '${analysis.similarCount}'),
                _analysisStat('Ср. скорость', '${analysis.avgSpeedSimilar.toStringAsFixed(1)} км/ч'),
                if (analysis.speedDelta != null)
                  _analysisStat('Отклонение', '${analysis.speedDelta! > 0 ? '+' : ''}${analysis.speedDelta!.toStringAsFixed(1)}%'),
              ],
            ),
          ],
          if (hasSimilar) ...[
            const SizedBox(height: 10),
            Text('Нажмите чтобы увидеть список >', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );

    if (hasSimilar) {
      return InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SimilarActivitiesScreen(activity: _activity)));
        },
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }
    return card;
  }

    Widget _buildAnalysisLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Анализирую тренировку...', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  // === Ollama AI допись ===
  Future<void> _generateAiComment() async {
    if (_aiLoading) return;
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });
    try {
      final settings = AppSettingsController.instance;
      if (!settings.ollamaEnabled) {
        throw Exception('ИИ-анализ выключен в настройках');
      }
      final apiKey = await settings.getOllamaApiKey();
      if (apiKey == null || apiKey.isEmpty) throw Exception('Укажите Ollama API ключ в настройках');
      final comment = await OllamaService.instance.generateComment(
        activity: _activity,
        totalAscent: _totalAscent,
        totalDescent: _totalDescent,
        avgHr: _avgHeartRate > 0 ? _avgHeartRate : null,
        maxHr: _maxHeartRate > 0 ? _maxHeartRate : null,
        tss: _zTss,
        avgSpeed: _activity.durationSeconds > 0 ? (_activity.distanceMeters / 1000) / (_activity.durationSeconds / 3600) : null,
        avgPace: _avgPace > 0 ? _avgPace : null,
      );
      if (!mounted) return;
      setState(() {
        _aiComment = comment;
        _aiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e.toString().replaceAll('Exception: ', '');
        _aiLoading = false;
      });
    }
  }

  Widget _buildAiAnalysisCard() {
    final settings = AppSettingsController.instance;
    final enabled = settings.ollamaEnabled;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.smart_toy_outlined, size: 18, color: Colors.deepPurple),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('ИИ-АНАЛИЗ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepPurple, letterSpacing: 1)),
              ),
              if (enabled && _aiComment == null && !_aiLoading)
                FilledButton.icon(
                  onPressed: _generateAiComment,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Сгенерировать', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: const Size(0, 32)),
                ),
              if (enabled && _aiComment != null && !_aiLoading)
                TextButton.icon(
                  onPressed: _generateAiComment,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Перегенерировать', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!enabled) ...[
            const Text('ИИ-комментарии выключены. Включите тумблер Ollama в настройках, укажите API ключ и модель.', style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4)),
          ] else if (_aiLoading) ...[
            const Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 12), Text('Генерирую анализ...', style: TextStyle(fontSize: 13, color: Colors.grey))]),
          ] else if (_aiError != null) ...[
            Text('Ошибка: $_aiError', style: const TextStyle(fontSize: 13, color: Colors.red, height: 1.4)),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _generateAiComment, icon: const Icon(Icons.refresh, size: 16), label: const Text('Попробовать снова')),
          ] else if (_aiComment != null) ...[
            Text(_aiComment!, style: const TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    // Допісь в заметки
                    final newNotes = (_activity.notes?.isNotEmpty == true ? '${_activity.notes}\n\n' : '') + 'ИИ: $_aiComment';
                    final updated = _activity.copyWith(notes: newNotes);
                    if (_activity.id != null) await _repository.updateActivity(updated);
                    if (mounted) {
                      setState(() => _activity = updated);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавлено в заметки')));
                    }
                  },
                  icon: const Icon(Icons.note_add_outlined, size: 16),
                  label: const Text('В заметки', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Text('Модель: ${settings.ollamaModel}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ] else ...[
            const Text('Нажмите «Сгенерировать» чтобы получить ИИ-допись к анализу тренировки. Учитываются дистанция, темп, пульс, набор высоты и TSS.', style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _analysisStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 0) seconds = 0;
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return "${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
    }
    return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  String _formatPace(double paceMinPerKm) {
    final min = paceMinPerKm.floor();
    final sec = ((paceMinPerKm - min) * 60).round();
    return "${min}:${sec.toString().padLeft(2, '0')}";
  }
}

class _HrZone {
  final String name;
  final double minPct;
  final double maxPct;
  final Color color;
  const _HrZone(this.name, this.minPct, this.maxPct, this.color);
}

class _GradientDonutPainter extends CustomPainter {
  final double climbPct;
  final double flatPct;
  final double descendPct;

  _GradientDonutPainter({
    required this.climbPct,
    required this.flatPct,
    required this.descendPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;

    final total = climbPct + flatPct + descendPct;
    if (total <= 0) return;

    double startAngle = -math.pi / 2;

    void drawArc(double pct, Color color) {
      if (pct <= 0) return;
      final sweepAngle = 2 * math.pi * (pct / total);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    drawArc(climbPct, Colors.orange);
    drawArc(flatPct, Colors.yellow.shade700);
    drawArc(descendPct, Colors.blue);
  }

  @override
  bool shouldRepaint(covariant _GradientDonutPainter oldDelegate) =>
      climbPct != oldDelegate.climbPct ||
      flatPct != oldDelegate.flatPct ||
      descendPct != oldDelegate.descendPct;
}

class _KilometerSplit {
  final int km;
  final double durationSeconds;
  final double paceMinPerKm;
  final double speedKmh;

  const _KilometerSplit({
    required this.km,
    required this.durationSeconds,
    required this.paceMinPerKm,
    required this.speedKmh,
  });
}

class _DetailCache {
  final List<ActivityPoint> points;
  final TrainingAnalysis? analysis;
  final double? totalAscent;
  final double? totalDescent;
  final DateTime timestamp;
  const _DetailCache({required this.points, this.analysis, this.totalAscent, this.totalDescent, required this.timestamp});
}

