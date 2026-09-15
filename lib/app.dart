import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:zapfit/core/theme/app_theme.dart';
import 'package:zapfit/shared/widgets/startup_splash.dart';
import 'package:zapfit/shared/widgets/app_bottom_nav.dart';
import 'package:zapfit/features/auth/login_screen.dart';
import 'package:zapfit/features/onboarding/onboarding_screen.dart';
import 'package:zapfit/features/onboarding/mode_selection_screen.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/services/auth_service.dart';
import 'package:zapfit/core/services/user_service.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/l10n/app_localizations.dart';
import 'package:zapfit/core/utils/platform_utils.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/shared/widgets/gradient_background.dart';
import 'package:zapfit/core/services/voice_coach_service.dart';
import 'package:zapfit/core/services/auto_sync_service.dart';
import 'package:zapfit/core/services/local_notification_service.dart';
import 'package:zapfit/core/services/background_tracking_service.dart';
import 'package:zapfit/core/services/widgets_service.dart';
import 'package:zapfit/core/services/connectivity_service.dart';
import 'package:zapfit/core/services/bluetooth_sensor_service.dart';
import 'package:zapfit/core/services/notification_service.dart';
import 'package:zapfit/core/services/websocket_service.dart';
import 'package:zapfit/core/services/gear_service.dart';
import 'package:zapfit/core/models/gear_model.dart';
import 'package:zapfit/core/services/activity_tracking_service.dart';
import 'package:flutter/foundation.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _storage = SecureStorageService();
  final _settings = AppSettingsController.instance;
  bool _isInitializing = true;
  bool _isAuthenticated = false;
  bool _autoLoginAttempted = false;
  bool _autoLoginSucceeded = false;

  // Состояния навигации
  bool _showOnboarding = false;
  bool _showModeSelection = false;
  AppMode? _appMode;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final settingsLoad = _settings.load();
    unawaited(_initBackgroundServices());

    try {
      await settingsLoad;
    } catch (_) {}

    // Проверяем first launch + onboarding
    final shouldShowOnboarding = await OnboardingScreen.shouldShow();
    final mode = await ModeSelectionScreen.getMode();

    if (shouldShowOnboarding) {
      if (mounted) {
        setState(() {
          _showOnboarding = true;
          _isInitializing = false;
        });
      }
      return;
    }

    _appMode = mode;

    // Регистрируем callback для onboarding из настроек
    _settings.onShowOnboarding = showOnboarding;

    // Если локальный режим — пропускаем логин
    if (mode == AppMode.local) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isInitializing = false;
        });
      }
      return;
    }

    // Серверный режим — проверяем авторизацию
    bool isAuth = false;
    try {
      isAuth = await _storage.isAuthenticated();
    } catch (e) {
      debugPrint('isAuthenticated failed: $e');
    }

    if (isAuth) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isInitializing = false;
        });
      }
      unawaited(_tryAutoLogin());
    } else {
      final savedUrl = await _storage.getServerUrl();
      final savedUser = await _storage.getUsername();
      if (savedUrl != null && savedUrl.isNotEmpty && savedUser != null && savedUser.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _isInitializing = false;
          });
        }
        _tryAutoLogin();
      } else {
        if (mounted) {
          setState(() {
            _isAuthenticated = false;
            _isInitializing = false;
          });
        }
      }
    }
  }

  /// [comment removed - encoding corrupted]
  /// [comment removed - encoding corrupted]
  /// [comment removed - encoding corrupted]
  Future<void> _tryAutoLogin() async {
    if (_autoLoginAttempted) return;
    _autoLoginAttempted = true;
    try {
      final auth = serviceLocator<AuthService>();
      final ok = await auth.refreshToken();
      if (mounted) {
        setState(() {
          _autoLoginSucceeded = ok;
        });
        if (ok) {
          // Подгружаем профиль после успешного входа
          try {
            final userService = serviceLocator<UserService>();
            await userService.fetchProfile(force: true);
          } catch (_) {}
          // Инициализируем WebSocket и уведомления
          _initNotificationServices();
          // Проверяем износ снаряжения
          unawaited(_checkGearWearNotifications());
        } else {
          final savedUrl = await _storage.getServerUrl();
          final savedUser = await _storage.getUsername();
          if (savedUrl == null || savedUrl.isEmpty || savedUser == null || savedUser.isEmpty) {
            setState(() {
              _isAuthenticated = false;
            });
          } else {
            _showAutoLoginHint();
          }
        }
      }
    } catch (e) {
      debugPrint('Auto login attempt failed: $e');
      final savedUrl = await _storage.getServerUrl();
      final savedUser = await _storage.getUsername();
      if (savedUrl == null || savedUrl.isEmpty || savedUser == null || savedUser.isEmpty) {
        if (mounted) {
          setState(() {
            _autoLoginSucceeded = false;
            _isAuthenticated = false;
          });
        }
      }
    }
  }

  void _initNotificationServices() {
    try {
      final wsService = serviceLocator<WebSocketService>();
      final notificationService = serviceLocator<NotificationService>();
      notificationService.init(wsService: wsService);
      wsService.connect();
    } catch (e) {
      debugPrint('Notification services init failed: $e');
    }
  }

  void _showAutoLoginHint() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Сессия истекла. Войдите ещё раз — поля заполнены автоматически.'),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  Future<void> _initBackgroundServices() async {
    try {
      await Future.wait([
        VoiceCoachService.instance.init().catchError((e) {
          debugPrint('VoiceCoach init failed: $e');
        }),
        LocalNotificationService.instance.init().catchError((e) {
          debugPrint('LocalNotification init failed: $e');
        }),
        BackgroundTrackingService.instance.init().catchError((e) {
          debugPrint('BackgroundTracking init failed: $e');
        }),
        WidgetsService.instance.init().catchError((e) {
          debugPrint('WidgetsService init failed: $e');
        }),
        ConnectivityService.instance.init().catchError((e) {
          debugPrint('ConnectivityService init failed: $e');
        }),
      ]);
      AutoSyncService.instance.init();
      // Восстановление незавершённой тренировки после убийства процесса (переключение/блокировка)
      try {
        await ActivityTrackingService.instance.tryRestoreOngoingActivity();
      } catch (e) {
        debugPrint('Restore ongoing activity failed: $e');
      }

      // Автоподключение BLE-датчиков
      try {
        final ble = serviceLocator<BluetoothSensorService>();
        await ble.init();
        await ble.reconnectAllSaved();
      } catch (e) {
        debugPrint('BLE auto-reconnect failed: $e');
      }
    } catch (e) {
      debugPrint('Background services init: $e');
    }
  }

  void _onLoginSuccess() {
    setState(() {
      _isAuthenticated = true;
      _autoLoginSucceeded = true;
    });
  }

  void _onLogout() async {
    try {
      final wsService = serviceLocator<WebSocketService>();
      await wsService.disconnect();
    } catch (_) {}
    try {
      final userService = serviceLocator<UserService>();
      await userService.clearCache();
    } catch (_) {}
    setState(() {
      _isAuthenticated = false;
      _autoLoginSucceeded = false;
    });
  }

  void _showModeSelectionScreen() {
    setState(() => _showModeSelection = true);
  }

  void _onModeSelected(AppMode mode) {
    setState(() {
      _showModeSelection = false;
      _appMode = mode;
    });
    if (mode == AppMode.local) {
      setState(() => _isAuthenticated = true);
    } else {
      // Серверный режим — показываем логин
      setState(() => _isAuthenticated = false);
    }
  }

  /// Вызов onboarding из настроек
  void showOnboarding() {
    setState(() => _showOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      child: const SizedBox.shrink(),
      builder: (context, child) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            ColorScheme lightScheme;
            ColorScheme darkScheme;

            if (lightDynamic != null && darkDynamic != null && _settings.dynamicColorEnabled) {
              lightScheme = lightDynamic;
              darkScheme = darkDynamic;
            } else {
              lightScheme = ColorScheme.fromSeed(
                seedColor: _settings.accentColor,
                brightness: Brightness.light,
              );
              darkScheme = ColorScheme.fromSeed(
                seedColor: _settings.accentColor,
                brightness: Brightness.dark,
              );
            }

            final bool useGradient = _settings.gradientEnabled && !_settings.dynamicColorEnabled;

            return MaterialApp(
              title: 'ZAPFIT',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: lightScheme,
                scaffoldBackgroundColor: useGradient ? Colors.transparent : (_settings.dynamicColorEnabled ? null : _settings.backgroundColor),
                appBarTheme: AppBarTheme(
                  centerTitle: true,
                  backgroundColor: useGradient ? Colors.transparent : null,
                  elevation: 0,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: darkScheme,
                scaffoldBackgroundColor: useGradient ? Colors.transparent : (_settings.dynamicColorEnabled ? null : (_settings.backgroundColor == Colors.white ? null : _settings.backgroundColor)),
                appBarTheme: AppBarTheme(
                  centerTitle: true,
                  backgroundColor: useGradient ? Colors.transparent : null,
                  elevation: 0,
                ),
              ),
              themeMode: _settings.themeMode,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: _settings.locale,
              builder: (context, child) {
                return GradientBackground(child: child!);
              },
              home: _isInitializing
                  ? const StartupSplash()
                  : _showOnboarding
                      ? OnboardingScreen(
                          onComplete: () async {
                            setState(() => _showOnboarding = false);
                            // Если режим уже выбран внутри визарда (новая логика) — сразу применяем
                            final prefs = await SharedPreferences.getInstance();
                            final modeStr = prefs.getString('app_mode');
                            if (modeStr != null) {
                              final mode = modeStr == 'server' ? AppMode.server : AppMode.local;
                              _onModeSelected(mode);
                            } else {
                              _showModeSelectionScreen();
                            }
                          },
                        )
                      : _showModeSelection
                          ? ModeSelectionScreen(
                              onModeSelected: _onModeSelected,
                            )
                          : (_isAuthenticated
                              ? AppBottomNav(onLogout: _onLogout)
                              : LoginScreen(onLoginSuccess: _onLoginSuccess)),
            );
          },
        );
      },
    );
  }

  Future<void> _checkGearWearNotifications() async {
    try {
      final gearService = serviceLocator<GearService>();
      await gearService.fetchGears();
      final gears = gearService.gears;
      final warnings = <String>[];

      for (final gear in gears) {
        final components = await gearService.fetchComponents(gear.id);
        for (final c in components) {
          if (!c.active || c.expectedKms == null || c.expectedKms == 0) continue;
          final pct = c.wearPercentage;
          if (c.isOverdue || pct >= 0.9) {
            final typeLabel = gearComponentTypeLabels[c.type] ?? c.type;
            final kmLeft = ((c.expectedKms! - c.currentDistance) / 1000).round();
            if (c.isOverdue) {
              warnings.add('${gear.nickname}: $typeLabel изношен (replace now)');
            } else {
              warnings.add('${gear.nickname}: $typeLabel — осталось ~$kmLeft км');
            }
          }
        }
      }

      if (warnings.isNotEmpty) {
        final notifService = LocalNotificationService.instance;
        final title = warnings.length == 1 ? 'Износ снаряжения' : 'Износ снаряжения (${warnings.length})';
        final body = warnings.take(3).join('\n');
        await notifService.showGearWearWarning(title, body);
      }
    } catch (e) {
      debugPrint('Gear wear check failed: $e');
    }
  }
}
