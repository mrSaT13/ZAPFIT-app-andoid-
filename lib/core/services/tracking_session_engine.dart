import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:zapfit/core/models/activity.dart';
import 'package:zapfit/core/models/gps_filter_mode.dart';
import 'package:zapfit/core/services/activity_repository.dart';
import 'package:zapfit/core/services/location_service.dart';
import 'package:zapfit/core/services/audio_feedback_service.dart';
import 'package:zapfit/core/services/bluetooth_sensor_service.dart';
import 'package:zapfit/core/utils/geometry/douglas_peucker.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:injectable/injectable.dart';
import 'package:flutter/foundation.dart';

enum TrackingSessionState { idle, initializing, recording, paused, stopped }

const _enableTrackingPhaseADiagnostics = bool.fromEnvironment(
  'ZAPFIT_PHASE_A_DIAGNOSTICS',
  defaultValue: false,
);
const _enableTrackingPhaseBDistanceConsistency = bool.fromEnvironment(
  'ZAPFIT_PHASE_B_DISTANCE_CONSISTENCY',
  defaultValue: false,
);

class PositionSample {
  const PositionSample({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitudeMeters,
    this.horizontalAccuracyMeters,
    this.speed,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitudeMeters;
  final double? horizontalAccuracyMeters;
  final double? speed;
}

abstract class PositionStreamProvider {
  Stream<PositionSample> getPositionStream();
}

@Singleton(as: PositionStreamProvider)
class LocationServicePositionStreamProvider implements PositionStreamProvider {
  LocationServicePositionStreamProvider(this._locationService);

  final LocationService _locationService;

  @override
  Stream<PositionSample> getPositionStream() {
    return _locationService.getPositionStream().map(
      (position) => PositionSample(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
        altitudeMeters: position.altitude,
        horizontalAccuracyMeters: position.accuracy,
        speed: position.speed,
      ),
    );
  }
}

class TrackingSessionSnapshot {
  const TrackingSessionSnapshot({
    required this.state,
    required this.duration,
    required this.distanceMeters,
    required this.elevationGainMeters,
    required this.trackPoints,
    this.activityType,
    this.activityTypeId,
    this.startTime,
    this.finalActivity,
    this.currentHeartRate,
    this.currentCadence,
    this.countdownSeconds,
    this.latestPosition,
    this.lastPositionAt,
    this.isGpsSignalLost = false,
    this.qualityMetrics = const TrackingQualityMetrics(),
  });

  const TrackingSessionSnapshot.idle()
    : state = TrackingSessionState.idle,
      activityType = null,
      activityTypeId = null,
      startTime = null,
      duration = Duration.zero,
      distanceMeters = 0,
      elevationGainMeters = 0,
      trackPoints = const <TrackPoint>[],
      finalActivity = null,
      currentHeartRate = null,
      currentCadence = null,
      countdownSeconds = null,
      latestPosition = null,
      lastPositionAt = null,
      isGpsSignalLost = false,
      qualityMetrics = const TrackingQualityMetrics();

  final TrackingSessionState state;
  final ActivityType? activityType;
  final int? activityTypeId;
  final DateTime? startTime;
  final Duration duration;
  final double distanceMeters;
  final double elevationGainMeters;
  final List<TrackPoint> trackPoints;
  final Activity? finalActivity;
  final int? currentHeartRate;
  final int? currentCadence;
  final int? countdownSeconds;
  final PositionSample? latestPosition;
  final DateTime? lastPositionAt;
  final bool isGpsSignalLost;
  final TrackingQualityMetrics qualityMetrics;

  TrackingSessionSnapshot copyWith({
    TrackingSessionState? state,
    ActivityType? activityType,
    int? activityTypeId,
    bool clearActivityTypeId = false,
    DateTime? startTime,
    Duration? duration,
    double? distanceMeters,
    double? elevationGainMeters,
    List<TrackPoint>? trackPoints,
    Activity? finalActivity,
    int? currentHeartRate,
    int? currentCadence,
    int? countdownSeconds,
    PositionSample? latestPosition,
    DateTime? lastPositionAt,
    bool? isGpsSignalLost,
    TrackingQualityMetrics? qualityMetrics,
    bool clearCountdown = false,
  }) {
    return TrackingSessionSnapshot(
      state: state ?? this.state,
      activityType: activityType ?? this.activityType,
      activityTypeId: clearActivityTypeId
          ? null
          : (activityTypeId ?? this.activityTypeId),
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
      trackPoints: trackPoints ?? this.trackPoints,
      finalActivity: finalActivity ?? this.finalActivity,
      currentHeartRate: currentHeartRate ?? this.currentHeartRate,
      currentCadence: currentCadence ?? this.currentCadence,
      countdownSeconds: clearCountdown
          ? null
          : (countdownSeconds ?? this.countdownSeconds),
      latestPosition: latestPosition ?? this.latestPosition,
      lastPositionAt: lastPositionAt ?? this.lastPositionAt,
      isGpsSignalLost: isGpsSignalLost ?? this.isGpsSignalLost,
      qualityMetrics: qualityMetrics ?? this.qualityMetrics,
    );
  }
}

class TrackingQualityMetrics {
  const TrackingQualityMetrics({
    this.ttffSeconds,
    this.ttffP50Seconds,
    this.ttffP95Seconds,
    this.gpsSignalLossCount = 0,
    this.gpsSignalRecoveryCount = 0,
    this.acceptedPoints = 0,
    this.rejectedByAccuracy = 0,
    this.rejectedByMinDistance = 0,
    this.rejectedBySpeed = 0,
    this.rejectedByAcceleration = 0,
    this.gpsSignalLossDurationSeconds = 0,
    this.syntheticDistanceCreditMeters = 0,
    this.acceptedTrackDistanceMeters = 0,
    this.distanceDivergenceMeters = 0,
    this.distanceDivergenceRatio = 0,
    this.phaseBConsistencyEnabled = false,
    this.rawElevationGainMeters = 0,
    this.filteredElevationGainMeters = 0,
    this.avgHeartRateBpm,
    this.avgCadenceRpm,
  });

  final double? ttffSeconds;
  final double? ttffP50Seconds;
  final double? ttffP95Seconds;
  final int gpsSignalLossCount;
  final int gpsSignalRecoveryCount;
  final int acceptedPoints;
  final int rejectedByAccuracy;
  final int rejectedByMinDistance;
  final int rejectedBySpeed;
  final int rejectedByAcceleration;
  final double gpsSignalLossDurationSeconds;
  final double syntheticDistanceCreditMeters;
  final double acceptedTrackDistanceMeters;
  final double distanceDivergenceMeters;
  final double distanceDivergenceRatio;
  final bool phaseBConsistencyEnabled;
  final double rawElevationGainMeters;
  final double filteredElevationGainMeters;
  final double? avgHeartRateBpm;
  final double? avgCadenceRpm;

  Map<String, dynamic> toJson() {
    return {
      'ttff_seconds': ttffSeconds,
      'ttff_p50_seconds': ttffP50Seconds,
      'ttff_p95_seconds': ttffP95Seconds,
      'gps_signal_loss_count': gpsSignalLossCount,
      'gps_signal_recovery_count': gpsSignalRecoveryCount,
      'accepted_points': acceptedPoints,
      'rejected_by_accuracy': rejectedByAccuracy,
      'rejected_by_min_distance': rejectedByMinDistance,
      'rejected_by_speed': rejectedBySpeed,
      'rejected_by_acceleration': rejectedByAcceleration,
      'gps_signal_loss_duration_seconds': gpsSignalLossDurationSeconds,
      'synthetic_distance_credit_meters': syntheticDistanceCreditMeters,
      'accepted_track_distance_meters': acceptedTrackDistanceMeters,
      'distance_divergence_meters': distanceDivergenceMeters,
      'distance_divergence_ratio': distanceDivergenceRatio,
      'phase_b_consistency_enabled': phaseBConsistencyEnabled,
      'raw_elevation_gain_meters': rawElevationGainMeters,
      'filtered_elevation_gain_meters': filteredElevationGainMeters,
      'avg_heart_rate_bpm': avgHeartRateBpm,
      'avg_cadence_rpm': avgCadenceRpm,
    };
  }
}

class TrackingDiagnosticsSummary {
  const TrackingDiagnosticsSummary({
    this.enabled = false,
    this.totalSamples = 0,
    this.acceptedSamples = 0,
    this.rejectedSamples = 0,
    this.maxStreamGapMs = 0,
    this.streamGapOver2sCount = 0,
    this.streamGapOver5sCount = 0,
    this.acceptedAccuracyAvgMeters,
    this.rejectedAccuracyAvgMeters,
    this.rejectedByReason = const <String, int>{},
  });

  final bool enabled;
  final int totalSamples;
  final int acceptedSamples;
  final int rejectedSamples;
  final int maxStreamGapMs;
  final int streamGapOver2sCount;
  final int streamGapOver5sCount;
  final double? acceptedAccuracyAvgMeters;
  final double? rejectedAccuracyAvgMeters;
  final Map<String, int> rejectedByReason;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'enabled': enabled,
      'total_samples': totalSamples,
      'accepted_samples': acceptedSamples,
      'rejected_samples': rejectedSamples,
      'max_stream_gap_ms': maxStreamGapMs,
      'stream_gap_over_2s_count': streamGapOver2sCount,
      'stream_gap_over_5s_count': streamGapOver5sCount,
      'accepted_accuracy_avg_meters': acceptedAccuracyAvgMeters,
      'rejected_accuracy_avg_meters': rejectedAccuracyAvgMeters,
      'rejected_by_reason': rejectedByReason,
    };
  }
}

