import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/services/health_connect_service.dart';
import 'package:zapfit/core/services/bluetooth_sensor_service.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/features/health/widgets/sync_status_bar.dart';
import 'package:zapfit/features/health/widgets/health_connect_import_button.dart';
import 'package:zapfit/features/health/widgets/realtime_hr_widget.dart';
import 'package:zapfit/features/health/tabs/dashboard_tab.dart';
import 'package:zapfit/features/health/tabs/weight_tab.dart';
import 'package:zapfit/features/health/tabs/sleep_tab.dart';
import 'package:zapfit/features/health/tabs/water_tab.dart';
import 'package:zapfit/features/health/tabs/steps_tab.dart';
import 'package:zapfit/features/health/tabs/heart_rate_tab.dart';
import 'package:zapfit/features/devices/devices_screen.dart';
import 'package:zapfit/l10n/app_localizations.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final HealthService _healthService = serviceLocator<HealthService>();
  bool _hcPermsGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 6, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _healthService.loadLocalData();
      } catch (e) {
        debugPrint('HealthService: loadLocalData error: $e');
      }

      await _refreshPermissions();

      try {
        _healthService.syncAll();
      } catch (e) {
        debugPrint('HealthService: syncAll error: $e');
      }
    });
  }

  void _switchTab(int index) {
    _tabController.animateTo(index);
  }

  /// Re-checks Health Connect permission (forced) and triggers import when granted.
  /// Called on init and whenever the app resumes (e.g. returning from
  /// Health Connect settings after granting access).
  Future<void> _refreshPermissions() async {
    try {
      final hc = HealthConnectService.instance;
      final ok = await hc.checkPermissions(force: true);
      if (mounted) setState(() => _hcPermsGranted = ok);
      if (ok) {
        await _healthService.autoImportFromHealthConnect(daysBack: 30, force: true);
      }
    } catch (e) {
      debugPrint('HealthConnect: re-check error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider.value(
      value: _healthService,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.healthTab),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DevicesScreen()),
                );
              },
              icon: const Icon(Icons.bluetooth),
              tooltip: 'Устройства',
            ),
            HealthConnectImportButton(healthService: _healthService),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: false,
            indicatorSize: TabBarIndicatorSize.label,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            tabs: [
              Tab(text: l10n.healthSummary, icon: Icon(Icons.dashboard_outlined, size: 18)),
              Tab(text: l10n.healthWeight, icon: Icon(Icons.monitor_weight_outlined, size: 18)),
              Tab(text: l10n.healthSleep, icon: Icon(Icons.bedtime_outlined, size: 18)),
              Tab(text: l10n.healthWater, icon: Icon(Icons.water_drop_outlined, size: 18)),
              Tab(text: l10n.healthSteps, icon: Icon(Icons.directions_walk, size: 18)),
              Tab(text: l10n.healthHeartRate, icon: Icon(Icons.favorite, size: 18)),
            ],
          ),
        ),
        body: Column(
          children: [
            const HealthSyncStatusBar(),
            // HC permission warning banner
            if (!_hcPermsGranted)
              MaterialBanner(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.health_and_safety, color: Colors.orange),
                content: const Text(
                  'Health Connect: нет разрешений. Откройте Настройки → Health Connect → ZAPFIT и выдайте доступ на чтение.',
                  style: TextStyle(fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      final hc = HealthConnectService.instance;
                      final ok = await hc.checkPermissions(force: true);
                      if (ok) {
                        setState(() => _hcPermsGranted = true);
                        await _healthService.autoImportFromHealthConnect(daysBack: 30, force: true);
                      }
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            // Real-time HR banner when BLE device connected
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  HealthDashboardTab(onTabRequested: _switchTab),
                  const WeightTab(),
                  const SleepTab(),
                  const WaterTab(),
                  const StepsTab(),
                  const HeartRateTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
