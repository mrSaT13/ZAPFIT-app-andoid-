import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:zapfit/features/feed/feed_screen.dart';
import 'package:zapfit/features/activities/activity_hub_screen.dart';
import 'package:zapfit/features/settings/settings_screen.dart';
import 'package:zapfit/features/health/health_screen.dart';
import 'package:zapfit/core/utils/platform_utils.dart';
import 'package:zapfit/core/constants/ui_constants.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/secure_storage_service.dart';
import 'package:zapfit/core/services/auth_service.dart';
import 'package:zapfit/core/di/service_locator.dart';

class AppBottomNav extends StatefulWidget {
  const AppBottomNav({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  int _currentIndex = 0;
  bool _isOffline = false;
  bool _autoLoginFailed = false;
  Timer? _reconnectTimer;

  List<Widget> get _screens => [
    const FeedScreen(),
    const ActivityHubScreen(),
    const HealthScreen(),
    SettingsScreen(onLogout: widget.onLogout),
  ];

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _startReconnectWatch();
  }

  void _startReconnectWatch() {
    _reconnectTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!_isOffline) return;
      try {
        final apiClient = serviceLocator<ApiClient>();
        final response = await apiClient.get('/api/v1/health');
        if (response.statusCode == 200 && mounted) {
          setState(() {
            _isOffline = false;
            _autoLoginFailed = false;
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final apiClient = serviceLocator<ApiClient>();
      final response = await apiClient.get('/api/v1/health');
      if (response.statusCode != 200) {
        setState(() => _isOffline = true);
      }
    } catch (_) {
      setState(() => _isOffline = true);
    }
    if (_isOffline) {
      final storage = SecureStorageService();
      final token = await storage.getAccessToken();
      if (token == null || token.isEmpty) {
        final username = await storage.getUsername();
        final password = await storage.getPassword();
        if (username == null || password == null) {
          setState(() => _autoLoginFailed = true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isApplePlatform) {
      return CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          height: UIConstants.tabBarHeight,
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: UIConstants.paddingSmall),
                child: Icon(CupertinoIcons.news),
              ),
              label: 'Лента',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: UIConstants.paddingSmall),
                child: Icon(CupertinoIcons.play_circle),
              ),
              label: 'Активность',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: UIConstants.paddingSmall),
                child: Icon(CupertinoIcons.heart),
              ),
              label: 'Здоровье',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: UIConstants.paddingSmall),
                child: Icon(CupertinoIcons.settings),
              ),
              label: 'Настройки',
            ),
          ],
        ),
        tabBuilder: (context, index) {
          return CupertinoTabView(builder: (context) => _screens[index]);
        },
      );
    }

    return Scaffold(
      body: Column(
        children: [
          if (_isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.orange.shade100,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _autoLoginFailed
                            ? 'Нет подключения к серверу. Работа в офлайн-режиме.'
                            : 'Работа в офлайн-режиме',
                        style: const TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            activeIcon: Icon(Icons.article),
            label: 'Лента',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run_outlined),
            activeIcon: Icon(Icons.directions_run),
            label: 'Активность',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Здоровье',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}