@singleton
class TrackingSessionEngine {
  TrackingSessionEngine({
    required LocationService locationService,
    required ActivityRepository activityRepository,
    required AudioFeedbackService audioService,
    required BluetoothSensorService bluetoothService,
    PositionStreamProvider? positionStreamProvider,
    @Named('phaseADiagnostics') bool? enablePhaseADiagnostics,
    @Named('phaseBDistanceConsistency') bool? enablePhaseBDistanceConsistency,
    // We remove the function type dependency for now to simplify DI
    // DateTime Function()? nowProvider,
  }) : _activityRepository = activityRepository,
       _audio = audioService,
       _bluetoothService = bluetoothService,
       _positionStreamProvider =
           positionStreamProvider ??
           LocationServicePositionStreamProvider(locationService),
       _enablePhaseADiagnostics =
           enablePhaseADiagnostics ?? _enableTrackingPhaseADiagnostics,
       _enablePhaseBDistanceConsistency =
           enablePhaseBDistanceConsistency ??
           _enableTrackingPhaseBDistanceConsistency,
       _nowProvider = DateTime.now {
    _subscribeToPositionStream();
  }

  final ActivityRepository _activityRepository;
  final AudioFeedbackService _audio;
  final BluetoothSensorService _bluetoothService;
  final PositionStreamProvider _positionStreamProvider;
  final bool _enablePhaseADiagnostics;
  final bool _enablePhaseBDistanceConsistency;
  final DateTime Function() _nowProvider;

  // Current Session
  String? _currentActivityId;

  // Re-map internal fields to match logic
  ActivityRepository get _repository => _activityRepository;

  int _lastSplitKm = 0;
  DateTime? _lastSplitTime;

  // Bluetooth
  StreamSubscription<int>? _hrSubscription;
  StreamSubscription<int>? _cadenceSubscription;

  // GPS Watchdog
  Timer? _gpsWatchdogTimer;
  bool _isGpsSignalLost = false;
  DateTime? _lastGpsAnnouncementTime;
  static const Duration _gpsDebounce = Duration(seconds: 60);
  static const Duration _gpsWatchdogMinTimeout = Duration(seconds: 14);
  static const Duration _gpsWatchdogMaxTimeout = Duration(seconds: 45);
  static const double _gpsWatchdogCadenceMultiplier = 3.0;
  DateTime? _lastPositionArrivalAt;
  Duration _observedPositionCadence = const Duration(seconds: 1);

  final StreamController<TrackingSessionSnapshot> _streamController =
      StreamController<TrackingSessionSnapshot>.broadcast();

  TrackingSessionSnapshot _snapshot = const TrackingSessionSnapshot.idle();
  StreamSubscription<PositionSample>? _positionSubscription;
  Timer? _durationTicker;
  Timer? _positionReconnectTimer;
  bool _isDisposed = false;
  double? _abLat;
  double? _abLng;
  double _abLatVelocity = 0;
  double _abLngVelocity = 0;
  DateTime? _abLastTimestamp;
  double? _lastAcceptedSegmentSpeed;
  double? _lastAcceptedAccuracyMeters;
  DateTime? _trackingRequestedAt;
  DateTime? _firstAcceptedPointAt;
  DateTime? _gpsSignalLostStartedAt;
  Duration _gpsSignalLossDuration = Duration.zero;
  int _gpsSignalLossCount = 0;
  int _gpsSignalRecoveryCount = 0;
  int _acceptedPointsCount = 0;
  int _rejectedByAccuracyCount = 0;
  int _rejectedByMinDistanceCount = 0;
  int _rejectedBySpeedCount = 0;
  int _rejectedByAccelerationCount = 0;
  final List<double> _ttffHistorySeconds = <double>[];
  final String _gpsDiagSessionId = _buildGpsDiagSessionId();
  bool _hasLoggedFirstStreamPoint = false;
  DateTime? _diagLastSampleTimestamp;
  int _diagTotalSamples = 0;
  int _diagAcceptedSamples = 0;
  int _diagRejectedSamples = 0;
  int _diagMaxStreamGapMs = 0;
  int _diagStreamGapOver2sCount = 0;
  int _diagStreamGapOver5sCount = 0;
  double _diagAcceptedAccuracySum = 0;
  int _diagAcceptedAccuracyCount = 0;
  double _diagRejectedAccuracySum = 0;
  int _diagRejectedAccuracyCount = 0;
  final Map<String, int> _diagRejectedByReason = <String, int>{};
  final List<Map<String, Object?>> _diagRecentEvents = <Map<String, Object?>>[];
  static const int _diagRecentEventsLimit = 180;
  double _syntheticDistanceCreditMeters = 0;
  double _acceptedTrackDistanceMeters = 0;
  double _rawElevationGainMeters = 0;

  TrackingSessionState get currentSessionState => _snapshot.state;
  TrackingSessionSnapshot get snapshot => _snapshot;
  Stream<TrackingSessionSnapshot> get stream => _streamController.stream;
  TrackingDiagnosticsSummary get diagnosticsSummary =>
      _buildDiagnosticsSummary();
  List<Map<String, Object?>> get diagnosticsRecentEvents =>
      List<Map<String, Object?>>.unmodifiable(_diagRecentEvents);

  // GPS Smoothing
  final List<PositionSample> _recentPositions = [];
  static const int _smoothingWindowSize = 3;

  // Configuration
  GpsFilterMode _gpsFilterMode = GpsFilterMode.auto;
  static const double minPointDistanceMeters = 5.0;
  static const double maxAcceptedAccuracyMeters = 40.0;
  static const double maxAcceptedAccuracyRideMeters = 30.0;
  static const double maxAcceptedAccuracyWalkRunMeters = 25.0;
  static const double maxSegmentSpeedMetersPerSecond = 35.0; // ~126 km/h
  static const double maxWalkSpeedMetersPerSecond = 3.0; // ~10.8 km/h
  static const double maxRunSpeedMetersPerSecond = 13.0; // ~46.8 km/h
  static const double maxRideSpeedMetersPerSecond = 25.0; // ~90 km/h
  static const Duration runWalkWarmupWindow = Duration(seconds: 20);
  static const double shortDistanceGuardrailMaxMeters = 120.0;
  static const double shortDistanceDeferredCapMeters = 12.0;
  static const double shortDistanceDeferredPerSampleMaxMeters = 3.0;
  static const double shortDistanceSyntheticCreditSessionCapMeters = 10.0;
  static const double elevationDeltaNoiseThresholdMeters = 1.5;
  static const Duration startupReanchorWindow = Duration(seconds: 12);
  static const int startupReanchorMinSamples = 3;
  static const int startupReanchorMaxSamples = 5;
  static const double startupReanchorAccuracyMaxMeters = 25.0;
  static const double startupReanchorMaxOffsetMeters = 20.0;

  void _subscribeToPositionStream() {
    if (_isDisposed || _positionSubscription != null) return;
    _hasLoggedFirstStreamPoint = false;
    _logGpsDiag('stream_subscribe_attempt');
    _positionSubscription = _positionStreamProvider.getPositionStream().listen(
      (position) {
        if (!_hasLoggedFirstStreamPoint) {
          _hasLoggedFirstStreamPoint = true;
          _logGpsDiag(
            'stream_first_position',
            details: <String, Object?>{
              'lat': position.latitude,
              'lng': position.longitude,
              'accuracy': position.horizontalAccuracyMeters,
              'state': _snapshot.state.name,
            },
          );
        }
        _positionReconnectTimer?.cancel();
        _positionReconnectTimer = null;
        _handlePositionUpdate(position);
      },
      onError: (Object e) {
        _logGpsDiag(
          'stream_error',
          details: <String, Object?>{'error': e.toString()},
        );
        _positionSubscription = null;
        _isGpsSignalLost = true;
        _snapshot = _snapshot.copyWith(isGpsSignalLost: true);
        _emitSnapshot();
        _schedulePositionReconnect();
      },
      onDone: () {
        _logGpsDiag('stream_done');
        _positionSubscription = null;
        if (!_isDisposed) {
          _schedulePositionReconnect();
        }
      },
    );
  }

