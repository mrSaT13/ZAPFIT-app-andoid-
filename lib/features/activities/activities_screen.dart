import 'dart:async';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/activity_sync_service.dart';
import 'package:zapfit/core/services/gpx_service.dart';
import 'package:zapfit/features/activities/activity_detail_screen.dart';
import 'package:zapfit/features/activities/widgets/activity_calendar_sheet.dart';
import 'package:zapfit/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key, this.hideAppBar = false});
  final bool hideAppBar;

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final LocalActivityRepository _repository = LocalActivityRepository.instance;

  List<ActivityRecord> _allActivities = [];
  List<ActivityRecord> _filteredActivities = [];
  bool _loading = true;
  String _searchQuery = '';
  bool _showSearchBar = false;
  
  ActivityKind? _filterKind;
  UploadStatus? _filterStatus;
  ActivitySource? _filterSource;
  
  StreamSubscription<void>? _changeSubscription;

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _changeSubscription = _repository.activityChanges.listen((_) {
      _loadActivities(showLoading: false);
    });
  }

  @override
  void dispose() {
    _changeSubscription?.cancel();
    super.dispose();
  }

  List<ActivityRecord> _deduplicateForDisplay(List<ActivityRecord> items) {
    final byServerId = <int, ActivityRecord>{};
    final byKey = <String, ActivityRecord>{};
    final result = <ActivityRecord>[];
    for (final a in items) {
      if (a.serverId != null) {
        if (byServerId.containsKey(a.serverId)) {
          final existing = byServerId[a.serverId]!;
          if (existing.uploadStatus == UploadStatus.uploaded && a.uploadStatus != UploadStatus.uploaded) continue;
          if (a.uploadStatus == UploadStatus.uploaded && existing.uploadStatus != UploadStatus.uploaded) { result.remove(existing); result.add(a); byServerId[a.serverId!] = a; }
          continue;
        }
        byServerId[a.serverId!] = a;
        final key = '${a.startedAt.millisecondsSinceEpoch}_${a.kind.name}_${a.distanceMeters.round()}';
        if (byKey.containsKey(key)) { final dup = byKey[key]!; result.remove(dup); }
        byKey[key] = a; result.add(a);
      } else {
        final key = '${a.startedAt.millisecondsSinceEpoch}_${a.kind.name}_${a.distanceMeters.round()}';
        if (byKey.containsKey(key) && byKey[key]!.serverId != null) continue;
        if (byKey.containsKey(key)) continue;
        byKey[key] = a; result.add(a);
      }
    }
    result.sort((a,b) => b.startedAt.compareTo(a.startedAt));
    return result;
  }

  Future<void> _loadActivities({bool showLoading = true, bool sync = false}) async {
    if (showLoading) setState(() => _loading = true);
    if (sync) {
      try { final syncService = ActivitySyncService(); await syncService.syncAll(); } catch (e) { debugPrint('Activities sync error: $e'); }
    }
    final items = await _repository.getActivities();
    final deduped = _deduplicateForDisplay(items);
    if (!mounted) return;
    setState(() { _allActivities = deduped; _applyFilters(); _loading = false; });
  }

  void _applyFilters() {
    _filteredActivities = _allActivities.where((a) {
      if (_filterKind != null && a.kind != _filterKind) return false;
      if (_filterStatus != null && a.uploadStatus != _filterStatus) return false;
      if (_filterSource != null && a.source != _filterSource) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!a.title.toLowerCase().contains(q) && !a.kind.labelRu.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final content = Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _loading 
            ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                onRefresh: () => _loadActivities(sync: true),
                child: _filteredActivities.isEmpty
                    ? Center(child: Text(l10n.noActivitiesYet))
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredActivities.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _buildActivityTile(_filteredActivities[index], l10n),
                      ),
              ),
        ),
      ],
    );

    if (widget.hideAppBar) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activitiesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, size: 22),
            tooltip: 'Импорт GPX/TCX',
            onPressed: () => _importGpxFile(),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month, size: 22),
            tooltip: 'Календарь активностей',
            onPressed: () => _showActivityCalendar(),
          ),
        ],
      ),
      body: content,
    );
  }

  void _showActivityCalendar() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ActivityCalendarSheet(activities: _allActivities),
    );
  }

  Future<void> _importGpxFile() async {
    final gpxService = GpxService();
    try {
      final importedIds = await gpxService.importMultipleFromPicker(
        onProgress: (progress) {
          // Можно показать прогресс если нужно
        },
      );
      if (mounted && importedIds.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Импортировано ${importedIds.length} файл(ов)')),
        );
        _loadActivities();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка импорта: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildFilterBar() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        if (_showSearchBar)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() { _searchQuery = v; _applyFilters(); }),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() { _searchQuery = ''; _applyFilters(); }))
                    : null,
              ),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _showSearchBar = !_showSearchBar;
                  if (!_showSearchBar) { _searchQuery = ''; _applyFilters(); }
                }),
                child: Icon(
                  _showSearchBar ? Icons.search_off : Icons.search,
                  size: 20,
                  color: _showSearchBar ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(_filterKind?.labelRu ?? l10n.allTypes),
                selected: _filterKind != null,
                onSelected: (_) => _showKindFilter(),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(_statusLabel(_filterStatus, l10n)),
                selected: _filterStatus != null,
                avatar: _filterStatus != null ? Icon(_statusIcon(_filterStatus), size: 14) : null,
                onSelected: (_) => _showStatusFilter(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(UploadStatus? s, AppLocalizations l10n) {
    switch (s) {
      case UploadStatus.uploaded: return l10n.inCloud;
      case UploadStatus.pending: return l10n.uploadStatusPending;
      case UploadStatus.failed: return l10n.uploadStatusFailed;
      case null: return l10n.allStatuses;
    }
  }

  IconData _statusIcon(UploadStatus? s) {
    switch (s) {
      case UploadStatus.uploaded: return Icons.cloud_done_outlined;
      case UploadStatus.pending: return Icons.schedule;
      case UploadStatus.failed: return Icons.error_outline;
      case null: return Icons.filter_list;
    }
  }

  IconData _activityIcon(ActivityKind kind) {
    switch (kind) {
      case ActivityKind.run:
      case ActivityKind.trailRun:
      case ActivityKind.trackRun:
      case ActivityKind.treadmillRun:
      case ActivityKind.virtualRun:
        return Icons.directions_run;
      case ActivityKind.roadCycling:
      case ActivityKind.gravelCycling:
      case ActivityKind.mtbCycling:
      case ActivityKind.commutingCycling:
      case ActivityKind.mixedSurfaceCycling:
      case ActivityKind.virtualCycling:
      case ActivityKind.indoorCycling:
      case ActivityKind.eBikeCycling:
      case ActivityKind.eBikeMountainCycling:
        return Icons.directions_bike;
      case ActivityKind.indoorSwimming:
      case ActivityKind.openWaterSwimming:
        return Icons.pool;
      case ActivityKind.walk:
      case ActivityKind.indoorWalk:
      case ActivityKind.hike:
        return Icons.hiking;
      case ActivityKind.rowing:
      case ActivityKind.kayaking:
      case ActivityKind.sailing:
      case ActivityKind.standUpPaddling:
      case ActivityKind.windsurf:
      case ActivityKind.surf:
        return Icons.rowing;
      case ActivityKind.yoga:
        return Icons.self_improvement;
      case ActivityKind.alpineSki:
      case ActivityKind.nordicSki:
      case ActivityKind.snowboard:
      case ActivityKind.snowShoeing:
        return Icons.downhill_skiing;
      case ActivityKind.iceSkate:
      case ActivityKind.inlineSkating:
        return Icons.ice_skating;
      case ActivityKind.strengthTraining:
      case ActivityKind.crossfit:
      case ActivityKind.generalWorkout:
      case ActivityKind.hiit:
      case ActivityKind.cardioTraining:
        return Icons.fitness_center;
      case ActivityKind.soccer:
        return Icons.sports_soccer;
      case ActivityKind.tennis:
      case ActivityKind.tableTennis:
      case ActivityKind.badminton:
      case ActivityKind.squash:
      case ActivityKind.racquetball:
      case ActivityKind.pickleball:
      case ActivityKind.padel:
        return Icons.sports_tennis;
      default:
        return Icons.sports;
    }
  }

  Widget _buildActivityTile(ActivityRecord activity, AppLocalizations l10n) {
    final distanceKm = (activity.distanceMeters / 1000).toStringAsFixed(2);
    final theme = Theme.of(context);
    
    Color statusColor;
    IconData statusIcon;
    switch (activity.uploadStatus) {
      case UploadStatus.uploaded:
        statusColor = Colors.green;
        statusIcon = Icons.cloud_done_outlined;
      case UploadStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
      case UploadStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (context) => ActivityDetailScreen(activity: activity)),
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_activityIcon(activity.kind), color: theme.colorScheme.primary, size: 26),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(activity.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            if (activity.source != ActivitySource.local)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _sourceColor(activity.source).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_sourceLabel(activity.source), style: TextStyle(fontSize: 9, color: _sourceColor(activity.source), fontWeight: FontWeight.w500)),
              ),
          ],
        ),
        subtitle: Text(
          '${activity.kind.labelRu} • $distanceKm km • ${_formatDate(activity.startedAt)} • ${_formatDuration(activity.durationSeconds)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Icon(statusIcon, size: 18, color: statusColor),
      ),
    );
  }


  String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  String _formatDuration(int sec) {
    final d = Duration(seconds: sec);
    if (d.inHours > 0) return "${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
    return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  String _sourceLabel(ActivitySource source) {
    switch (source) {
      case ActivitySource.local: return '';
      case ActivitySource.gpxImport: return 'GPX';
      case ActivitySource.fitImport: return 'FIT';
      case ActivitySource.healthConnect: return 'HC';
      case ActivitySource.serverSync: return 'Сервер';
    }
  }

  Color _sourceColor(ActivitySource source) {
    switch (source) {
      case ActivitySource.local: return Colors.grey;
      case ActivitySource.gpxImport: return Colors.blue;
      case ActivitySource.fitImport: return Colors.orange;
      case ActivitySource.healthConnect: return Colors.teal;
      case ActivitySource.serverSync: return Colors.purple;
    }
  }

  void _showKindFilter() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(l10n.allTypes), onTap: () { setState(() => _filterKind = null); _applyFilters(); Navigator.pop(context); }),
          ...ActivityKind.values.map((k) => ListTile(
            title: Text(k.labelRu),
            onTap: () { setState(() => _filterKind = k); _applyFilters(); Navigator.pop(context); },
          )),
        ],
      ),
    );
  }

  void _showStatusFilter() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(l10n.filterByStatus, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 1),
          ListTile(title: Text(l10n.allStatuses), leading: const Icon(Icons.filter_list), onTap: () { setState(() => _filterStatus = null); _applyFilters(); Navigator.pop(context); }),
          ListTile(title: Text(l10n.inCloud), leading: const Icon(Icons.cloud_done, color: Colors.green), onTap: () { setState(() => _filterStatus = UploadStatus.uploaded); _applyFilters(); Navigator.pop(context); }),
          ListTile(title: Text(l10n.pendingUpload), leading: const Icon(Icons.schedule, color: Colors.orange), onTap: () { setState(() => _filterStatus = UploadStatus.pending); _applyFilters(); Navigator.pop(context); }),
          ListTile(title: Text(l10n.uploadError), leading: const Icon(Icons.error_outline, color: Colors.red), onTap: () { setState(() => _filterStatus = UploadStatus.failed); _applyFilters(); Navigator.pop(context); }),
          const Divider(height: 1),
          ListTile(title: const Text('Источник', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(title: const Text('Все'), leading: const Icon(Icons.filter_list), onTap: () { setState(() => _filterSource = null); _applyFilters(); Navigator.pop(context); }),
          ListTile(title: const Text('Локальная'), leading: const Icon(Icons.phone_android, color: Colors.grey), onTap: () { setState(() => _filterSource = ActivitySource.local); _applyFilters(); Navigator.pop(context); }),
          ListTile(title: const Text('GPX импорт'), leading: const Icon(Icons.file_upload, color: Colors.blue), onTap: () { setState(() => _filterSource = ActivitySource.gpxImport); _applyFilters(); Navigator.pop(context); }),
          ListTile(title: const Text('FIT импорт'), leading: const Icon(Icons.file_upload, color: Colors.orange), onTap: () { setState(() => _filterSource = ActivitySource.fitImport); _applyFilters(); Navigator.pop(context); }),
          ListTile(title: const Text('Health Connect'), leading: const Icon(Icons.favorite, color: Colors.teal), onTap: () { setState(() => _filterSource = ActivitySource.healthConnect); _applyFilters(); Navigator.pop(context); }),
          ListTile(title: const Text('Сервер'), leading: const Icon(Icons.cloud, color: Colors.purple), onTap: () { setState(() => _filterSource = ActivitySource.serverSync); _applyFilters(); Navigator.pop(context); }),
        ],
      ),
    );
  }
}
