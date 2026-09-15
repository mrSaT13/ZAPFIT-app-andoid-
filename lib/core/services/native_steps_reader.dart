import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Чтение шагомера.
/// 1) Прямой Android Sensor через EventChannel (работает без разрешений на большинстве устройств)
/// 2) Pedometer package (fallback)
/// 3) Ручной ввод
class NativeStepsReader {
  static final NativeStepsReader instance = NativeStepsReader._();
  NativeStepsReader._();

  static const _stepChannel = EventChannel('com.zapfit/step_counter');

  String _source = 'none';
  bool _hasPermission = false;
  bool _platformChannelActive = false;

  int? _cumulativeSteps;
  int _baselineSteps = 0;
  DateTime? _baselineDate;

  StreamSubscription<dynamic>? _platformSub;

  String get source => _source;

  Future<bool> requestPermissions() async {
    try {
      final status = await Permission.activityRecognition.request();
      _hasPermission = status.isGranted;
      if (_hasPermission) {
        _source = 'pedometer';
      }
      await _loadBaseline();
      await _tryPlatformChannel();
      return _hasPermission;
    } catch (e) {
      debugPrint('NativeStepsReader.requestPermissions: $e');
      _hasPermission = false;
      await _tryPlatformChannel();
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    try {
      final status = await Permission.activityRecognition.status;
      _hasPermission = status.isGranted;
      return _hasPermission;
    } catch (e) {
      return false;
    }
  }

  Future<void> _tryPlatformChannel() async {
    try {
      _platformSub?.cancel();
      _platformSub = _stepChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is Map) {
            final cumulative = event['cumulative'] as int?;
            if (cumulative != null) {
              _cumulativeSteps = cumulative;
              _platformChannelActive = true;
              _source = 'pedometer';
              _checkBaseline(cumulative);
              debugPrint('NativeStepsReader [platform]: cumulative=$cumulative, today=${cumulative - _baselineSteps}');
            }
          }
        },
        onError: (e) {
          debugPrint('NativeStepsReader platform channel error: $e');
          if (!_platformChannelActive) {
            _source = 'manual';
          }
        },
        onDone: () {
          debugPrint('NativeStepsReader platform channel done');
        },
      );
    } catch (e) {
      debugPrint('NativeStepsReader platform channel failed: $e');
      _source = 'manual';
    }
  }

  void _checkBaseline(int cumulative) {
    final now = DateTime.now();
    if (_baselineDate == null || !_isSameDay(_baselineDate!, now)) {
      _baselineSteps = cumulative;
      _baselineDate = now;
      _saveBaseline();
    }
  }

  Future<void> _loadBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDateStr = prefs.getString('steps_baseline_date');
      final savedBaseline = prefs.getInt('steps_baseline_value') ?? 0;

      if (savedDateStr != null) {
        final savedDate = DateTime.tryParse(savedDateStr);
        final now = DateTime.now();
        if (savedDate != null && _isSameDay(savedDate, now)) {
          _baselineSteps = savedBaseline;
          _baselineDate = savedDate;
          debugPrint('NativeStepsReader: loaded baseline=$_baselineSteps for today');
        }
      }
    } catch (e) {
      debugPrint('NativeStepsReader._loadBaseline: $e');
    }
  }

  Future<void> _saveBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('steps_baseline_date', _baselineDate!.toIso8601String());
      await prefs.setInt('steps_baseline_value', _baselineSteps);
    } catch (e) {
      debugPrint('NativeStepsReader._saveBaseline: $e');
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<int?> readStepsForDate(DateTime date) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requestedDay = DateTime(date.year, date.month, date.day);

    if (requestedDay.isAtSameMomentAs(today)) {
      // Если нет данных — запускаем listener и ждём
      if (_cumulativeSteps == null) {
        if (!_platformChannelActive && _platformSub == null) {
          _tryPlatformChannel();
        }
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      if (_cumulativeSteps == null) return 0;
      final todaySteps = _cumulativeSteps! - _baselineSteps;
      return todaySteps < 0 ? 0 : todaySteps;
    }

    return null;
  }

  void resetBaseline() {
    _baselineSteps = _cumulativeSteps ?? 0;
    _baselineDate = DateTime.now();
    _saveBaseline();
  }

  void dispose() {
    _platformSub?.cancel();
  }
}