  void _schedulePositionReconnect() {
    if (_isDisposed) return;
    if (_positionReconnectTimer != null) return;
    _logGpsDiag('stream_reconnect_scheduled');
    _positionReconnectTimer = Timer(const Duration(seconds: 2), () {
      _positionReconnectTimer = null;
      _logGpsDiag('stream_reconnect_triggered');
      _subscribeToPositionStream();
    });
  }

  void _handlePositionUpdate(PositionSample rawPosition) {
    if (rawPosition.latitude == 0 && rawPosition.longitude == 0) return;
    _updateWatchdogCadence();
    _snapshot = _snapshot.copyWith(
      latestPosition: rawPosition,
      lastPositionAt: rawPosition.timestamp,
    );
    _emitSnapshot();

    if (_snapshot.state == TrackingSessionState.recording) {
      _startGpsWatchdog();
      _onGpsSignalRecovered();
    }

    if (_snapshot.state != TrackingSessionState.recording) return;
    _recordDiagnosticRawSample(rawPosition);
    _collectStartupAnchorSample(rawPosition);

    final isRunWalkWarmup = _isRunWalkWarmup(rawPosition.timestamp);

    _recentPositions.add(rawPosition);
    if (_recentPositions.length > _smoothingWindowSize) {
      _recentPositions.removeAt(0);
    }

    double latSum = 0;
    double lngSum = 0;
    double weightSum = 0;

    for (int i = 0; i < _recentPositions.length; i++) {
      final pos = _recentPositions[i];
      final accuracy = pos.horizontalAccuracyMeters ?? 20.0;
      final accuracyWeight = 1.0 / (accuracy > 0 ? accuracy : 20.0);
      final recencyWeight = (i + 1).toDouble();

      final weight = accuracyWeight * recencyWeight;

      latSum += pos.latitude * weight;
      lngSum += pos.longitude * weight;
      weightSum += weight;
    }

    final smoothedLat = latSum / weightSum;
    final smoothedLng = lngSum / weightSum;
    final filtered = _applyAlphaBetaFilter(
      latitude: smoothedLat,
      longitude: smoothedLng,
      timestamp: rawPosition.timestamp,
      horizontalAccuracyMeters: rawPosition.horizontalAccuracyMeters,
      speed: rawPosition.speed,
      isRunWalkWarmup: isRunWalkWarmup,
    );

    final trackPoint = TrackPoint(
      latitude: filtered.$1,
      longitude: filtered.$2,
      altitudeMeters: rawPosition.altitudeMeters ?? 0,
      timestamp: rawPosition.timestamp,
      heartRate: _snapshot.currentHeartRate,
      cadence: _snapshot.currentCadence,
    );

    final maxAccuracy = _dynamicAccuracyThreshold(
      rawPosition,
      isRunWalkWarmup: isRunWalkWarmup,
    );
    if (rawPosition.horizontalAccuracyMeters != null &&
        rawPosition.horizontalAccuracyMeters! > maxAccuracy) {
      _rejectedByAccuracyCount += 1;
      _emitQualityMetricsSnapshot();
      _recordDiagnosticDecision(
        accepted: false,
        reason: 'accuracy',
        rawPosition: rawPosition,
        filteredLatitude: trackPoint.latitude,
        filteredLongitude: trackPoint.longitude,
        maxAccuracyMeters: maxAccuracy,
      );
      return;
    }

    _processValidPosition(
      trackPoint,
      rawPosition,
      isRunWalkWarmup: isRunWalkWarmup,
    );
  }

  void _processValidPosition(
    TrackPoint point,
    PositionSample rawPosition, {
    required bool isRunWalkWarmup,
  }) {
    final previousPoints = _snapshot.trackPoints;
    double newDistance = _snapshot.distanceMeters;
    double elevationGain = _snapshot.elevationGainMeters;

    if (previousPoints.isNotEmpty) {
      final lastPoint = previousPoints.last;
      final dist = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        point.latitude,
        point.longitude,
      );

      final dynamicMinDistance = _dynamicMinPointDistance(
        rawPosition,
        isRunWalkWarmup: isRunWalkWarmup,
      );
      final elapsedSeconds =
          point.timestamp.difference(lastPoint.timestamp).inMilliseconds / 1000;
      if (dist < dynamicMinDistance) {
        final shortDistanceCredit = _shortDistanceRejectCredit(
          dist: dist,
          elapsedSeconds: elapsedSeconds,
          rawPosition: rawPosition,
        );
        if (shortDistanceCredit > 0) {
          _syntheticDistanceCreditMeters += shortDistanceCredit;
          _snapshot = _snapshot.copyWith(
            distanceMeters: _snapshot.distanceMeters + shortDistanceCredit,
          );
          _emitSnapshot();
        }
        _accumulateDeferredShortDistance(
          dist: dist,
          elapsedSeconds: elapsedSeconds,
          rawPosition: rawPosition,
        );
        _rejectedByMinDistanceCount += 1;
        _emitQualityMetricsSnapshot();
        _recordDiagnosticDecision(
          accepted: false,
          reason: 'min_distance',
          rawPosition: rawPosition,
          filteredLatitude: point.latitude,
          filteredLongitude: point.longitude,
          segmentDistanceMeters: dist,
          elapsedSeconds: elapsedSeconds,
          minDistanceMeters: dynamicMinDistance,
          shortDistanceCreditMeters: shortDistanceCredit,
        );
        return;
      }

      if (elapsedSeconds > 0) {
        final activityType = _snapshot.activityType;
        final isWalkOrRun =
            activityType == ActivityType.walk ||
            activityType == ActivityType.run;
        final currentAccuracy = (rawPosition.horizontalAccuracyMeters ?? 20)
            .clamp(3, 80)
            .toDouble();
        final previousAccuracy =
            (_lastAcceptedAccuracyMeters ?? currentAccuracy)
                .clamp(3, 80)
                .toDouble();
        final uncertaintyRadiusMeters = math.max(
          currentAccuracy,
          previousAccuracy,
        );
        final reportedSpeed = rawPosition.speed ?? (dist / elapsedSeconds);
        final lowConfidenceDisplacement = isRunWalkWarmup
            ? uncertaintyRadiusMeters >= 15 &&
                  dist <= (uncertaintyRadiusMeters * 0.9) &&
                  reportedSpeed <= 1.8
            : uncertaintyRadiusMeters >= 12 &&
                  dist <= (uncertaintyRadiusMeters * 1.15) &&
                  reportedSpeed <= 2.6;
        if (isWalkOrRun && lowConfidenceDisplacement) {
          _rejectedByMinDistanceCount += 1;
          _emitQualityMetricsSnapshot();
          _recordDiagnosticDecision(
            accepted: false,
            reason: 'low_confidence_displacement',
            rawPosition: rawPosition,
            filteredLatitude: point.latitude,
            filteredLongitude: point.longitude,
            segmentDistanceMeters: dist,
            elapsedSeconds: elapsedSeconds,
            minDistanceMeters: dynamicMinDistance,
          );
          return;
        }
        final segmentSpeed = dist / elapsedSeconds;
        if (segmentSpeed > _maxSpeedForCurrentActivity()) {
          _rejectedBySpeedCount += 1;
          _emitQualityMetricsSnapshot();
          _recordDiagnosticDecision(
            accepted: false,
            reason: 'speed',
            rawPosition: rawPosition,
            filteredLatitude: point.latitude,
            filteredLongitude: point.longitude,
            segmentDistanceMeters: dist,
            elapsedSeconds: elapsedSeconds,
            segmentSpeedMetersPerSecond: segmentSpeed,
          );
          return;
        }
        final prevSpeed = _lastAcceptedSegmentSpeed;
        final maxAcceleration = _maxAccelerationForCurrentActivity();
        if (prevSpeed != null &&
            rawPosition.horizontalAccuracyMeters != null &&
            rawPosition.horizontalAccuracyMeters! >
                _dynamicAccuracyThreshold(
                      rawPosition,
                      isRunWalkWarmup: isRunWalkWarmup,
                    ) *
                    0.8) {
          final acceleration =
              (segmentSpeed - prevSpeed).abs() / elapsedSeconds;
          if (acceleration > maxAcceleration) {
            _rejectedByAccelerationCount += 1;
            _emitQualityMetricsSnapshot();
            _recordDiagnosticDecision(
              accepted: false,
              reason: 'acceleration',
              rawPosition: rawPosition,
              filteredLatitude: point.latitude,
              filteredLongitude: point.longitude,
              segmentDistanceMeters: dist,
              elapsedSeconds: elapsedSeconds,
              segmentSpeedMetersPerSecond: segmentSpeed,
            );
            return;
          }
        }
        _lastAcceptedSegmentSpeed = segmentSpeed;
      }

      newDistance += dist;
      if (_enablePhaseBDistanceConsistency) {
        _acceptedTrackDistanceMeters += dist;
      }
      final deferredConsumed = _consumeDeferredShortDistance(
        dist: dist,
        rawPosition: rawPosition,
      );
      newDistance += deferredConsumed;
      if (deferredConsumed > 0) {
        _syntheticDistanceCreditMeters += deferredConsumed;
      }

      // Elevation gain
      if (point.altitudeMeters != null && lastPoint.altitudeMeters != null) {
        if (point.altitudeMeters! > lastPoint.altitudeMeters!) {
          final diff = point.altitudeMeters! - lastPoint.altitudeMeters!;
          _rawElevationGainMeters += diff;
          if (diff >= elevationDeltaNoiseThresholdMeters) {
            elevationGain += diff;
          }
        }
      }
    }

