import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/features/map/map_screen.dart';
import 'package:zapfit/features/activities/activities_screen.dart';
import 'package:zapfit/features/activities/tabs/gear_tab.dart';
import 'package:zapfit/features/activities/tabs/goals_tab.dart';
import 'package:zapfit/features/activities/widgets/activity_calendar_sheet.dart';
import 'package:zapfit/features/search/search_screen.dart';
import 'package:zapfit/core/services/activity_sync_service.dart';
import 'package:zapfit/core/services/activity_tracking_service.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/gpx_service.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/l10n/app_localizations.dart';

class ActivityHubScreen extends StatefulWidget {
  const ActivityHubScreen({super.key});

  @override
  State<ActivityHubScreen> createState() => _ActivityHubScreenState();
}

class _ActivityHubScreenState extends State<ActivityHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ActivitySyncService _syncService = serviceLocator<ActivitySyncService>();
  final ActivityTrackingService _trackingService = ActivityTrackingService.instance;
  bool _isSyncing = false;
  bool _isRecording = false;
  StreamSubscription<TrackingSnapshot>? _trackingSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _isRecording = _trackingService.currentSnapshot.isRecording;
    _trackingSub = _trackingService.snapshotStream.listen((snap) {
      if (!mounted) return;
      final wasRecording = _isRecording;
      setState(() => _isRecording = snap.isRecording);
      if (!wasRecording && snap.isRecording && _tabController.index != 0) {
        _tabController.animateTo(0);
      }
    });
  }

  @override
  void dispose() {
    _trackingSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);
    try {
      final result = await _syncService.syncAll();

      if (mounted) {
        if (result.error != null) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.error}: ${result.error}'), backgroundColor: Colors.red),
          );
        } else {
          final l10n = AppLocalizations.of(context)!;
          final String msg = result.total > 0
              ? '${l10n.syncAndCache}: +${result.pushed} sent, +${result.pulled} received'
              : l10n.noActivitiesYet;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Critical error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showActivityCalendar() async {
    final repo = LocalActivityRepository.instance;
    final activities = await repo.getActivities();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ActivityCalendarSheet(activities: activities),
    );
  }

  Future<void> _importGpxFile() async {
    try {
      final gpxService = GpxService();
      final importedIds = await gpxService.importMultipleFromPicker();
      if (mounted && importedIds.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Импортировано ${importedIds.length} файл(ов)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка импорта: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activitiesTitle),
        centerTitle: true,
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search, size: 22),
              tooltip: 'Поиск',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.file_upload_outlined, size: 22),
              tooltip: 'Импорт GPX/TCX',
              onPressed: _importGpxFile,
            ),
            IconButton(
              icon: const Icon(Icons.calendar_month, size: 22),
              tooltip: 'Календарь активностей',
              onPressed: _showActivityCalendar,
            ),
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: l10n.settingsUpdated,
              onPressed: _handleSync,
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.label,
          labelPadding: EdgeInsets.zero,
          tabs: [
            Tab(text: l10n.tabRecord, icon: const Icon(Icons.play_circle_outline, size: 20)),
            Tab(text: l10n.tabHistory, icon: const Icon(Icons.history, size: 20)),
            Tab(text: l10n.tabGear, icon: const Icon(Icons.inventory_2_outlined, size: 20)),
            const Tab(text: 'Цели', icon: Icon(Icons.flag_outlined, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isSyncing) const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: _isRecording
                  ? const ClampingScrollPhysics()
                  : const BouncingScrollPhysics(),
              children: [
                const MapScreen(),
                const ActivitiesScreen(hideAppBar: true),
                const GearTab(),
                const GoalsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
