import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class WidgetsService {
  WidgetsService._();
  static final WidgetsService instance = WidgetsService._();

  SharedPreferences? _prefs;
  static const _channel = MethodChannel('com.zapfit/widgets');

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('WidgetsService init error: $e');
    }
  }

  Future<void> updateStepsWidget(int steps, int goal) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setInt('today_steps', steps);
      await prefs.setInt('today_goal', goal);
      await prefs.setString('last_update', DateFormat('HH:mm').format(DateTime.now()));
      _notifyWidgets();
    } catch (e) {
      debugPrint('WidgetsService updateStepsWidget error: $e');
    }
  }

  Future<void> updateSummaryWidget({
    required int steps,
    required double water,
    required double distance,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setInt('today_steps', steps);
      await prefs.setString('water_today', water.toStringAsFixed(0));
      await prefs.setString('distance_today', distance.toStringAsFixed(2));
      await prefs.setString('last_update', DateFormat('HH:mm').format(DateTime.now()));
      _notifyWidgets();
    } catch (e) {
      debugPrint('WidgetsService updateSummaryWidget error: $e');
    }
  }

  Future<void> updateSleepWidget({
    required int totalSeconds,
    required int deepSeconds,
    required int lightSeconds,
    required int remSeconds,
    required int score,
    required String sleepRange,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setInt('sleep_total_min', totalSeconds ~/ 60);
      await prefs.setInt('sleep_deep_min', deepSeconds ~/ 60);
      await prefs.setInt('sleep_light_min', lightSeconds ~/ 60);
      await prefs.setInt('sleep_rem_min', remSeconds ~/ 60);
      await prefs.setInt('sleep_score', score);
      await prefs.setString('sleep_range', sleepRange);
      await prefs.setString('last_update', DateFormat('HH:mm').format(DateTime.now()));
      _notifyWidgets();
    } catch (e) {
      debugPrint('WidgetsService updateSleepWidget error: $e');
    }
  }

  Future<void> updateHrWidget({
    required int currentHr,
    required int restingHr,
    required int maxHr,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setInt('hr_current', currentHr);
      await prefs.setInt('hr_resting', restingHr);
      await prefs.setInt('hr_max', maxHr);
      await prefs.setString('last_update', DateFormat('HH:mm').format(DateTime.now()));
      _notifyWidgets();
    } catch (e) {
      debugPrint('WidgetsService updateHrWidget error: $e');
    }
  }

  void _notifyWidgets() {
    try {
      _channel.invokeMethod('updateWidgets');
    } catch (_) {
      // MethodChannel может быть недоступен (десктоп и т.д.)
    }
  }
}