    // --- NEW: Kilometer Split Logic ---
    final currentKm = (newDistance / 1000).floor();
    if (currentKm > _lastSplitKm) {
      // Calculate split pace
      // We need time taken for this last kilometer.
      // Total duration so far: _snapshot.duration + time since last tick?
      // Actually _snapshot.duration is updated by ticker.
      // Better: use current timestamp - last split timestamp.
      final now = point.timestamp;
      final lastTime = _lastSplitTime ?? _snapshot.startTime ?? now;

      final durationSinceLastSplit = now.difference(lastTime);
      final distanceSinceLastSplit = newDistance - (_lastSplitKm * 1000);

      // Safety check to avoid division by zero
      if (distanceSinceLastSplit > 0) {
        final secondsPerKm =
            durationSinceLastSplit.inSeconds / (distanceSinceLastSplit / 1000);
        _audio.announceSplit(km: currentKm, paceSecondsPerKm: secondsPerKm);
      }

      _lastSplitKm = currentKm;
      _lastSplitTime = now;
    }
    // ----------------------------------

    // 1. Stream to Database
    if (_currentActivityId != null) {
      _repository.insertTrackPoint(_currentActivityId!, point);

      // Update stats periodically (e.g. every point or every N points)
      // For now, let's update activity stats in DB only on stop/pause to save writes,
      // OR we can update "distance" in Activity table periodically.
      // Let's stick to streaming points for now.
    }

    // 2. Manage In-Memory Path (UI)
    var newPoints = List<TrackPoint>.from(previousPoints)..add(point);

    // Simplification Strategy:
    // If the path grows too large, run Douglas-Peucker to compress it.
    // Threshold: 2000 points (~1 hour of raw 1s data is 3600 points).
    // Compression target: ~500-1000 points for smooth rendering.
    if (newPoints.length > 2000) {
      // Simplify with 5 meters tolerance
      newPoints = DouglasPeucker.simplify(newPoints, 5.0);
    }

