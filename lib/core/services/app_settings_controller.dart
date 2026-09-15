import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zapfit/core/utils/url_utils.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';

// [comment removed - encoding corrupted]
enum MapStyle { normal, topographic }

// [comment removed - encoding corrupted]
// [comment removed - encoding corrupted]
enum MapTheme { auto, light, dark }

// [comment removed - encoding corrupted]
// [comment removed - encoding corrupted]
// [comment removed - encoding corrupted]
// [comment removed - encoding corrupted]
// [comment removed - encoding corrupted]
enum MapDynamicBehavior { off, follow, followWithHeading }

enum MapProvider { osm, tomapo, cartoDark, esriSatellite }

class AppSettingsController extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _accentColorKey = 'accent_color';
  static const String _backgroundColorKey = 'background_color';
  static const String _dynamicColorKey = 'dynamic_color_enabled';
  static const String _gpsAccuracyKey = 'gps_accuracy';
  static const String _gpsDistanceFilterKey = 'gps_distance_filter';
  static const String _gpsUpdateIntervalKey = 'gps_update_interval_seconds';
  static const String _uploadEndpointKey = 'activity_upload_endpoint';
  static const String _apiPasswordKey = 'activity_upload_api_password';
  static const String _apiKeyKey = 'activity_upload_api_key';
  static const String _uploadFormatKey = 'upload_format';
  static const String _mapCacheFolderKey = 'map_cache_folder';
  static const String _localeCodeKey = 'locale_code';
  static const String _gradientEnabledKey = 'theme_gradient_enabled';
  static const String _gradientAccentKey = 'theme_gradient_accent';
  static const String _gradientDirectionKey = 'theme_gradient_direction';
  
  static const String _mapStyleKey = 'map_style';
  static const String _mapThemeKey = 'map_theme';
  static const String _voiceCoachEnabledKey = 'voice_coach_enabled';
  static const String _voiceCoachGenderKey = 'voice_coach_gender';
  static const String _voiceCoachSpeechRateKey = 'voice_coach_speech_rate';
  static const String _voiceCoachVolumeKey = 'voice_coach_volume';
  static const String _voiceCoachAnnounceKmKey = 'voice_coach_announce_km';
  static const String _voiceCoachKmIntervalKey = 'voice_coach_km_interval';
  static const String _voiceCoachAnnouncePaceKey = 'voice_coach_announce_pace';
  static const String _voiceCoachAnnounceCountdownKey = 'voice_coach_announce_countdown';
  static const String _voiceCoachAnnounceMilestonesKey = 'voice_coach_announce_milestones';
  static const String _voiceCoachMilestoneIntervalKey = 'voice_coach_milestone_interval_km';
  static const String _voiceCoachAnnounceFinishKey = 'voice_coach_announce_finish';
  static const String _voiceCoachHrAlertEnabledKey = 'voice_coach_hr_alert_enabled';
  static const String _voiceCoachHrCooldownKey = 'voice_coach_hr_cooldown_seconds';
  static const String _voiceCoachModelKey = 'voice_coach_model';
  static const String _mapDynamicBehaviorKey = 'map_dynamic_behavior';
  static const String _mapProviderKey = 'map_provider';

  // Ollama Cloud AI keys
  static const String _ollamaEnabledKey = 'ollama_enabled';
  static const String _ollamaBaseUrlKey = 'ollama_base_url';
  static const String _ollamaModelKey = 'ollama_model';
  static const String _ollamaPromptTemplateKey = 'ollama_prompt_template';
  static const String _ollamaApiKeySecureKey = 'ollama_api_key';

  // Auto-sync keys
  static const String _autoSyncEnabledKey = 'auto_sync_enabled';
  static const String _autoSyncIntervalKey = 'auto_sync_interval_minutes';

  // Auto-pause keys
  static const String _autoPauseEnabledKey = 'auto_pause_enabled';
  static const String _autoPauseSpeedThresholdKey = 'auto_pause_speed_threshold';
  static const String _autoPauseDelayKey = 'auto_pause_delay_seconds';

  // Notification polling keys
  static const String _notifPollingEnabledKey = 'notif_polling_enabled';
  static const String _notifPollingIntervalKey = 'notif_polling_interval_minutes';

  // Step counter keys
  static const String _stepsAutoSyncKey = 'steps_auto_sync_enabled';
  static const String _stepsSyncHourKey = 'steps_sync_hour';
  static const String _stepsLastSyncDateKey = 'steps_last_sync_date';
  static const String _stepsHealthGrantedKey = 'steps_health_permissions_granted';
  static const String _stepsHealthSourceKey = 'steps_health_source'; // 'health_connect' | 'pedometer'

  // Weight reminder keys
  static const String _weightReminderEnabledKey = 'weight_reminder_enabled';
  static const String _weightReminderHourKey = 'weight_reminder_hour';
  static const String _weightReminderMinuteKey = 'weight_reminder_minute';

  // Folder auto-import keys
  static const String _folderAutoImportEnabledKey = 'folder_auto_import_enabled';
  static const String _folderAutoImportPathKey = 'folder_auto_import_path';

  // Profile keys
  static const String _userHeightKey = 'user_height';
  static const String _userWeightKey = 'user_weight';
  static const String _userMaxHeartRateKey = 'user_max_hr';
  static const String _userGenderKey = 'user_gender';
  static const String _userBirthDateKey = 'user_birth_date';
  static const String _userCityKey = 'user_city';
  static const String _userUnitsKey = 'user_units';
  static const String _userCurrencyKey = 'user_currency';
  static const String _userRestingHrKey = 'user_resting_hr';
  static const String _userFtpKey = 'user_ftp';
  static const String _userVo2maxKey = 'user_vo2max';

  // Additional body / health data for ZAPFIT metrics
  static const String _userHrvRmssdKey = 'user_hrv_rmssd';
  static const String _userWaistCmKey = 'user_waist_cm';
  static const String _userHipCmKey = 'user_hip_cm';
  static const String _userNeckCmKey = 'user_neck_cm';
  static const String _userSystolicKey = 'user_systolic';
  static const String _userDiastolicKey = 'user_diastolic';

  // ZAPFIT mode key
  static const String _zapfitModeKey = 'zapfit_mode';

  AppSettingsController._();

  static final AppSettingsController instance = AppSettingsController._();

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = Colors.blue;
  Color _backgroundColor = Colors.white;
  bool _dynamicColorEnabled = true;
  bool _gradientEnabled = false;
  Color? _gradientAccent;
  String _gradientDirection = 'linear'; // linear | radial
  String _gpsAccuracy = 'high';
  int _gpsDistanceFilter = 3;
  int _gpsUpdateIntervalSeconds = 1;
  String _uploadEndpoint = '/api/v1/activities/create/upload';
  String _apiPassword = '';
  String _apiKey = '';
  String _uploadFormat = 'gpx';
  String _mapCacheFolder = 'tiles';
  String _localeCode = 'ru';
  
  MapStyle _mapStyle = MapStyle.normal;
  MapTheme _mapTheme = MapTheme.auto;
  bool _voiceCoachEnabled = true;
  String _voiceCoachGender = 'female';
  double _voiceCoachSpeechRate = 0.5;
  double _voiceCoachVolume = 1.0;
  bool _voiceCoachAnnounceKm = true;
  int _voiceCoachKmInterval = 1;
  bool _voiceCoachAnnouncePace = false;
  bool _voiceCoachAnnounceCountdown = true;
  bool _voiceCoachAnnounceMilestones = true;
  int _voiceCoachMilestoneInterval = 5; // каждые N км поздравление
  bool _voiceCoachAnnounceFinish = true; // поздравление в конце
  bool _voiceCoachHrAlertEnabled = true; // предупреждение о превышении пульса
  int _voiceCoachHrCooldownSeconds = 60; // не чаще раза в N сек
  String? _voiceCoachModel;
  MapDynamicBehavior _mapDynamicBehavior = MapDynamicBehavior.follow;
  MapProvider _mapProvider = MapProvider.osm;

  // Ollama
  bool _ollamaEnabled = false;
  String _ollamaBaseUrl = 'https://ollama.com';
  String _ollamaModel = 'kimi-k2.6:cloud';
  String _ollamaPromptTemplate =
      'Ты — тренер. Проанализируй тренировку {kind}: дистанция {distance} км, время {duration}, темп {pace}, скорость {speed}, пульс {avgHr}/{maxHr} (покой {restingHr}), набор высоты {ascent} м, TSS {tss}. Профиль: {age} лет, вес {weight} кг, рост {height} см, BMI {bmi}, город {city}, FTP {ftp}, VO2max {vo2max}, HRV {hrv}, талия {waist} см, давление {systolic}/{diastolic}. Сегодня: сон {sleep} (оценка {sleepScore}), вода {water}, шаги {steps}. Дай короткий мотивирующий комментарий (2-3 предложения) без эмодзи, учти восстановление.';

  // Auto-sync
  bool _autoSyncEnabled = false;
  int _autoSyncIntervalMinutes = 30;

  // Notification polling
  bool _notifPollingEnabled = false;
  int _notifPollingIntervalMinutes = 60;

  // Step counter
  bool _stepsAutoSyncEnabled = false;
  int _stepsSyncHour = 23; // 23:00 by default
  String? _stepsLastSyncDate; // YYYY-MM-DD
  bool _stepsHealthPermissionsGranted = false;
  String _stepsHealthSource = 'health_connect';

  // Auto-pause
  bool _autoPauseEnabled = false;
  double _autoPauseSpeedThreshold = 1.0; // km/h — below this = stopped
  int _autoPauseDelaySeconds = 10; // seconds of low speed before auto-pause

  // Weight reminder
  bool _weightReminderEnabled = false;
  int _weightReminderHour = 8;
  int _weightReminderMinute = 0;

  // Folder auto-import
  bool _folderAutoImportEnabled = false;
  String _folderAutoImportPath = '';

  // Profile defaults
  double _userHeight = 175.0;
  double _userWeight = 75.0;
  int _userMaxHeartRate = 185;
  int _userRestingHeartRate = 60;
  double _userFtp = 0;
  double _userVo2max = 0;
  String _userGender = 'male';
  DateTime? _userBirthDate;
  String _userCity = '';
  String _userUnits = 'metric';
  String _userCurrency = 'euro';

  // Additional body / health data (defaults 0 = not set)
  double _userHrvRmssd = 0;
  double _userWaistCm = 0;
  double _userHipCm = 0;
  double _userNeckCm = 0;
  int _userSystolic = 0;
  int _userDiastolic = 0;

  // ZAPFIT mode (false = legacy mode, true = new ZAPFIT API)
  bool _zapfitMode = true;

  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  Color get backgroundColor => _backgroundColor;
  bool get dynamicColorEnabled => _dynamicColorEnabled;
  bool get gradientEnabled => _gradientEnabled;
  Color? get gradientAccent => _gradientAccent;
  String get gradientDirection => _gradientDirection;
  String get gpsAccuracy => _gpsAccuracy;
  int get gpsDistanceFilter => _gpsDistanceFilter;
  int get gpsUpdateIntervalSeconds => _gpsUpdateIntervalSeconds;
  String get uploadEndpoint => _uploadEndpoint;
  String get apiPassword => _apiPassword;
  String get apiKey => _apiKey;
  String get uploadFormat => _uploadFormat;
  String get mapCacheFolder => _mapCacheFolder;
  Locale? get locale => _localeCode.isEmpty ? null : Locale(_localeCode);
  String get localeCode => _localeCode;
  
  MapStyle get mapStyle => _mapStyle;
  MapTheme get mapTheme => _mapTheme;
  bool get voiceCoachEnabled => _voiceCoachEnabled;
  String get voiceCoachGender => _voiceCoachGender;
  double get voiceCoachSpeechRate => _voiceCoachSpeechRate;
  double get voiceCoachVolume => _voiceCoachVolume;
  bool get voiceCoachAnnounceKm => _voiceCoachAnnounceKm;
  int get voiceCoachKmInterval => _voiceCoachKmInterval;
  bool get voiceCoachAnnouncePace => _voiceCoachAnnouncePace;
  bool get voiceCoachAnnounceCountdown => _voiceCoachAnnounceCountdown;
  bool get voiceCoachAnnounceMilestones => _voiceCoachAnnounceMilestones;
  int get voiceCoachMilestoneInterval => _voiceCoachMilestoneInterval;
  bool get voiceCoachAnnounceFinish => _voiceCoachAnnounceFinish;
  bool get voiceCoachHrAlertEnabled => _voiceCoachHrAlertEnabled;
  int get voiceCoachHrCooldownSeconds => _voiceCoachHrCooldownSeconds;
  String? get voiceCoachModel => _voiceCoachModel;
  MapDynamicBehavior get mapDynamicBehavior => _mapDynamicBehavior;
  MapProvider get mapProvider => _mapProvider;

  bool get ollamaEnabled => _ollamaEnabled;
  String get ollamaBaseUrl => _ollamaBaseUrl;
  String get ollamaModel => _ollamaModel;
  String get ollamaPromptTemplate => _ollamaPromptTemplate;
  
  // Profile getters
  double get userHeight => _userHeight;
  double get userWeight => _userWeight;
  int get userMaxHeartRate => _userMaxHeartRate;
  int get userRestingHeartRate => _userRestingHeartRate;
  double get userFtp => _userFtp;
  double get userVo2max => _userVo2max;
  String get userGender => _userGender;
  DateTime? get userBirthDate => _userBirthDate;
  String get userCity => _userCity;
  String get userUnits => _userUnits;
  String get userCurrency => _userCurrency;

  // Currency symbol helper
  static const Map<String, String> currencySymbols = {
    'euro': '€',
    'dollar': '\$',
    'pound': '£',
    'ruble': '₽',
  };
  String get currencySymbol => currencySymbols[_userCurrency] ?? '€';

  double get userHrvRmssd => _userHrvRmssd;
  double get userWaistCm => _userWaistCm;
  double get userHipCm => _userHipCm;
  double get userNeckCm => _userNeckCm;
  int get userSystolic => _userSystolic;
  int get userDiastolic => _userDiastolic;

  // ZAPFIT mode getter
  bool get zapfitMode => _zapfitMode;

  bool get autoSyncEnabled => _autoSyncEnabled;
  int get autoSyncIntervalMinutes => _autoSyncIntervalMinutes;

  // Auto-pause getters
  bool get autoPauseEnabled => _autoPauseEnabled;
  double get autoPauseSpeedThreshold => _autoPauseSpeedThreshold;
  int get autoPauseDelaySeconds => _autoPauseDelaySeconds;

  bool get notifPollingEnabled => _notifPollingEnabled;
  int get notifPollingIntervalMinutes => _notifPollingIntervalMinutes;

  // Step counter getters
  bool get stepsAutoSyncEnabled => _stepsAutoSyncEnabled;
  int get stepsSyncHour => _stepsSyncHour;
  String? get stepsLastSyncDate => _stepsLastSyncDate;
  bool get stepsHealthPermissionsGranted => _stepsHealthPermissionsGranted;
  String get stepsHealthSource => _stepsHealthSource;

  // Weight reminder getters
  bool get weightReminderEnabled => _weightReminderEnabled;
  int get weightReminderHour => _weightReminderHour;
  int get weightReminderMinute => _weightReminderMinute;

  // Folder auto-import getters
  bool get folderAutoImportEnabled => _folderAutoImportEnabled;
  String get folderAutoImportPath => _folderAutoImportPath;

  bool get isLoaded => _loaded;
  SharedPreferences? get rawPrefs => _prefs;

  static const List<Color> accentColors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange, 
    Colors.teal, Colors.purple, Colors.pink, Colors.indigo,
    Colors.amber, Colors.deepOrange, Colors.lightGreen, Colors.cyan
  ];

  static const List<Color> backgroundColors = [
    Colors.white, Color(0xFFF5F5F5), Color(0xFFE0E0E0), 
    Color(0xFF121212), Colors.black, Color(0xFF1A1A1A),
    Color(0xFF0D1117), 
    Color(0xFF1E1E1E), 
  ];

  static const List<Color> gradientColors = [
    Colors.blue, Colors.indigo, Colors.deepPurple, Colors.pink, 
    Colors.red, Colors.orange, Colors.teal, Colors.green,
    Colors.purple, Colors.cyan, Colors.deepOrange, Color(0xFF2196F3)
  ];

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;

    final themeModeRaw = prefs.getString(_themeModeKey) ?? ThemeMode.system.name;
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == themeModeRaw,
      orElse: () => ThemeMode.system,
    );

    final accentColorValue = prefs.getInt(_accentColorKey);
    if (accentColorValue != null) {
      _accentColor = Color(accentColorValue);
    }

    final bgColorValue = prefs.getInt(_backgroundColorKey);
    if (bgColorValue != null) {
      _backgroundColor = Color(bgColorValue);
    }

    _dynamicColorEnabled = prefs.getBool(_dynamicColorKey) ?? true;

    final gradientEnabledRaw = prefs.getBool(_gradientEnabledKey);
    _gradientEnabled = gradientEnabledRaw ?? false;
    final gradientAccentValue = prefs.getInt(_gradientAccentKey);
    if (gradientAccentValue != null) {
      _gradientAccent = Color(gradientAccentValue);
    }
    _gradientDirection = prefs.getString(_gradientDirectionKey) ?? 'linear';

    _gpsAccuracy = prefs.getString(_gpsAccuracyKey) ?? 'high';
    _gpsDistanceFilter = prefs.getInt(_gpsDistanceFilterKey) ?? 3;
    _gpsUpdateIntervalSeconds = prefs.getInt(_gpsUpdateIntervalKey) ?? 1;
    _uploadEndpoint = UrlUtils.normalizeEndpointPath(
      prefs.getString(_uploadEndpointKey) ?? '/api/v1/activities/create/upload',
    );
    _apiPassword = prefs.getString(_apiPasswordKey) ?? '';
    _apiKey = prefs.getString(_apiKeyKey) ?? '';
    _uploadFormat = prefs.getString(_uploadFormatKey) ?? 'gpx';
    _mapCacheFolder = prefs.getString(_mapCacheFolderKey) ?? 'tiles';
    _localeCode = prefs.getString(_localeCodeKey) ?? 'ru';

    final mapStyleRaw = prefs.getString(_mapStyleKey) ?? MapStyle.normal.name;
    _mapStyle = MapStyle.values.firstWhere(
      (s) => s.name == mapStyleRaw,
      orElse: () => MapStyle.normal,
    );

    final mapThemeRaw = prefs.getString(_mapThemeKey) ?? MapTheme.auto.name;
    _mapTheme = MapTheme.values.firstWhere(
      (t) => t.name == mapThemeRaw,
      orElse: () => MapTheme.auto,
    );

    _voiceCoachEnabled = prefs.getBool(_voiceCoachEnabledKey) ?? true;
    _voiceCoachGender = prefs.getString(_voiceCoachGenderKey) ?? 'female';
    _voiceCoachSpeechRate = prefs.getDouble(_voiceCoachSpeechRateKey) ?? 0.5;
    _voiceCoachVolume = prefs.getDouble(_voiceCoachVolumeKey) ?? 1.0;
    _voiceCoachAnnounceKm = prefs.getBool(_voiceCoachAnnounceKmKey) ?? true;
    _voiceCoachKmInterval = prefs.getInt(_voiceCoachKmIntervalKey) ?? 1;
    _voiceCoachAnnouncePace = prefs.getBool(_voiceCoachAnnouncePaceKey) ?? false;
    _voiceCoachAnnounceCountdown = prefs.getBool(_voiceCoachAnnounceCountdownKey) ?? true;
    _voiceCoachAnnounceMilestones = prefs.getBool(_voiceCoachAnnounceMilestonesKey) ?? true;
    _voiceCoachMilestoneInterval = prefs.getInt(_voiceCoachMilestoneIntervalKey) ?? 5;
    _voiceCoachAnnounceFinish = prefs.getBool(_voiceCoachAnnounceFinishKey) ?? true;
    _voiceCoachHrAlertEnabled = prefs.getBool(_voiceCoachHrAlertEnabledKey) ?? true;
    _voiceCoachHrCooldownSeconds = prefs.getInt(_voiceCoachHrCooldownKey) ?? 60;
    _voiceCoachModel = prefs.getString(_voiceCoachModelKey);

    _ollamaEnabled = prefs.getBool(_ollamaEnabledKey) ?? false;
    _ollamaBaseUrl = prefs.getString(_ollamaBaseUrlKey) ?? 'https://ollama.com';
    _ollamaModel = prefs.getString(_ollamaModelKey) ?? 'kimi-k2.6:cloud';
    _ollamaPromptTemplate = prefs.getString(_ollamaPromptTemplateKey) ??
        'Ты — тренер. Проанализируй тренировку {kind}: дистанция {distance} км, время {duration}, темп {pace}, пульс {avgHr}/{maxHr}, набор высоты {ascent} м, TSS {tss}. Дай короткий мотивирующий комментарий (2-3 предложения) без эмодзи.';

    final mapProviderRaw = prefs.getString(_mapProviderKey) ?? MapProvider.osm.name;
    _mapProvider = MapProvider.values.firstWhere(
      (p) => p.name == mapProviderRaw,
      orElse: () => MapProvider.osm,
    );

    final dynRaw = prefs.getString(_mapDynamicBehaviorKey)
        ?? MapDynamicBehavior.off.name;
    _mapDynamicBehavior = MapDynamicBehavior.values.firstWhere(
      (d) => d.name == dynRaw,
      orElse: () => MapDynamicBehavior.off,
    );

    // Load profile
    _userHeight = prefs.getDouble(_userHeightKey) ?? 175.0;
    _userWeight = prefs.getDouble(_userWeightKey) ?? 75.0;
    _userMaxHeartRate = prefs.getInt(_userMaxHeartRateKey) ?? 185;
    _userRestingHeartRate = prefs.getInt(_userRestingHrKey) ?? 60;
    _userFtp = prefs.getDouble(_userFtpKey) ?? 0;
    _userVo2max = prefs.getDouble(_userVo2maxKey) ?? 0;
    _userGender = prefs.getString(_userGenderKey) ?? 'male';
    final birthDateStr = prefs.getString(_userBirthDateKey);
    _userBirthDate = birthDateStr != null ? DateTime.tryParse(birthDateStr) : null;
    _userCity = prefs.getString(_userCityKey) ?? '';
    _userUnits = prefs.getString(_userUnitsKey) ?? 'metric';
    _userCurrency = prefs.getString(_userCurrencyKey) ?? 'euro';

    _userHrvRmssd = prefs.getDouble(_userHrvRmssdKey) ?? 0;
    _userWaistCm = prefs.getDouble(_userWaistCmKey) ?? 0;
    _userHipCm = prefs.getDouble(_userHipCmKey) ?? 0;
    _userNeckCm = prefs.getDouble(_userNeckCmKey) ?? 0;
    _userSystolic = prefs.getInt(_userSystolicKey) ?? 0;
    _userDiastolic = prefs.getInt(_userDiastolicKey) ?? 0;

    // Load ZAPFIT mode (default false = legacy)
    _zapfitMode = prefs.getBool(_zapfitModeKey) ?? true;

    _autoSyncEnabled = prefs.getBool(_autoSyncEnabledKey) ?? false;
    _autoSyncIntervalMinutes = prefs.getInt(_autoSyncIntervalKey) ?? 30;

    // Auto-pause load
    _autoPauseEnabled = prefs.getBool(_autoPauseEnabledKey) ?? false;
    _autoPauseSpeedThreshold = prefs.getDouble(_autoPauseSpeedThresholdKey) ?? 1.0;
    _autoPauseDelaySeconds = prefs.getInt(_autoPauseDelayKey) ?? 10;

    _notifPollingEnabled = prefs.getBool(_notifPollingEnabledKey) ?? false;
    _notifPollingIntervalMinutes = prefs.getInt(_notifPollingIntervalKey) ?? 60;

    // Step counter load
    _stepsAutoSyncEnabled = prefs.getBool(_stepsAutoSyncKey) ?? false;
    _stepsSyncHour = prefs.getInt(_stepsSyncHourKey) ?? 23;
    _stepsLastSyncDate = prefs.getString(_stepsLastSyncDateKey);
    _stepsHealthPermissionsGranted = prefs.getBool(_stepsHealthGrantedKey) ?? false;
    _stepsHealthSource = prefs.getString(_stepsHealthSourceKey) ?? 'health_connect';

    // Weight reminder load
    _weightReminderEnabled = prefs.getBool(_weightReminderEnabledKey) ?? false;
    _weightReminderHour = prefs.getInt(_weightReminderHourKey) ?? 8;
    _weightReminderMinute = prefs.getInt(_weightReminderMinuteKey) ?? 0;

    // Folder auto-import load
    _folderAutoImportEnabled = prefs.getBool(_folderAutoImportEnabledKey) ?? false;
    _folderAutoImportPath = prefs.getString(_folderAutoImportPathKey) ?? '';

    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _ensurePrefs();
    await _prefs!.setString(_themeModeKey, mode.name);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    await _ensurePrefs();
    await _prefs!.setInt(_accentColorKey, color.value);
    notifyListeners();
  }

  Future<void> setBackgroundColor(Color color) async {
    _backgroundColor = color;
    await _ensurePrefs();
    await _prefs!.setInt(_backgroundColorKey, color.value);
    notifyListeners();
  }

  Future<void> setDynamicColorEnabled(bool enabled) async {
    _dynamicColorEnabled = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_dynamicColorKey, enabled);
    notifyListeners();
  }

  Future<void> setGradientEnabled(bool enabled) async {
    _gradientEnabled = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_gradientEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setGradientAccent(Color color) async {
    _gradientAccent = color;
    await _ensurePrefs();
    await _prefs!.setInt(_gradientAccentKey, color.value);
    notifyListeners();
  }

  Future<void> setGradientDirection(String direction) async {
    _gradientDirection = direction;
    await _ensurePrefs();
    await _prefs!.setString(_gradientDirectionKey, direction);
    notifyListeners();
  }

  Future<void> setGpsAccuracy(String accuracy) async {
    _gpsAccuracy = accuracy;
    await _ensurePrefs();
    await _prefs!.setString(_gpsAccuracyKey, accuracy);
    notifyListeners();
  }

  Future<void> setGpsDistanceFilter(int meters) async {
    _gpsDistanceFilter = meters;
    notifyListeners();
    await _prefs!.setInt(_gpsDistanceFilterKey, meters);
  }

  Future<void> setGpsUpdateInterval(int seconds) async {
    _gpsUpdateIntervalSeconds = seconds.clamp(1, 30);
    notifyListeners();
    await _prefs!.setInt(_gpsUpdateIntervalKey, _gpsUpdateIntervalSeconds);
  }

  Future<void> setUploadEndpoint(String endpoint) async {
    _uploadEndpoint = UrlUtils.normalizeEndpointPath(endpoint);
    await _ensurePrefs();
    await _prefs!.setString(_uploadEndpointKey, _uploadEndpoint);
    notifyListeners();
  }

  Future<void> setApiPassword(String password) async {
    _apiPassword = password.trim();
    await _ensurePrefs();
    await _prefs!.setString(_apiPasswordKey, _apiPassword);
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    await _ensurePrefs();
    await _prefs!.setString(_apiKeyKey, _apiKey);
    notifyListeners();
  }

  Future<void> setUploadFormat(String format) async {
    _uploadFormat = format;
    await _ensurePrefs();
    await _prefs!.setString(_uploadFormatKey, format);
    notifyListeners();
  }

  Future<void> setMapCacheFolder(String folder) async {
    _mapCacheFolder = folder;
    await _ensurePrefs();
    await _prefs!.setString(_mapCacheFolderKey, folder);
    notifyListeners();
  }

  Future<void> setLocaleCode(String? localeCode) async {
    _localeCode = localeCode ?? '';
    await _ensurePrefs();
    await _prefs!.setString(_localeCodeKey, _localeCode);
    notifyListeners();
  }

  Future<void> setMapStyle(MapStyle style) async {
    _mapStyle = style;
    await _ensurePrefs();
    await _prefs!.setString(_mapStyleKey, style.name);
    notifyListeners();
  }

  Future<void> setMapTheme(MapTheme theme) async {
    _mapTheme = theme;
    await _ensurePrefs();
    await _prefs!.setString(_mapThemeKey, theme.name);
    notifyListeners();
  }

  Future<void> setVoiceCoachEnabled(bool enabled) async {
    _voiceCoachEnabled = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_voiceCoachEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setVoiceCoachGender(String gender) async {
    _voiceCoachGender = gender;
    await _ensurePrefs();
    await _prefs!.setString(_voiceCoachGenderKey, gender);
    notifyListeners();
  }

  Future<void> setVoiceCoachSpeechRate(double rate) async {
    _voiceCoachSpeechRate = rate;
    await _ensurePrefs();
    await _prefs!.setDouble(_voiceCoachSpeechRateKey, rate);
    notifyListeners();
  }

  Future<void> setVoiceCoachVolume(double volume) async {
    _voiceCoachVolume = volume.clamp(0.0, 1.0);
    await _ensurePrefs();
    await _prefs!.setDouble(_voiceCoachVolumeKey, _voiceCoachVolume);
    notifyListeners();
  }

  Future<void> setVoiceCoachAnnounceKm(bool enabled) async {
    _voiceCoachAnnounceKm = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_voiceCoachAnnounceKmKey, enabled);
    notifyListeners();
  }

  Future<void> setVoiceCoachKmInterval(int interval) async {
    _voiceCoachKmInterval = interval.clamp(1, 10);
    await _ensurePrefs();
    await _prefs!.setInt(_voiceCoachKmIntervalKey, _voiceCoachKmInterval);
    notifyListeners();
  }

  Future<void> setVoiceCoachAnnouncePace(bool enabled) async {
    _voiceCoachAnnouncePace = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_voiceCoachAnnouncePaceKey, enabled);
    notifyListeners();
  }

  Future<void> setVoiceCoachAnnounceCountdown(bool enabled) async {
    _voiceCoachAnnounceCountdown = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_voiceCoachAnnounceCountdownKey, enabled);
    notifyListeners();
  }

  Future<void> setVoiceCoachAnnounceMilestones(bool enabled) async {
    _voiceCoachAnnounceMilestones = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_voiceCoachAnnounceMilestonesKey, enabled);
    notifyListeners();
  }

  Future<void> setVoiceCoachMilestoneInterval(int km) async {
    _voiceCoachMilestoneInterval = km.clamp(1, 50);
    await _ensurePrefs();
    await _prefs!.setInt(_voiceCoachMilestoneIntervalKey, _voiceCoachMilestoneInterval);
    notifyListeners();
  }

  Future<void> setVoiceCoachAnnounceFinish(bool enabled) async {
    _voiceCoachAnnounceFinish = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_voiceCoachAnnounceFinishKey, enabled);
    notifyListeners();
  }

  Future<void> setVoiceCoachHrAlertEnabled(bool enabled) async {
    _voiceCoachHrAlertEnabled = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_voiceCoachHrAlertEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setVoiceCoachModel(String? model) async {
    _voiceCoachModel = model;
    await _ensurePrefs();
    if (model != null) {
      await _prefs!.setString(_voiceCoachModelKey, model);
    } else {
      await _prefs!.remove(_voiceCoachModelKey);
    }
    notifyListeners();
  }

  Future<void> setMapProvider(MapProvider provider) async {
    _mapProvider = provider;
    await _ensurePrefs();
    await _prefs!.setString(_mapProviderKey, provider.name);
    notifyListeners();
  }

  Future<void> setMapDynamicBehavior(MapDynamicBehavior behavior) async {
    _mapDynamicBehavior = behavior;
    await _ensurePrefs();
    await _prefs!.setString(_mapDynamicBehaviorKey, behavior.name);
    notifyListeners();
  }

  // Ollama setters
  Future<void> setOllamaEnabled(bool v) async {
    _ollamaEnabled = v;
    await _ensurePrefs();
    await _prefs!.setBool(_ollamaEnabledKey, v);
    notifyListeners();
  }

  Future<void> setOllamaBaseUrl(String url) async {
    _ollamaBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (_ollamaBaseUrl.isEmpty) _ollamaBaseUrl = 'https://ollama.com';
    await _ensurePrefs();
    await _prefs!.setString(_ollamaBaseUrlKey, _ollamaBaseUrl);
    notifyListeners();
  }

  Future<void> setOllamaModel(String model) async {
    _ollamaModel = model.trim();
    await _ensurePrefs();
    await _prefs!.setString(_ollamaModelKey, _ollamaModel);
    notifyListeners();
  }

  Future<void> setOllamaPromptTemplate(String tpl) async {
    _ollamaPromptTemplate = tpl;
    await _ensurePrefs();
    await _prefs!.setString(_ollamaPromptTemplateKey, tpl);
    notifyListeners();
  }

  // Ollama API key stored in SecureStorage (fallback to prefs for migration)
  Future<String?> getOllamaApiKey() async {
    try {
      final secure = SecureStorageService();
      final v = await secure.getOllamaApiKey();
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      await _ensurePrefs();
      return _prefs!.getString(_ollamaApiKeySecureKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> setOllamaApiKey(String key) async {
    final secure = SecureStorageService();
    try {
      if (key.trim().isEmpty) {
        await secure.deleteOllamaApiKey();
      } else {
        await secure.setOllamaApiKey(key.trim());
      }
    } catch (_) {}
    // also clear legacy prefs
    try {
      await _ensurePrefs();
      if (key.trim().isEmpty) {
        await _prefs!.remove(_ollamaApiKeySecureKey);
      } else {
        await _prefs!.setString(_ollamaApiKeySecureKey, key.trim());
      }
    } catch (_) {}
    notifyListeners();
  }

  // Profile setters
  Future<void> setUserHeight(double height) async {
    _userHeight = height;
    await _ensurePrefs();
    await _prefs!.setDouble(_userHeightKey, height);
    notifyListeners();
  }

  Future<void> setUserWeight(double weight) async {
    _userWeight = weight;
    await _ensurePrefs();
    await _prefs!.setDouble(_userWeightKey, weight);
    notifyListeners();
  }

  Future<void> setUserMaxHeartRate(int hr) async {
    _userMaxHeartRate = hr;
    await _ensurePrefs();
    await _prefs!.setInt(_userMaxHeartRateKey, hr);
    notifyListeners();
  }

  Future<void> setUserRestingHeartRate(int hr) async {
    _userRestingHeartRate = hr;
    await _ensurePrefs();
    await _prefs!.setInt(_userRestingHrKey, hr);
    notifyListeners();
  }

  Future<void> setUserFtp(double ftp) async {
    _userFtp = ftp;
    await _ensurePrefs();
    await _prefs!.setDouble(_userFtpKey, ftp);
    notifyListeners();
  }

  Future<void> setUserVo2max(double vo2max) async {
    _userVo2max = vo2max;
    await _ensurePrefs();
    await _prefs!.setDouble(_userVo2maxKey, vo2max);
    notifyListeners();
  }

  Future<void> setUserGender(String gender) async {
    _userGender = gender;
    await _ensurePrefs();
    await _prefs!.setString(_userGenderKey, gender);
    notifyListeners();
  }

  Future<void> setUserBirthDate(DateTime? date) async {
    _userBirthDate = date;
    await _ensurePrefs();
    if (date == null) {
      await _prefs!.remove(_userBirthDateKey);
    } else {
      await _prefs!.setString(_userBirthDateKey, date.toIso8601String().split('T')[0]);
    }
    notifyListeners();
  }

  int? get userAge {
    if (_userBirthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - _userBirthDate!.year;
    if (now.month < _userBirthDate!.month ||
        (now.month == _userBirthDate!.month && now.day < _userBirthDate!.day)) {
      age--;
    }
    return age;
  }

  Future<void> setUserCity(String city) async {
    _userCity = city;
    await _ensurePrefs();
    await _prefs!.setString(_userCityKey, city);
    notifyListeners();
  }

  Future<void> setUserUnits(String units) async {
    _userUnits = units;
    await _ensurePrefs();
    await _prefs!.setString(_userUnitsKey, units);
    notifyListeners();
  }

  Future<void> setUserCurrency(String currency) async {
    _userCurrency = currency;
    await _ensurePrefs();
    await _prefs!.setString(_userCurrencyKey, currency);
    notifyListeners();
  }

  Future<void> setUserHrvRmssd(double value) async {
    _userHrvRmssd = value;
    await _ensurePrefs();
    await _prefs!.setDouble(_userHrvRmssdKey, value);
    notifyListeners();
  }

  Future<void> setUserWaistCm(double value) async {
    _userWaistCm = value;
    await _ensurePrefs();
    await _prefs!.setDouble(_userWaistCmKey, value);
    notifyListeners();
  }

  Future<void> setUserHipCm(double value) async {
    _userHipCm = value;
    await _ensurePrefs();
    await _prefs!.setDouble(_userHipCmKey, value);
    notifyListeners();
  }

  Future<void> setUserNeckCm(double value) async {
    _userNeckCm = value;
    await _ensurePrefs();
    await _prefs!.setDouble(_userNeckCmKey, value);
    notifyListeners();
  }

  Future<void> setUserSystolic(int value) async {
    _userSystolic = value;
    await _ensurePrefs();
    await _prefs!.setInt(_userSystolicKey, value);
    notifyListeners();
  }

  Future<void> setUserDiastolic(int value) async {
    _userDiastolic = value;
    await _ensurePrefs();
    await _prefs!.setInt(_userDiastolicKey, value);
    notifyListeners();
  }

  // ZAPFIT mode setter
  Future<void> setZapfitMode(bool enabled) async {
    _zapfitMode = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_zapfitModeKey, enabled);
    notifyListeners();
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    _autoSyncEnabled = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_autoSyncEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setAutoSyncIntervalMinutes(int minutes) async {
    _autoSyncIntervalMinutes = minutes;
    await _ensurePrefs();
    await _prefs!.setInt(_autoSyncIntervalKey, minutes);
    notifyListeners();
  }

  Future<void> setAutoPauseEnabled(bool enabled) async {
    _autoPauseEnabled = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_autoPauseEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setAutoPauseSpeedThreshold(double kmh) async {
    _autoPauseSpeedThreshold = kmh;
    await _ensurePrefs();
    await _prefs!.setDouble(_autoPauseSpeedThresholdKey, kmh);
    notifyListeners();
  }

  Future<void> setAutoPauseDelaySeconds(int seconds) async {
    _autoPauseDelaySeconds = seconds;
    await _ensurePrefs();
    await _prefs!.setInt(_autoPauseDelayKey, seconds);
    notifyListeners();
  }

  Future<void> setNotifPollingEnabled(bool enabled) async {
    _notifPollingEnabled = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_notifPollingEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setNotifPollingIntervalMinutes(int minutes) async {
    _notifPollingIntervalMinutes = minutes;
    await _ensurePrefs();
    await _prefs!.setInt(_notifPollingIntervalKey, minutes);
    notifyListeners();
  }

  // Step counter setters
  Future<void> setStepsAutoSyncEnabled(bool enabled) async {
    _stepsAutoSyncEnabled = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_stepsAutoSyncKey, enabled);
    notifyListeners();
  }

  Future<void> setStepsSyncHour(int hour) async {
    _stepsSyncHour = hour.clamp(0, 23);
    await _ensurePrefs();
    await _prefs!.setInt(_stepsSyncHourKey, _stepsSyncHour);
    notifyListeners();
  }

  Future<void> setStepsLastSyncDate(String? date) async {
    _stepsLastSyncDate = date;
    await _ensurePrefs();
    if (date == null) {
      await _prefs!.remove(_stepsLastSyncDateKey);
    } else {
      await _prefs!.setString(_stepsLastSyncDateKey, date);
    }
    notifyListeners();
  }

  Future<void> setStepsHealthPermissionsGranted(bool granted) async {
    _stepsHealthPermissionsGranted = granted;
    await _ensurePrefs();
    await _prefs!.setBool(_stepsHealthGrantedKey, granted);
    notifyListeners();
  }

  Future<void> setStepsHealthSource(String source) async {
    _stepsHealthSource = source;
    await _ensurePrefs();
    await _prefs!.setString(_stepsHealthSourceKey, source);
    notifyListeners();
  }

  // Weight reminder setters
  Future<void> setWeightReminderEnabled(bool enabled) async {
    _weightReminderEnabled = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_weightReminderEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setWeightReminderTime(int hour, int minute) async {
    _weightReminderHour = hour;
    _weightReminderMinute = minute;
    await _ensurePrefs();
    await _prefs!.setInt(_weightReminderHourKey, hour);
    await _prefs!.setInt(_weightReminderMinuteKey, minute);
    notifyListeners();
  }

  // Folder auto-import setters
  Future<void> setFolderAutoImportEnabled(bool enabled) async {
    _folderAutoImportEnabled = enabled;
    await _ensurePrefs();
    await _prefs!.setBool(_folderAutoImportEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setFolderAutoImportPath(String path) async {
    _folderAutoImportPath = path;
    await _ensurePrefs();
    await _prefs!.setString(_folderAutoImportPathKey, path);
    notifyListeners();
  }

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Глобальный callback для запуска onboarding из любого места
  VoidCallback? onShowOnboarding;
}

