import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/zapfit_uploader.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/health_connect_service.dart';
import 'package:zapfit/core/services/widgets_service.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/utils/url_utils.dart';
import 'package:zapfit/core/utils/sleep_score_calculator.dart';
import 'package:flutter/foundation.dart';

class HealthService extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final LocalActivityRepository _repository = LocalActivityRepository.instance;

  bool _isDisposed = false;
  double _syncProgress = 0;
  bool _isSyncing = false;
  String _syncStatus = '';
  int _totalToSync = 0;
  int _currentSynced = 0;
  HealthDashboard? _dashboard;
  bool _isLoading = false;
  int? _averageSleepHr;

  final Set<String> _syncedThisSession = {};
  List<WeightRecord> _weightRecords = [];
  List<SleepRecord> _sleepRecords = [];
  List<WaterRecord> _waterRecords = [];
  List<StepsRecord> _stepsRecords = [];
  List<HeartRateRecord> _heartRateRecords = [];

  // Getters
  double get syncProgress => _syncProgress;
  bool get isSyncing => _isSyncing;
  String get syncStatus => _syncStatus;
  int get totalToSync => _totalToSync;
  int get currentSynced => _currentSynced;
  HealthDashboard? get dashboard => _dashboard;
  List<WeightRecord> get weightRecords => _weightRecords;
  List<SleepRecord> get sleepRecords => _sleepRecords;
  List<WaterRecord> get waterRecords => _waterRecords;
  List<StepsRecord> get stepsRecords => _stepsRecords;
  List<HeartRateRecord> get heartRateRecords => _heartRateRecords;
  bool get isLoading => _isLoading;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  Future<void> loadLocalData() async {
    _isLoading = true;
    notifyListeners();

    _weightRecords = await _repository.getWeightRecords();
    _sleepRecords = await _repository.getSleepRecords();
    _waterRecords = await _repository.getWaterRecords();
    _stepsRecords = await _repository.getStepsRecords();
    _heartRateRecords = await _repository.getHeartRateRecords();
    
    // Compute HR statistics from sleep records
    _computeSleepHrStatistics();
    
    _updateDashboardFromLocal();

    _isLoading = false;
    notifyListeners();
  }

  /// Compute average/min/max HR from sleep records
  void _computeSleepHrStatistics() {
    if (_sleepRecords.isEmpty) return;
    
    final avgHrValues = _sleepRecords
        .where((r) => r.avgHeartRate != null)
        .map((r) => r.avgHeartRate!)
        .toList();
    
    if (avgHrValues.isNotEmpty) {
      final total = avgHrValues.reduce((a, b) => a + b);
      _averageSleepHr = (total / avgHrValues.length).round();
    }
  }

  void _updateDashboardFromLocal() {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    
    double totalWater = 0;
    for (final r in _waterRecords) {
      if (r.date.toIso8601String().startsWith(todayStr)) {
        totalWater += r.amountMl;
      } else if (r.date.toIso8601String().compareTo(todayStr) < 0) {
        break;
      }
    }

    int totalSteps = 0;
    for (final r in _stepsRecords) {
      if (r.date.toIso8601String().startsWith(todayStr)) {
        totalSteps += r.steps;
      } else if (r.date.toIso8601String().compareTo(todayStr) < 0) {
        break;
      }
    }

    // Вычисляем средний HR за последние 7 дней
    int avgHrLast7Days = 0;
    int hrCount = 0;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    for (final r in _heartRateRecords) {
      if (r.timestamp.isAfter(sevenDaysAgo)) {
        avgHrLast7Days += r.bpm;
        hrCount++;
      }
    }
    avgHrLast7Days = hrCount > 0 ? (avgHrLast7Days / hrCount).round() : 0;

    _dashboard = HealthDashboard(
      latestWeight: _weightRecords.isNotEmpty ? _weightRecords.first : null,
      latestSleep: _sleepRecords.isNotEmpty ? _sleepRecords.first : null,
      todaySteps: totalSteps,
      todayWaterMl: totalWater,
      todayNutrition: false,
      avgHeartRateLast7Days: avgHrLast7Days,
    );
  }

  // --- Public Data Management Methods (Restored) ---

  Future<void> addWeight(double weight) async {
    await _repository.addWeightRecord(WeightRecord(
      weight: weight, 
      date: DateTime.now(), 
      isSynced: false
    ));
    await loadLocalData();
    syncAll();
  }

  Future<void> addWeightWithComposition(WeightRecord record) async {
    await _repository.addWeightRecord(record);
    await loadLocalData();
    syncAll();
  }

  Future<void> updateWeight(WeightRecord record) async {
    await _repository.updateWeightRecord(record.copyWith(isSynced: false));
    await loadLocalData();
    syncAll();
  }

  Future<void> deleteWeightRecord(int id) async {
    await _repository.deleteHealthRecord('weight_records', id);
    await loadLocalData();
    syncAll();
  }

  /// Compute the sleep score if it is missing, so all consumers
  /// (widget, dashboard, profile) get a real value, not null/0.
  int? _ensureSleepScore(SleepRecord record) {
    final existing = record.sleepScoreOverall;
    if (existing != null && existing > 0) return existing;
    if (record.totalSleepSeconds <= 0) return existing;
    return SleepScoreCalculator.calculate(
      totalSleepSeconds: record.totalSleepSeconds,
      deepSleepSeconds: record.deepSleepSeconds,
      lightSleepSeconds: record.lightSleepSeconds,
      remSleepSeconds: record.remSleepSeconds,
      awakeSleepSeconds: record.awakeSleepSeconds,
      restHr: record.restHeartRate?.toDouble(),
      age: AppSettingsController.instance.userAge,
    ).score;
  }

  Future<void> addSleep(SleepRecord record) async {
    final score = _ensureSleepScore(record);
    await _repository.upsertSleepRecord(record.copyWith(sleepScoreOverall: score, isSynced: false));
    await loadLocalData();
    syncAll();
  }

  Future<void> updateSleep(SleepRecord record) async {
    final score = _ensureSleepScore(record);
    await _repository.upsertSleepRecord(record.copyWith(sleepScoreOverall: score, isSynced: false));
    await loadLocalData();
    syncAll();
  }

  Future<void> deleteSleepRecord(int id) async {
    await _repository.deleteHealthRecord('sleep_records', id);
    await loadLocalData();
    syncAll();
  }

  Future<void> addWater(double amountMl) async {
    await _repository.addWaterRecord(WaterRecord(
      date: DateTime.now(), 
      amountMl: amountMl, 
      isSynced: false
    ));
    await loadLocalData();
    syncAll();
  }

  Future<void> updateWater(WaterRecord record) async {
    await _repository.updateWaterRecord(record.copyWith(isSynced: false));
    await loadLocalData();
    syncAll();
  }

  Future<void> deleteWaterRecord(int id) async {
    await _repository.deleteHealthRecord('water_records', id);
    await loadLocalData();
    syncAll();
  }

  Future<void> addStepsRecord(int steps) async {
    await _repository.addStepsRecord(StepsRecord(
      date: DateTime.now(),
      steps: steps,
      isSynced: false,
    ), forceUpdate: true);
    await loadLocalData();
    syncAll();
  }

  Future<void> updateSteps(int steps) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final index = _stepsRecords.indexWhere((r) => r.date.toIso8601String().startsWith(todayStr));
    if (index != -1) {
      await updateStepsRecord(_stepsRecords[index].copyWith(steps: steps));
    } else {
      await addStepsRecord(steps);
    }
  }

  Future<void> updateStepsRecord(StepsRecord record) async {
    await _repository.updateStepsRecord(record.copyWith(isSynced: false));
    await loadLocalData();
    syncAll();
  }

  Future<void> deleteStepsRecord(int id) async {
    await _repository.deleteHealthRecord('steps_records', id);
    await loadLocalData();
    syncAll();
  }

  // --- Heart Rate CRUD ---

  Future<void> addHeartRate(HeartRateRecord record) async {
    await _repository.addHeartRateRecord(record.copyWith(isSynced: false));
    await loadLocalData();
  }

  Future<void> updateHeartRate(HeartRateRecord record) async {
    await _repository.upsertHeartRateRecord(record.copyWith(isSynced: false));
    await loadLocalData();
  }

  Future<void> deleteHeartRateRecord(int id) async {
    await _repository.deleteHeartRateRecord(id);
    await loadLocalData();
  }

  // --- Health Connect Auto-Import ---

  DateTime? _lastAutoImportTime;
  static const _autoImportInterval = Duration(minutes: 30);

  Future<void> autoImportFromHealthConnect({int daysBack = 7, bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastAutoImportTime != null && now.difference(_lastAutoImportTime!) < _autoImportInterval) return;
    _lastAutoImportTime = now;

    try {
      final hc = HealthConnectService.instance;
      final hasPerms = await hc.hasPermissions();
      if (!hasPerms) {
        debugPrint('HealthConnect: permissions not granted — skip auto-import');
        await loadLocalData();
        return;
      }

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysBack));
      debugPrint('HealthConnect: auto-import start=$start end=$now');

      // Import sleep
      debugPrint('HealthConnect: fetching sleep...');
      final sleepData = await hc.fetchSleep(start: start, end: now);
      debugPrint('HealthConnect: got ${sleepData.length} sleep records from HC');
      for (final record in sleepData) {
        debugPrint('HealthConnect: sleep ${record.date.toIso8601String().split('T')[0]} total=${record.totalSleepSeconds}s start=${record.sleepStartTime} end=${record.sleepEndTime}');
        await _repository.upsertSleepRecord(record);
      }

      // Import heart rate
      debugPrint('HealthConnect: fetching heart rate...');
      final hrData = await hc.fetchHeartRate(start: start, end: now);
      debugPrint('HealthConnect: got ${hrData.length} HR records from HC');
      for (final record in hrData) {
        await _repository.upsertHeartRateRecord(record);
      }

      // Import steps — always update with Health Connect data if available
      final stepsData = await hc.fetchSteps(start: start, end: now);
      debugPrint('HealthConnect: got ${stepsData.length} steps records from HC');
      for (final record in stepsData) {
        debugPrint('HealthConnect: steps ${record.date.toIso8601String().split('T')[0]} = ${record.steps}');
        await _repository.upsertStepsRecord(record);
      }

      // Import weight (last record only)
      final weightData = await hc.fetchWeight(start: start, end: now);
      if (weightData.isNotEmpty) {
        final latest = weightData.last;
        final existingWeight = _weightRecords.any((r) =>
            r.date.year == latest.date.year &&
            r.date.month == latest.date.month &&
            r.date.day == latest.date.day);
        if (!existingWeight) {
          await _repository.upsertWeightRecord(latest);
        }
      }

      await loadLocalData();
      await syncAll();
      debugPrint('HealthConnect: auto-import complete');
    } catch (e) {
      debugPrint('HealthConnect: auto-import error: $e');
      await loadLocalData();
    }
  }

  Future<int> importFromHealthConnect({
    required DateTime start,
    required DateTime end,
  }) async {
    int imported = 0;
    try {
      final hc = HealthConnectService.instance;
      final hasPerms = await hc.hasPermissions();
      if (!hasPerms) return 0;

      final sleepData = await hc.fetchSleep(start: start, end: end);
      for (final record in sleepData) {
        await _repository.upsertSleepRecord(record);
        imported++;
      }

      final hrData = await hc.fetchHeartRate(start: start, end: end);
      for (final record in hrData) {
        await _repository.upsertHeartRateRecord(record);
        imported++;
      }

      final stepsData = await hc.fetchSteps(start: start, end: end);
      for (final record in stepsData) {
        await _repository.upsertStepsRecord(record);
        imported++;
      }

      final weightData = await hc.fetchWeight(start: start, end: end);
      for (final record in weightData) {
        await _repository.upsertWeightRecord(record);
        imported++;
      }

      await syncAll();
    } catch (e) {
      debugPrint('HealthConnect: manual import error: $e');
      await loadLocalData();
    }
    return imported;
  }

  Future<void> clearAllLocalHealthData() async {
    await _repository.clearAllHealthData();
    await loadLocalData();
  }

  // --- Sync Logic ---

  Future<void> syncAll() async {
    if (_isSyncing) { debugPrint('HealthSync: Already syncing, skip'); return; }
    _isSyncing = true;
    _syncProgress = 0;
    _syncStatus = 'Отправка данных...';
    _syncedThisSession.clear();
    notifyListeners();
    debugPrint('HealthSync: syncAll() START — weight=${_weightRecords.length}, unsynced=${_weightRecords.where((r) => !r.isSynced).length}');

    try {
      await _pushUnsyncedData();
      
      _syncStatus = 'Получение данных...';
      notifyListeners();

      final categories = [
        {'end': '/api/v1/health/weight', 'lbl': 'Вес', 'tbl': 'weight_records', 'p': [0.1, 0.3]},
        {'end': '/api/v1/health/sleep', 'lbl': 'Сон', 'tbl': 'sleep_records', 'p': [0.3, 0.6]},
        {'end': '/api/v1/health/water', 'lbl': 'Вода', 'tbl': 'water_records', 'p': [0.6, 0.8]},
        {'end': '/api/v1/health/steps', 'lbl': 'Шаги', 'tbl': 'steps_records', 'p': [0.8, 1.0]},
      ];

      for (var cat in categories) {
        await _syncCategoryGeneric(
          endpoint: cat['end'] as String,
          label: cat['lbl'] as String,
          tableName: cat['tbl'] as String,
          startP: (cat['p'] as List<double>)[0],
          endP: (cat['p'] as List<double>)[1],
        );
      }

      await loadLocalData();
      _syncStatus = 'Синхронизация завершена';

      _updateWidgets();
    } catch (e) {
      _syncStatus = 'Ошибка соединения';
      debugPrint('Sync error: $e');
    } finally {
      _isSyncing = false;
      _syncProgress = 1.0;
      notifyListeners();
      
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isDisposed && !_isSyncing) {
          _syncProgress = 0;
          _syncStatus = '';
          notifyListeners();
        }
      });
    }
  }

  Future<void> _pushUnsyncedData() async {
    debugPrint('HealthSync: _pushUnsyncedData called');
    await _pushCategoryRecords(_weightRecords, '/api/v1/health/weight', 'weight_records');
    await _pushCategoryRecords(_sleepRecords, '/api/v1/health/sleep', 'sleep_records');
    await _pushCategoryRecords(_waterRecords, '/api/v1/health/water', 'water_records');
    await _pushCategoryRecords(_stepsRecords, '/api/v1/health/steps', 'steps_records');
    // HR сна и покоя уже в sleep_records (resting_heart_rate/avg_heart_rate), отдельно не пушим
  }

  Future<void> _pushCategoryRecords(List<dynamic> records, String endpoint, String tableName) async {
    final unsynced = records.where((dynamic r) => (r.isSynced as bool) == false).toList();
    debugPrint('HealthSync: Pushing ${unsynced.length} unsynced records to $endpoint');
    for (final record in unsynced) {
      try {
        final body = record.toJson() as Map<String, dynamic>?;
        debugPrint('HealthSync: POST $endpoint body=$body');
        final res = await _apiClient.post(endpoint, body: body);
        debugPrint('HealthSync: $endpoint responded ${res.statusCode} ${res.body.length < 200 ? res.body : res.body.substring(0, 200)}');
        if (res.statusCode == 200 || res.statusCode == 201) {
          final dateStr = (record.date as DateTime).toIso8601String().split('T')[0];
          await _repository.updateHealthSyncStatusByDate(tableName, dateStr, true);
          _syncedThisSession.add("${tableName}_$dateStr");
          continue;
        }
        debugPrint('HealthSync: API failed ${res.statusCode}, trying direct POST...');
      } catch (e) {
        debugPrint('HealthSync: Push FAILED for $tableName via API: $e');
        debugPrint('HealthSync: Trying direct POST fallback...');
      }
      // Fallback: direct JSON POST with ZapfitAuthManager headers
      try {
        await _directPost(endpoint, record.toJson() as Map<String, dynamic>?, tableName, record);
      } catch (e2) {
        debugPrint('HealthSync: Direct POST also FAILED for $tableName: $e2');
      }
    }
  }

  Future<void> _directPost(String endpoint, Map<String, dynamic>? body, String tableName, dynamic record) async {
    final storage = SecureStorageService();
    final serverUrl = await storage.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) throw Exception('Server URL not configured');
    
    final authManager = ZapfitAuthManager(baseUrl: serverUrl);
    final authHeaders = await authManager.getValidAuthHeaders();
    
    final url = UrlUtils.buildUrl(serverUrl, endpoint);
    final headers = {
      'Content-Type': 'application/json',
      'X-Client-Type': 'mobile',
      ...authHeaders,
    };
    
    final bodyStr = body != null ? json.encode(body) : null;
    final response = await http.post(url, headers: headers, body: bodyStr).timeout(const Duration(seconds: 30));
    
    debugPrint('HealthSync: Direct POST $endpoint → ${response.statusCode} ${response.body.length < 200 ? response.body : response.body.substring(0, 200)}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final dateStr = (record.date as DateTime).toIso8601String().split('T')[0];
      await _repository.updateHealthSyncStatusByDate(tableName, dateStr, true);
      _syncedThisSession.add("${tableName}_$dateStr");
    }
  }

  Future<void> _syncCategoryGeneric({
    required String endpoint, 
    required String label, 
    required String tableName,
    required double startP, 
    required double endP,
  }) async {
    try {
      final res = await _apiClient.get(endpoint);
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        final serverRecords = ((decoded is Map) ? ((decoded['records'] as List<dynamic>?) ?? <dynamic>[]) : (decoded as List<dynamic>));
        
        for (final item in serverRecords) {
          final map = item as Map<String, dynamic>;
          final dateStr = (map['date'] as String).split('T')[0];
          if (_syncedThisSession.contains("${tableName}_$dateStr")) continue;
          await _saveServerRecord(tableName, map);
        }
      }
    } catch (e) { 
      debugPrint('Pull $label failed: $e'); 
    }
    _syncProgress = endP;
    notifyListeners();
  }

  Future<void> _saveServerRecord(String table, Map<String, dynamic> map) async {
    switch (table) {
      case 'weight_records': await _repository.upsertWeightRecord(WeightRecord.fromJson(map).copyWith(isSynced: true)); break;
      case 'sleep_records': await _repository.upsertSleepRecord(SleepRecord.fromJson(map).copyWith(isSynced: true)); break;
      case 'water_records': await _repository.upsertWaterRecord(WaterRecord.fromJson(map).copyWith(isSynced: true)); break;
      case 'steps_records': await _repository.upsertStepsRecord(StepsRecord.fromJson(map).copyWith(isSynced: true)); break;
    }
  }

  void _updateWidgets() {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      int todaySteps = 0;
      double todayDistance = 0;
      double todayWater = 0;
      for (final r in _stepsRecords) {
        if (r.date.toIso8601String().startsWith(todayStr)) {
          todaySteps += r.steps;
          todayDistance += r.distanceMeters ?? r.estimatedDistanceMeters;
        }
      }
      for (final r in _waterRecords) {
        if (r.date.toIso8601String().startsWith(todayStr)) {
          todayWater += r.amountMl;
        }
      }
      debugPrint('Widget: updating steps=$todaySteps water=$todayWater distance=$todayDistance');
      WidgetsService.instance.updateSummaryWidget(
        steps: todaySteps,
        water: todayWater,
        distance: todayDistance,
      );

      // Update sleep widget with latest sleep record
      if (_sleepRecords.isNotEmpty) {
        final latest = _sleepRecords.first;
        final start = latest.sleepStartTime;
        final end = latest.sleepEndTime;
        final range = (start != null && end != null)
            ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}–${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'
            : '';
        // Recompute score if not persisted (mirrors in-app Health tab logic)
        int score = latest.sleepScoreOverall ?? 0;
        if (score == 0 && latest.totalSleepSeconds > 0) {
          score = SleepScoreCalculator.calculate(
            totalSleepSeconds: latest.totalSleepSeconds,
            deepSleepSeconds: latest.deepSleepSeconds,
            lightSleepSeconds: latest.lightSleepSeconds,
            remSleepSeconds: latest.remSleepSeconds,
            awakeSleepSeconds: latest.awakeSleepSeconds,
            restHr: latest.restHeartRate?.toDouble(),
            age: AppSettingsController.instance.userAge,
          ).score;
        }
        WidgetsService.instance.updateSleepWidget(
          totalSeconds: latest.totalSleepSeconds,
          deepSeconds: latest.deepSleepSeconds,
          lightSeconds: latest.lightSleepSeconds,
          remSeconds: latest.remSleepSeconds,
          score: score,
          sleepRange: range,
        );
      }

      // Update HR widget
      int currentHr = 0;
      int restingHr = 0;
      if (_heartRateRecords.isNotEmpty) {
        currentHr = _heartRateRecords.first.bpm;
      }
      if (_sleepRecords.isNotEmpty && _sleepRecords.first.restHeartRate != null) {
        restingHr = _sleepRecords.first.restHeartRate!;
      }
      WidgetsService.instance.updateHrWidget(
        currentHr: currentHr,
        restingHr: restingHr,
        maxHr: AppSettingsController.instance.userMaxHeartRate,
      );
    } catch (e) {
      debugPrint('Widget update error: $e');
    }
  }
}