    _snapshot = _snapshot.copyWith(
      trackPoints: newPoints,
      distanceMeters: newDistance,
      elevationGainMeters: elevationGain,
    );
    _maybeApplyStartupReanchor(point.timestamp);
    _acceptedPointsCount += 1;
    _lastAcceptedAccuracyMeters = rawPosition.horizontalAccuracyMeters;
    _firstAcceptedPointAt ??= point.timestamp;
    _emitQualityMetricsSnapshot();
    _recordDiagnosticDecision(
      accepted: true,
      reason: 'accepted',
      rawPosition: rawPosition,
      filteredLatitude: point.latitude,
      filteredLongitude: point.longitude,
      totalDistanceMeters: newDistance,
    );
    _emitSnapshot();
  }

  void setGpsFilterMode(GpsFilterMode mode) {
    _gpsFilterMode = mode;
  }

  Future<bool> start(
    ActivityType activityType, {
    int? activityTypeId,
    DateTime? startedAt,
    bool useCountdown = false,
  }) async {
    if (_snapshot.state != TrackingSessionState.idle &&
        _snapshot.state != TrackingSessionState.stopped) {
      return false;
    }

    // Initialize snapshot
    _snapshot = TrackingSessionSnapshot(
      state: TrackingSessionState.initializing,
      activityType: activityType,
      activityTypeId: activityTypeId,
      startTime: null,
      duration: Duration.zero,
      distanceMeters: 0,
      elevationGainMeters: 0,
      trackPoints: const <TrackPoint>[],
      countdownSeconds: useCountdown ? 6 : null, // Start at 6 if countdown used
    );
    _emitSnapshot();

    if (useCountdown) {
      // Force initial snapshot with 6 seconds (or 5) to ensure UI shows "Starting..." immediately
      _snapshot = _snapshot.copyWith(
        state: TrackingSessionState.initializing,
        countdownSeconds: 5,
      );
      _emitSnapshot();

      // Announce "Starting" before counting down? No, usually "5, 4, 3..."
      // But we can say "Starting workout" first.

      for (var i = 5; i > 0; i--) {
        // Emit countdown update
        _snapshot = _snapshot.copyWith(countdownSeconds: i);
        _emitSnapshot();

        // Speak
        unawaited(_audio.announceCountdown(i));

        // Wait 1 second
        await Future<void>.delayed(const Duration(seconds: 1));

        // Check if cancelled during countdown?
        if (_snapshot.state != TrackingSessionState.initializing) return false;
      }
    }

    // TRANSITION: Recording
    // DO NOT cancel the position subscription if it's the SAME provider we just set up.
    // If we cancel it here, we stop receiving GPS updates!
    // await _positionSubscription?.cancel(); // REMOVED THIS LINE

    // Announce start
    await _audio.announceStartSession();
    final startTime = startedAt ?? _nowProvider();

    // Initialize Database Session
    _currentActivityId = startTime.microsecondsSinceEpoch.toString();
    final initialActivity = Activity(
      id: _currentActivityId!,
      activityType: activityType,
      activityTypeId: activityTypeId,
      startedAt: startTime,
      endedAt: null, // In progress
      distanceMeters: 0,
      trackPoints: const [],
    );
    await _repository.create(initialActivity);

    _snapshot = _snapshot.copyWith(
      state: TrackingSessionState.recording,
      startTime: startTime,
      isGpsSignalLost: false,
      clearCountdown: true, // Clear countdown
    );

    // Reset state
    _lastSplitKm = 0;
    _lastSplitTime = startTime;
    _isGpsSignalLost = false;
    _lastGpsAnnouncementTime = null;
    _recentPositions.clear();
    _resetSmoothingState();
    _resetQualityMetrics();
    _resetDiagnosticsState();
    _trackingRequestedAt = startTime;
    _lastPositionArrivalAt = null;
    _observedPositionCadence = const Duration(seconds: 1);
    _emitQualityMetricsSnapshot();

    _emitSnapshot();
    _startDurationTicker();

    _subscribeToBluetoothSensors();
    _startGpsWatchdog();

    return true;
  }

  Future<void> pause() async {
    if (_snapshot.state != TrackingSessionState.recording) return;

    _unsubscribeFromBluetoothSensors();
    _durationTicker?.cancel();
    _gpsWatchdogTimer?.cancel();
    _durationTicker = null;
    _positionReconnectTimer?.cancel();
    _positionReconnectTimer = null;
    _closeGpsLossWindow(_nowProvider());

    // Enter Paused State
    _snapshot = _snapshot.copyWith(state: TrackingSessionState.paused);
    _emitSnapshot();

    // Optional: Announce paused?
  }

  Future<void> resume() async {
    if (_snapshot.state != TrackingSessionState.paused) return;

    // Enter Recording State
    _snapshot = _snapshot.copyWith(state: TrackingSessionState.recording);
    _emitSnapshot();

    // Re-activate side effects
    _startDurationTicker();
    _subscribeToBluetoothSensors();
    _startGpsWatchdog();
  }

  Future<Activity?> stop({DateTime? endedAt}) async {
    if (_snapshot.state != TrackingSessionState.recording &&
        _snapshot.state != TrackingSessionState.paused) {
      return null;
    }

    _unsubscribeFromBluetoothSensors();
    _durationTicker?.cancel();
    _gpsWatchdogTimer?.cancel();
    _durationTicker = null;
    _positionReconnectTimer?.cancel();
    _positionReconnectTimer = null;
    _closeGpsLossWindow(_nowProvider());

    final startTime = _snapshot.startTime;
    final activityType = _snapshot.activityType;
    final activityTypeId = _snapshot.activityTypeId;

    // If we never properly started (e.g. cancelled during init), reset to idle
    if (startTime == null || activityType == null) {
      _snapshot = const TrackingSessionSnapshot.idle();
      _emitSnapshot();
      return null;
    }

    final candidateEnd = endedAt ?? _nowProvider();
    final endTime = candidateEnd.isBefore(startTime) ? startTime : candidateEnd;

    // Create Activity (Final State)
    final activity = Activity(
      id: _currentActivityId ?? endTime.microsecondsSinceEpoch.toString(),
      activityType: activityType,
      activityTypeId: activityTypeId,
      startedAt: startTime,
      endedAt: endTime,
      distanceMeters: _snapshot.distanceMeters,
      qualityMetrics: _buildQualityMetrics().toJson(),
      // For the final record, we might want the FULL path from DB or the simplified one.
      // Since we streamed points to DB, the DB has the FULL path.
      // The Activity object we return here usually goes to UI or Upload.
      // If we upload, we probably want the full path.
      // BUT: 'trackPoints' here comes from _snapshot, which is simplified.
      // ISSUE: If we simplify _snapshot, we lose high-res data for the "Activity" object returned here.
      // SOLUTION: Since we streamed everything to DB, we should re-fetch the FULL list from DB
      // if we want to return a "complete" activity, OR rely on the DB being the source of truth.
      // However, to save IO, we can just return what we have (simplified) and let the UploadService
      // fetch from DB if it needs raw data.
      // Wait, UploadService takes an 'Activity' object. If that object has simplified points, we upload simplified points.
      // That might be desired (smaller payload) or not.
      // Let's assume we want to upload FULL data.
      // So we should probably fetch from repository.
      trackPoints: List<TrackPoint>.from(_snapshot.trackPoints),
    );

    // Update the existing activity in DB to mark it as finished
    // Note: We used to call create(). Now we call update().
    await _repository.update(activity);

    // Clean up
    _currentActivityId = null;

    // TRANSITION: Stopped
    _appendTtffHistoryIfPresent();
    _snapshot = TrackingSessionSnapshot(
      state: TrackingSessionState.stopped,
      activityType: activityType,
      activityTypeId: activityTypeId,
      startTime: startTime,
      duration: Duration(seconds: activity.durationSeconds),
      distanceMeters: activity.distanceMeters,
      elevationGainMeters: activity.elevationGainMeters,
      trackPoints: activity.trackPoints,
      finalActivity: activity,
      latestPosition: _snapshot.latestPosition,
      lastPositionAt: _snapshot.lastPositionAt,
      isGpsSignalLost: false,
      qualityMetrics: _buildQualityMetrics(),
    );
    _emitPhaseADiagnosticsSummary();
    _emitQualitySummaryEvent();
    _resetSmoothingState();
    _emitSnapshot();

    return activity;
  }

  Future<void> reset() async {
    // Force transition to Idle from any state
    _unsubscribeFromBluetoothSensors();
    _durationTicker?.cancel();
    _gpsWatchdogTimer?.cancel();
    _durationTicker = null;
    _positionReconnectTimer?.cancel();
    _positionReconnectTimer = null;
    _closeGpsLossWindow(_nowProvider());

    _snapshot = const TrackingSessionSnapshot.idle();
    _resetSmoothingState();
    _resetQualityMetrics();
    _resetDiagnosticsState();
    _emitSnapshot();
  }

  Future<void> startIntervalPlan(dynamic plan) async {
    // TODO: Implement interval plan tracking
    // For now, just start a regular tracking session
    await start(ActivityType.run);
  }

  Future<void> deleteSavedActivity(String id) async {
    await _repository.delete(id);
  }

  void _startGpsWatchdog() {
    _gpsWatchdogTimer?.cancel();
    _gpsWatchdogTimer = Timer(_gpsWatchdogTimeout(), _onGpsSignalLost);
  }

  void _onGpsSignalLost() {
    if (_snapshot.state != TrackingSessionState.recording) return;
    if (!_isGpsSignalLost) {
      _isGpsSignalLost = true;
      _gpsSignalLossCount += 1;
      _logGpsDiag(
        'gps_signal_lost',
        details: <String, Object?>{'loss_count': _gpsSignalLossCount},
      );
      _gpsSignalLostStartedAt = _nowProvider();
      _emitQualityMetricsSnapshot();
      _snapshot = _snapshot.copyWith(isGpsSignalLost: true);
      _emitSnapshot();
      _announceGpsStatus(true);
    }
  }

  void _onGpsSignalRecovered() {
    if (_isGpsSignalLost) {
      _isGpsSignalLost = false;
      _gpsSignalRecoveryCount += 1;
      _logGpsDiag(
        'gps_signal_recovered',
        details: <String, Object?>{'recovery_count': _gpsSignalRecoveryCount},
      );
      _closeGpsLossWindow(_nowProvider());
      _emitQualityMetricsSnapshot();
      _snapshot = _snapshot.copyWith(isGpsSignalLost: false);
      _emitSnapshot();
      _announceGpsStatus(false);
    }
    _startGpsWatchdog();
  }

  void _announceGpsStatus(bool isLost) {
    final now = _nowProvider();
    if (_lastGpsAnnouncementTime == null ||
        now.difference(_lastGpsAnnouncementTime!) > _gpsDebounce) {
      _audio.announceGpsStatus(isLost: isLost);
      _lastGpsAnnouncementTime = now;
    }
  }

  void dispose() {
    _isDisposed = true;
    _closeGpsLossWindow(_nowProvider());
    _positionSubscription?.cancel();
    _positionReconnectTimer?.cancel();
    _unsubscribeFromBluetoothSensors();
    _durationTicker?.cancel();
    _gpsWatchdogTimer?.cancel();
    _streamController.close();
  }

  void _resetSmoothingState() {
    _recentPositions.clear();
    _abLat = null;
    _abLng = null;
    _abLatVelocity = 0;
    _abLngVelocity = 0;
    _abLastTimestamp = null;
    _lastAcceptedSegmentSpeed = null;
    _lastAcceptedAccuracyMeters = null;
    _lastPositionArrivalAt = null;
    _observedPositionCadence = const Duration(seconds: 1);
    _deferredShortDistanceMeters = 0;
    _startupAnchorSamples.clear();
    _startupReanchorLocked = false;
  }

  void _updateWatchdogCadence() {
    final now = _nowProvider();
    final lastArrival = _lastPositionArrivalAt;
    _lastPositionArrivalAt = now;
    if (lastArrival == null) return;
    final elapsedMs = now
        .difference(lastArrival)
        .inMilliseconds
        .clamp(200, 30000)
        .toDouble();
    final previousMs = _observedPositionCadence.inMilliseconds.toDouble();
    final smoothedMs = ((previousMs * 0.7) + (elapsedMs * 0.3)).round();
    _observedPositionCadence = Duration(milliseconds: smoothedMs);
  }

  Duration _gpsWatchdogTimeout() {
    final dynamicMs =
        (_observedPositionCadence.inMilliseconds *
                _gpsWatchdogCadenceMultiplier)
            .round();
    final minMs = _gpsWatchdogMinTimeout.inMilliseconds;
    final maxMs = _gpsWatchdogMaxTimeout.inMilliseconds;
    final boundedMs = dynamicMs.clamp(minMs, maxMs);
    return Duration(milliseconds: boundedMs);
  }

  void _resetQualityMetrics() {
    _trackingRequestedAt = null;
    _firstAcceptedPointAt = null;
    _gpsSignalLostStartedAt = null;
    _gpsSignalLossDuration = Duration.zero;
    _gpsSignalLossCount = 0;
    _gpsSignalRecoveryCount = 0;
    _acceptedPointsCount = 0;
    _rejectedByAccuracyCount = 0;
    _rejectedByMinDistanceCount = 0;
    _rejectedBySpeedCount = 0;
    _rejectedByAccelerationCount = 0;
    _syntheticDistanceCreditMeters = 0;
    _acceptedTrackDistanceMeters = 0;
    _rawElevationGainMeters = 0;
    _deferredShortDistanceMeters = 0;
    _startupAnchorSamples.clear();
    _startupReanchorLocked = false;
  }

  void _resetDiagnosticsState() {
    _diagLastSampleTimestamp = null;
    _diagTotalSamples = 0;
    _diagAcceptedSamples = 0;
    _diagRejectedSamples = 0;
    _diagMaxStreamGapMs = 0;
    _diagStreamGapOver2sCount = 0;
    _diagStreamGapOver5sCount = 0;
    _diagAcceptedAccuracySum = 0;
    _diagAcceptedAccuracyCount = 0;
    _diagRejectedAccuracySum = 0;
    _diagRejectedAccuracyCount = 0;
    _diagRejectedByReason.clear();
    _diagRecentEvents.clear();
  }

  TrackingDiagnosticsSummary _buildDiagnosticsSummary() {
    if (!_enablePhaseADiagnostics) {
      return const TrackingDiagnosticsSummary(enabled: false);
    }
    final acceptedAvg = _diagAcceptedAccuracyCount > 0
        ? _diagAcceptedAccuracySum / _diagAcceptedAccuracyCount
        : null;
    final rejectedAvg = _diagRejectedAccuracyCount > 0
        ? _diagRejectedAccuracySum / _diagRejectedAccuracyCount
        : null;
    return TrackingDiagnosticsSummary(
      enabled: true,
      totalSamples: _diagTotalSamples,
      acceptedSamples: _diagAcceptedSamples,
      rejectedSamples: _diagRejectedSamples,
      maxStreamGapMs: _diagMaxStreamGapMs,
      streamGapOver2sCount: _diagStreamGapOver2sCount,
      streamGapOver5sCount: _diagStreamGapOver5sCount,
      acceptedAccuracyAvgMeters: acceptedAvg,
      rejectedAccuracyAvgMeters: rejectedAvg,
      rejectedByReason: Map<String, int>.from(_diagRejectedByReason),
    );
  }

  void _recordDiagnosticRawSample(PositionSample rawPosition) {
    if (!_enablePhaseADiagnostics) return;
    _diagTotalSamples += 1;
    final lastTimestamp = _diagLastSampleTimestamp;
    if (lastTimestamp != null) {
      final gapMs = rawPosition.timestamp
          .difference(lastTimestamp)
          .inMilliseconds;
      if (gapMs > 0) {
        if (gapMs > _diagMaxStreamGapMs) {
          _diagMaxStreamGapMs = gapMs;
        }
        if (gapMs >= 2000) {
          _diagStreamGapOver2sCount += 1;
        }
        if (gapMs >= 5000) {
          _diagStreamGapOver5sCount += 1;
        }
      }
    }
    _diagLastSampleTimestamp = rawPosition.timestamp;
  }

  void _recordDiagnosticDecision({
    required bool accepted,
    required String reason,
    required PositionSample rawPosition,
    required double filteredLatitude,
    required double filteredLongitude,
    double? maxAccuracyMeters,
    double? minDistanceMeters,
    double? segmentDistanceMeters,
    double? elapsedSeconds,
    double? segmentSpeedMetersPerSecond,
    double? shortDistanceCreditMeters,
    double? totalDistanceMeters,
  }) {
    if (!_enablePhaseADiagnostics) return;
    if (accepted) {
      _diagAcceptedSamples += 1;
      final accuracy = rawPosition.horizontalAccuracyMeters;
      if (accuracy != null && accuracy.isFinite) {
        _diagAcceptedAccuracySum += accuracy;
        _diagAcceptedAccuracyCount += 1;
      }
    } else {
      _diagRejectedSamples += 1;
      _diagRejectedByReason.update(
        reason,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      final accuracy = rawPosition.horizontalAccuracyMeters;
      if (accuracy != null && accuracy.isFinite) {
        _diagRejectedAccuracySum += accuracy;
        _diagRejectedAccuracyCount += 1;
      }
    }
    final event = <String, Object?>{
      'event': 'point_decision',
      'session_id': _gpsDiagSessionId,
      'accepted': accepted,
      'reason': reason,
      'timestamp': rawPosition.timestamp.toIso8601String(),
      'state': _snapshot.state.name,
      'raw_lat': rawPosition.latitude,
      'raw_lng': rawPosition.longitude,
      'raw_accuracy_m': rawPosition.horizontalAccuracyMeters,
      'raw_altitude_m': rawPosition.altitudeMeters,
      'raw_speed_mps': rawPosition.speed,
      'filtered_lat': filteredLatitude,
      'filtered_lng': filteredLongitude,
      'max_accuracy_m': maxAccuracyMeters,
      'min_distance_m': minDistanceMeters,
      'segment_distance_m': segmentDistanceMeters,
      'elapsed_s': elapsedSeconds,
      'segment_speed_mps': segmentSpeedMetersPerSecond,
      'short_distance_credit_m': shortDistanceCreditMeters,
      'total_distance_m': totalDistanceMeters,
    };
    _diagRecentEvents.add(event);
    if (_diagRecentEvents.length > _diagRecentEventsLimit) {
      _diagRecentEvents.removeAt(0);
    }
    debugPrint('tracking_phase_a_diag:${jsonEncode(event)}');
  }

  double _deferredShortDistanceMeters = 0;
  final List<PositionSample> _startupAnchorSamples = <PositionSample>[];
  bool _startupReanchorLocked = false;

  void _accumulateDeferredShortDistance({
    required double dist,
    required double elapsedSeconds,
    required PositionSample rawPosition,
  }) {
    if (!_isShortDistanceGuardrailEligible(rawPosition)) return;
    if (elapsedSeconds <= 0) return;
    if (dist < 1.0) return;
    final speed = rawPosition.speed ?? (dist / elapsedSeconds);
    if (speed < 0.9) return;
    final addition = dist
        .clamp(0.0, shortDistanceDeferredPerSampleMaxMeters)
        .toDouble();
    _deferredShortDistanceMeters = (_deferredShortDistanceMeters + addition)
        .clamp(0.0, shortDistanceDeferredCapMeters)
        .toDouble();
  }

  double _consumeDeferredShortDistance({
    required double dist,
    required PositionSample rawPosition,
  }) {
    if (_deferredShortDistanceMeters <= 0) return 0;
    if (!_isShortDistanceGuardrailEligible(rawPosition)) return 0;
    final remainingBudget = _remainingShortDistanceCreditBudget();
    if (remainingBudget <= 0) return 0;
    final consumeLimit = dist * 0.6;
    if (consumeLimit <= 0) return 0;
    final consumed = math.min(
      _deferredShortDistanceMeters,
      math.min(consumeLimit, remainingBudget),
    );
    _deferredShortDistanceMeters = (_deferredShortDistanceMeters - consumed)
        .clamp(0.0, 1000.0)
        .toDouble();
    return consumed;
  }

  bool _isShortDistanceGuardrailEligible(PositionSample rawPosition) {
    final activityType = _snapshot.activityType;
    if (activityType != ActivityType.run && activityType != ActivityType.walk) {
      return false;
    }
    if (_snapshot.distanceMeters > shortDistanceGuardrailMaxMeters) {
      return false;
    }
    final accuracy = rawPosition.horizontalAccuracyMeters;
    if (accuracy != null && accuracy > 25) return false;
    return true;
  }

  double _shortDistanceRejectCredit({
    required double dist,
    required double elapsedSeconds,
    required PositionSample rawPosition,
  }) {
    if (!_isShortDistanceGuardrailEligible(rawPosition)) return 0;
    if (elapsedSeconds <= 0) return 0;
    if (dist < 1.0) return 0;
    final remainingBudget = _remainingShortDistanceCreditBudget();
    if (remainingBudget <= 0) return 0;
    final speed = rawPosition.speed ?? (dist / elapsedSeconds);
    if (speed < 0.9) return 0;
    return math.min(math.min(dist * 0.35, 1.2), remainingBudget);
  }

  double _remainingShortDistanceCreditBudget() {
    return (shortDistanceSyntheticCreditSessionCapMeters -
            _syntheticDistanceCreditMeters)
        .clamp(0.0, shortDistanceSyntheticCreditSessionCapMeters)
        .toDouble();
  }

  void _collectStartupAnchorSample(PositionSample rawPosition) {
    if (!_isStartupReanchorEligible(rawPosition.timestamp)) return;
    final accuracy = rawPosition.horizontalAccuracyMeters;
    if (accuracy != null && accuracy > startupReanchorAccuracyMaxMeters) return;
    _startupAnchorSamples.add(rawPosition);
    if (_startupAnchorSamples.length > startupReanchorMaxSamples) {
      _startupAnchorSamples.removeAt(0);
    }
  }

  bool _isStartupReanchorEligible(DateTime timestamp) {
    if (_startupReanchorLocked) return false;
    final activityType = _snapshot.activityType;
    if (activityType != ActivityType.run && activityType != ActivityType.walk) {
      return false;
    }
    if (_snapshot.trackPoints.isEmpty) return false;
    final startTime = _snapshot.startTime;
    if (startTime == null) return false;
    final elapsed = timestamp.difference(startTime);
    if (elapsed.isNegative) return false;
    return elapsed <= startupReanchorWindow;
  }

  void _maybeApplyStartupReanchor(DateTime timestamp) {
    if (!_isStartupReanchorEligible(timestamp)) return;
    if (_startupAnchorSamples.length < startupReanchorMinSamples) return;
    final firstPoint = _snapshot.trackPoints.first;
    final medianLat = _median(
      _startupAnchorSamples.map((sample) => sample.latitude).toList(),
    );
    final medianLng = _median(
      _startupAnchorSamples.map((sample) => sample.longitude).toList(),
    );
    final offsetMeters = Geolocator.distanceBetween(
      firstPoint.latitude,
      firstPoint.longitude,
      medianLat,
      medianLng,
    );
    if (offsetMeters < 2 || offsetMeters > startupReanchorMaxOffsetMeters) {
      if (_snapshot.trackPoints.length >= startupReanchorMaxSamples) {
        _startupReanchorLocked = true;
      }
      return;
    }

    final updatedFirst = TrackPoint(
      latitude: medianLat,
      longitude: medianLng,
      altitudeMeters: firstPoint.altitudeMeters,
      timestamp: firstPoint.timestamp,
      heartRate: firstPoint.heartRate,
      cadence: firstPoint.cadence,
    );
    final updatedPoints = <TrackPoint>[
      updatedFirst,
      ..._snapshot.trackPoints.skip(1),
    ];
    final recomputedDistance = _recomputeDistanceMeters(updatedPoints);
    if (_enablePhaseBDistanceConsistency) {
      _acceptedTrackDistanceMeters = recomputedDistance;
    }
    _snapshot = _snapshot.copyWith(
      trackPoints: updatedPoints,
      distanceMeters: recomputedDistance,
    );
    _emitSnapshot();
    if (_snapshot.trackPoints.length >= startupReanchorMinSamples) {
      _startupReanchorLocked = true;
    }
  }

  double _recomputeDistanceMeters(List<TrackPoint> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  void _closeGpsLossWindow(DateTime until) {
    final started = _gpsSignalLostStartedAt;
    if (started == null) return;
    if (until.isAfter(started)) {
      _gpsSignalLossDuration += until.difference(started);
    }
    _gpsSignalLostStartedAt = null;
  }

  void _appendTtffHistoryIfPresent() {
    final ttffSeconds = _computeTtffSeconds();
    if (ttffSeconds == null) return;
    _ttffHistorySeconds.add(ttffSeconds);
    if (_ttffHistorySeconds.length > 64) {
      _ttffHistorySeconds.removeAt(0);
    }
  }

  double? _computeTtffSeconds() {
    final requestedAt = _trackingRequestedAt;
    final firstAcceptedAt = _firstAcceptedPointAt;
    if (requestedAt == null || firstAcceptedAt == null) return null;
    if (firstAcceptedAt.isBefore(requestedAt)) return 0;
    return firstAcceptedAt.difference(requestedAt).inMilliseconds / 1000.0;
  }

  double? _percentile(List<double> values, double percentile) {
    if (values.isEmpty) return null;
    final sorted = List<double>.from(values)..sort();
    final rank = ((sorted.length - 1) * percentile).round();
    return sorted[rank.clamp(0, sorted.length - 1)];
  }

  TrackingQualityMetrics _buildQualityMetrics() {
    final acceptedTrackDistanceMeters = _enablePhaseBDistanceConsistency
        ? _acceptedTrackDistanceMeters
        : 0.0;
    final syntheticDistanceCreditMeters = _enablePhaseBDistanceConsistency
        ? _syntheticDistanceCreditMeters
        : 0.0;
    final summaryDistanceMeters = _snapshot.distanceMeters;
    final divergenceMeters = _enablePhaseBDistanceConsistency
        ? (summaryDistanceMeters - acceptedTrackDistanceMeters).abs()
        : 0.0;
    final divergenceRatio = !_enablePhaseBDistanceConsistency
        ? 0.0
        : (acceptedTrackDistanceMeters > 0
              ? divergenceMeters / acceptedTrackDistanceMeters
              : (divergenceMeters > 0 ? 1.0 : 0.0));
    final hrValues = _snapshot.trackPoints
        .map((point) => point.heartRate)
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    final cadenceValues = _snapshot.trackPoints
        .map((point) => point.cadence)
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    final avgHeartRate = hrValues.isEmpty
        ? null
        : hrValues.fold<int>(0, (sum, value) => sum + value) / hrValues.length;
    final avgCadence = cadenceValues.isEmpty
        ? null
        : cadenceValues.fold<int>(0, (sum, value) => sum + value) /
              cadenceValues.length;
    return TrackingQualityMetrics(
      ttffSeconds: _computeTtffSeconds(),
      ttffP50Seconds: _percentile(_ttffHistorySeconds, 0.50),
      ttffP95Seconds: _percentile(_ttffHistorySeconds, 0.95),
      gpsSignalLossCount: _gpsSignalLossCount,
      gpsSignalRecoveryCount: _gpsSignalRecoveryCount,
      acceptedPoints: _acceptedPointsCount,
      rejectedByAccuracy: _rejectedByAccuracyCount,
      rejectedByMinDistance: _rejectedByMinDistanceCount,
      rejectedBySpeed: _rejectedBySpeedCount,
      rejectedByAcceleration: _rejectedByAccelerationCount,
      gpsSignalLossDurationSeconds:
          _gpsSignalLossDuration.inMilliseconds / 1000.0,
      syntheticDistanceCreditMeters: syntheticDistanceCreditMeters,
      acceptedTrackDistanceMeters: acceptedTrackDistanceMeters,
      distanceDivergenceMeters: divergenceMeters,
      distanceDivergenceRatio: divergenceRatio,
      phaseBConsistencyEnabled: _enablePhaseBDistanceConsistency,
      rawElevationGainMeters: _rawElevationGainMeters,
      filteredElevationGainMeters: _snapshot.elevationGainMeters,
      avgHeartRateBpm: avgHeartRate,
      avgCadenceRpm: avgCadence,
    );
  }

  void _emitQualityMetricsSnapshot() {
    _snapshot = _snapshot.copyWith(qualityMetrics: _buildQualityMetrics());
  }

  void _emitQualitySummaryEvent() {
    final payload = _snapshot.qualityMetrics.toJson();
    final encoded = jsonEncode(payload);
    debugPrint('tracking_quality_summary:$encoded');
  }

  void _emitPhaseADiagnosticsSummary() {
    if (!_enablePhaseADiagnostics) return;
    final payload = _buildDiagnosticsSummary().toJson();
    payload['session_id'] = _gpsDiagSessionId;
    payload['state'] = _snapshot.state.name;
    payload['recent_event_count'] = _diagRecentEvents.length;
    debugPrint('tracking_phase_a_summary:${jsonEncode(payload)}');
  }

  static String _buildGpsDiagSessionId() {
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return micros.toRadixString(36);
  }

  void _logGpsDiag(String event, {Map<String, Object?> details = const {}}) {
    final payload = <String, Object?>{
      'scope': 'tracking_engine',
      'event': event,
      'session_id': _gpsDiagSessionId,
      'state': _snapshot.state.name,
      ...details,
    };
    debugPrint('gps_diag:${jsonEncode(payload)}');
  }

  (double, double) _applyAlphaBetaFilter({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required double? horizontalAccuracyMeters,
    required double? speed,
    required bool isRunWalkWarmup,
  }) {
    final lastLat = _abLat;
    final lastLng = _abLng;
    final lastTimestamp = _abLastTimestamp;
    if (lastLat == null || lastLng == null || lastTimestamp == null) {
      _abLat = latitude;
      _abLng = longitude;
      _abLastTimestamp = timestamp;
      return (latitude, longitude);
    }

    final dtMs = timestamp.difference(lastTimestamp).inMilliseconds;
    final dt = (dtMs <= 0 ? 1 : dtMs) / 1000.0;
    final boundedDt = dt.clamp(0.2, 3.0);

    final predictedLat = lastLat + (_abLatVelocity * boundedDt);
    final predictedLng = lastLng + (_abLngVelocity * boundedDt);

    final speedMs = (speed ?? 0).clamp(0, 45).toDouble();
    final accuracy = (horizontalAccuracyMeters ?? 20).clamp(3, 80).toDouble();
    final quality = (1 - ((accuracy - 3) / 77)).clamp(0.0, 1.0);

    var alpha = 0.5 + (0.35 * quality);
    var beta = 0.05 + (0.16 * quality);
    if (speedMs > 8) {
      alpha += 0.05;
      beta += 0.03;
    }
    if (isRunWalkWarmup) {
      alpha += 0.05;
      beta += 0.02;
    }
    alpha = alpha.clamp(0.45, 0.9);
    beta = beta.clamp(0.03, 0.25);

    final residualLat = latitude - predictedLat;
    final residualLng = longitude - predictedLng;

    final correctedLat = predictedLat + (alpha * residualLat);
    final correctedLng = predictedLng + (alpha * residualLng);

    _abLatVelocity += (beta / boundedDt) * residualLat;
    _abLngVelocity += (beta / boundedDt) * residualLng;
    _abLat = correctedLat;
    _abLng = correctedLng;
    _abLastTimestamp = timestamp;
    return (correctedLat, correctedLng);
  }

  double _dynamicAccuracyThreshold(
    PositionSample rawPosition, {
    required bool isRunWalkWarmup,
  }) {
    final base = _maxAccuracyForCurrentActivity();
    final speed = (rawPosition.speed ?? 0).clamp(0, 45).toDouble();
    final activityType = _snapshot.activityType;
    var threshold = base;
    if (activityType == ActivityType.ride && speed > 10) {
      threshold += 6;
    } else if (activityType == ActivityType.run && speed > 5) {
      threshold += 4;
    } else if (activityType == ActivityType.walk && speed < 1.5) {
      threshold -= 3;
    }
    if (_gpsFilterMode == GpsFilterMode.strict) {
      threshold -= 2;
    } else if (_gpsFilterMode == GpsFilterMode.normal) {
      threshold += 2;
    }
    if (isRunWalkWarmup &&
        (activityType == ActivityType.run ||
            activityType == ActivityType.walk)) {
      threshold += 5;
    }
    return threshold.clamp(15, 50).toDouble();
  }

  double _dynamicMinPointDistance(
    PositionSample rawPosition, {
    required bool isRunWalkWarmup,
  }) {
    final speed = (rawPosition.speed ?? 0).clamp(0, 45).toDouble();
    final accuracy = (rawPosition.horizontalAccuracyMeters ?? 20)
        .clamp(3, 80)
        .toDouble();

    if (isRunWalkWarmup) {
      var warmupThreshold = 3.5;
      final isEarlyWarmup = _isEarlyRunWalkWarmup(rawPosition.timestamp);
      if (isEarlyWarmup && speed >= 1.8 && accuracy <= 15) {
        warmupThreshold -= 1.0;
      }
      if (speed < 1.2) {
        warmupThreshold += 0.8;
      }
      if (accuracy > 20) {
        warmupThreshold += 0.7;
      }
      if (speed > 8) {
        warmupThreshold -= 1.5;
      }
      return warmupThreshold.clamp(2.5, 8.0);
    }

    var threshold = minPointDistanceMeters;
    if (speed < 1.2) {
      threshold += 2.0;
    }
    if (accuracy > 20) {
      threshold += 1.5;
    }
    if (speed > 8) {
      threshold -= 1.5;
    }
    return threshold.clamp(3.0, 10.0);
  }

  bool _isEarlyRunWalkWarmup(DateTime timestamp) {
    if (!_isRunWalkWarmup(timestamp)) return false;
    final startTime = _snapshot.startTime;
    if (startTime == null) return false;
    final elapsed = timestamp.difference(startTime);
    if (elapsed.isNegative) return false;
    return elapsed <= const Duration(seconds: 8);
  }

  bool _isRunWalkWarmup(DateTime timestamp) {
    if (_snapshot.state != TrackingSessionState.recording) return false;
    final startTime = _snapshot.startTime;
    final activityType = _snapshot.activityType;
    if (startTime == null) return false;
    if (activityType != ActivityType.run && activityType != ActivityType.walk) {
      return false;
    }
    final elapsed = timestamp.difference(startTime);
    if (elapsed.isNegative) return false;
    return elapsed <= runWalkWarmupWindow;
  }

  double _maxAccelerationForCurrentActivity() {
    final activityType = _snapshot.activityType;
    switch (activityType) {
      case ActivityType.walk:
        return 4.0;
      case ActivityType.run:
        return 6.5;
      case ActivityType.ride:
        return 8.5;
      case null:
        return 7.0;
    }
  }

  // _subscribeToPositionStream is defined above with smoothing logic

  void _subscribeToBluetoothSensors() {
    _hrSubscription?.cancel();
    _hrSubscription = _bluetoothService.heartRate.listen((hr) {
      _snapshot = _snapshot.copyWith(currentHeartRate: hr);
      _emitSnapshot();
    });

    _cadenceSubscription?.cancel();
    _cadenceSubscription = _bluetoothService.cadence.listen((cad) {
      _snapshot = _snapshot.copyWith(currentCadence: cad);
      _emitSnapshot();
    });
  }

  void _unsubscribeFromBluetoothSensors() {
    _hrSubscription?.cancel();
    _cadenceSubscription?.cancel();
    _hrSubscription = null;
    _cadenceSubscription = null;
  }

  // Removed unused methods
  // void _handlePositionStreamInterruption...
  // void _onPosition...
  // bool addPoint...
  // void _checkSplit...

  void _emitSnapshot() {
    if (!_streamController.isClosed) {
      _streamController.add(_snapshot);
    }
  }

  void _startDurationTicker() {
    _durationTicker?.cancel();
    // Do not cancel watchdog here!
    _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_snapshot.state != TrackingSessionState.recording) {
        return;
      }
      final now = _nowProvider();
      final startTime = _snapshot.startTime;
      if (startTime == null) return;

      final duration = now.isAfter(startTime)
          ? now.difference(startTime)
          : Duration.zero;
      _snapshot = _snapshot.copyWith(duration: duration);
      _emitSnapshot();
    });
  }

  static double calculateDistanceMeters(TrackPoint from, TrackPoint to) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _degreesToRadians(from.latitude);
    final lat2 = _degreesToRadians(to.latitude);
    final deltaLat = _degreesToRadians(to.latitude - from.latitude);
    final deltaLng = _degreesToRadians(to.longitude - from.longitude);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double calculateElevationGainMeters(List<TrackPoint> points) {
    if (points.length < 2) return 0;
    var gain = 0.0;
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1].altitudeMeters;
      final current = points[i].altitudeMeters;
      if (previous == null || current == null) continue;
      final delta = current - previous;
      if (delta >= elevationDeltaNoiseThresholdMeters) {
        gain += delta;
      }
    }
    return gain;
  }

  static double _degreesToRadians(double degrees) => degrees * (math.pi / 180);

  double _maxAccuracyForCurrentActivity() {
    if (_gpsFilterMode == GpsFilterMode.normal) {
      return maxAcceptedAccuracyMeters;
    }
    if (_gpsFilterMode == GpsFilterMode.strict) {
      final activityType = _snapshot.activityType;
      if (activityType == ActivityType.ride) return 22;
      return 18;
    }
    final activityType = _snapshot.activityType;
    if (activityType == ActivityType.ride) return maxAcceptedAccuracyRideMeters;
    if (activityType == ActivityType.run || activityType == ActivityType.walk) {
      return maxAcceptedAccuracyWalkRunMeters;
    }
    return maxAcceptedAccuracyMeters;
  }

  double _maxSpeedForCurrentActivity() {
    if (_gpsFilterMode == GpsFilterMode.normal) {
      return maxSegmentSpeedMetersPerSecond;
    }
    if (_gpsFilterMode == GpsFilterMode.strict) {
      final activityType = _snapshot.activityType;
      switch (activityType) {
        case ActivityType.walk:
          return 6.0;
        case ActivityType.run:
          return 12.0;
        case ActivityType.ride:
          return 18.0;
        case null:
          return 18.0;
      }
    }
    final activityType = _snapshot.activityType;
    switch (activityType) {
      case ActivityType.walk:
        return maxWalkSpeedMetersPerSecond;
      case ActivityType.run:
        return maxRunSpeedMetersPerSecond;
      case ActivityType.ride:
        return maxRideSpeedMetersPerSecond;
      case null:
        return maxSegmentSpeedMetersPerSecond;
    }
  }
}
