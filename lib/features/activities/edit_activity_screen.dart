import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/models/activity_media_model.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/models/gear_model.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/shared/widgets/secure_image.dart';
import 'package:zapfit/core/utils/rpe_to_tss_calculator.dart';
import 'package:zapfit/core/services/training_metrics_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:zapfit/core/constants/map_constants.dart';
import 'package:zapfit/l10n/app_localizations.dart';
import 'package:zapfit/core/services/activity_upload_service.dart';
import 'package:zapfit/core/services/gpx_service.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';

class EditActivityScreen extends StatefulWidget {
  final ActivityRecord activity;
  final List<ActivityPoint> points;
  final List<GearRecord> availableGears;
  final List<ActivityMedia> media;

  const EditActivityScreen({
    super.key,
    required this.activity,
    required this.points,
    required this.availableGears,
    required this.media,
  });

  @override
  State<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends State<EditActivityScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _distanceController;
  late TextEditingController _durationController;
  late ActivityKind _kind;
  late int _visibility;
  int? _gearId;
  late List<ActivityPoint> _points;
  late List<ActivityMedia> _media;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  // === ZAPFIT metrics ===
  int _rpe = 0; // RPE 1-10, 0 = не указано
  double? _computedTss;
  // === ZAPFIT metrics end ===

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.activity.title);
    _notesController = TextEditingController(text: widget.activity.notes);
    _distanceController = TextEditingController(
        text: (widget.activity.distanceMeters / 1000).toStringAsFixed(3));
    _durationController =
        TextEditingController(text: widget.activity.durationSeconds.toString());
    _kind = widget.activity.kind;
    _visibility = widget.activity.visibility;
    _gearId = widget.activity.gearId;
    _points = List.from(widget.points);
    _media = List.from(widget.media);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  double _computeTotalDistanceMeters(List<ActivityPoint> pts) {
    if (pts.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < pts.length; i++) {
      total += distanceInMeters(pts[i-1].latitude, pts[i-1].longitude, pts[i].latitude, pts[i].longitude);
    }
    return total;
  }

  List<ActivityPoint> _recomputeDistanceFromStart(List<ActivityPoint> pts) {
    if (pts.isEmpty) return pts;
    double acc = 0;
    final out = <ActivityPoint>[];
    for (int i = 0; i < pts.length; i++) {
      if (i == 0) { out.add(pts[i].copyWith(distanceFromStartMeters: 0)); } else {
        final seg = distanceInMeters(pts[i-1].latitude, pts[i-1].longitude, pts[i].latitude, pts[i].longitude);
        acc += seg; out.add(pts[i].copyWith(distanceFromStartMeters: acc)); }
    }
    return out;
  }

  void _recalculateAndUpdateControllers() {
    final newDist = _computeTotalDistanceMeters(_points);
    _distanceController.text = (newDist/1000).toStringAsFixed(3);
    if (_points.length >= 2) { final dur = _points.last.timestamp.difference(_points.first.timestamp).inSeconds; if (dur > 0) _durationController.text = dur.toString(); } else if (_points.isEmpty) { _durationController.text = '0'; }
  }

  Future<void> _showMapPicker() async {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final initialCenter = _points.isNotEmpty ? ll.LatLng(_points.last.latitude, _points.last.longitude) : const ll.LatLng(55.7522, 37.6156);
    final distance = const ll.Distance();
    // Берем URL тайлов с учетом настроек пользователя (как в деталях активности)
    String tileUrl = MapConstants.defaultTileServerUrl;
    try {
      final s = AppSettingsController.instance;
      switch (s.mapProvider) {
        case MapProvider.esriSatellite:
          tileUrl = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
          break;
        case MapProvider.tomapo:
          tileUrl = 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
          break;
        case MapProvider.cartoDark:
          tileUrl = 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png';
          break;
        case MapProvider.osm:
          if (s.mapStyle == MapStyle.topographic) {
            tileUrl = 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
          }
          break;
      }
    } catch (_) {}
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 8),
                  Text(isRu ? 'Тапните по карте, чтобы добавить точку' : 'Tap on map to add point', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: initialCenter,
                          initialZoom: 14,
                          maxZoom: 18,
                          minZoom: 3,
                          onTap: (tapPos, latlng) {
                            final last = _points.isNotEmpty ? _points.last : null;
                            double distFromStart = 0;
                            if (last != null) {
                              final seg = distance.as(ll.LengthUnit.Meter, ll.LatLng(last.latitude, last.longitude), latlng);
                              distFromStart = last.distanceFromStartMeters + seg;
                            }
                            double _avgMps = 0;
                            if (_points.length >= 2) {
                              final _td = _computeTotalDistanceMeters(_points);
                              final _dur = _points.last.timestamp.difference(_points.first.timestamp).inSeconds;
                              if (_dur > 0) _avgMps = _td / _dur;
                            }
                            if (_avgMps <= 0.3 && widget.activity.durationSeconds > 0 && widget.activity.distanceMeters > 0) {
                              _avgMps = widget.activity.distanceMeters / widget.activity.durationSeconds;
                            }
                            if (_avgMps <= 0.3) _avgMps = 2.8;
                            final _segM = last != null ? distance.as(ll.LengthUnit.Meter, ll.LatLng(last.latitude, last.longitude), latlng) : 0;
                            double _newSpeed = _segM > 0 ? _segM / 5.0 : _avgMps;
                            if (_newSpeed < 0.5 || _newSpeed > 12) _newSpeed = _avgMps;
                            final newPoint = ActivityPoint(
                              activityId: widget.activity.id ?? 0,
                              timestamp: last != null ? last.timestamp.add(const Duration(seconds: 5)) : DateTime.now(),
                              latitude: latlng.latitude,
                              longitude: latlng.longitude,
                              distanceFromStartMeters: distFromStart,
                              speed: _newSpeed,
                            );
                            setState(() { _points.add(newPoint); _points = _recomputeDistanceFromStart(_points); _recalculateAndUpdateControllers(); });
                            setSheetState(() {});
                            final msg = isRu
                                ? 'Точка добавлена ${latlng.latitude.toStringAsFixed(5)}, ${latlng.longitude.toStringAsFixed(5)}'
                                : 'Point added ${latlng.latitude.toStringAsFixed(5)}, ${latlng.longitude.toStringAsFixed(5)}';
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg, style: const TextStyle(color: Colors.white)),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                duration: const Duration(milliseconds: 900),
                              ),
                            );
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: tileUrl,
                            userAgentPackageName: MapConstants.userAgent,
                            maxZoom: 18,
                            // Включаем кэш тайлов если доступен, иначе сеть
                          ),
                          PolylineLayer(polylines: [Polyline(points: _points.map((p) => ll.LatLng(p.latitude, p.longitude)).toList(), color: Theme.of(context).colorScheme.primary, strokeWidth: 4)]),
                          MarkerLayer(markers: _points.map((p) => Marker(point: ll.LatLng(p.latitude, p.longitude), width: 12, height: 12, child: Container(decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))))).toList()),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [Expanded(child: FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(isRu ? 'Готово' : 'Done')))]),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _editPoint(int index) async {
    final point = _points[index];
    final latController =
        TextEditingController(text: point.latitude.toString());
    final lonController =
        TextEditingController(text: point.longitude.toString());
    final speedController = TextEditingController(
        text: ((point.speed ?? 0.0) * 3.6).toStringAsFixed(1));
    final timeController = TextEditingController(
        text: DateFormat('HH:mm:ss').format(point.timestamp));

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Точка #${index + 1}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latController,
                decoration: const InputDecoration(labelText: 'Широта'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: lonController,
                decoration: const InputDecoration(labelText: 'Долгота'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: speedController,
                decoration: const InputDecoration(labelText: 'Скорость (км/ч)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(labelText: 'Время (HH:mm:ss)'),
                keyboardType: TextInputType.datetime,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ОК'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final newTime = DateFormat('HH:mm:ss').parse(timeController.text);
        final updatedTimestamp = DateTime(
          point.timestamp.year,
          point.timestamp.month,
          point.timestamp.day,
          newTime.hour,
          newTime.minute,
          newTime.second,
        );

        setState(() {
          _points[index] = point.copyWith(
            latitude: double.tryParse(latController.text) ?? point.latitude,
            longitude: double.tryParse(lonController.text) ?? point.longitude,
            speed: (double.tryParse(speedController.text) ?? 0.0) / 3.6,
            timestamp: updatedTimestamp,
          );
          _points = _recomputeDistanceFromStart(_points);
          _points.sort((a,b) => a.timestamp.compareTo(b.timestamp));
          _points = _recomputeDistanceFromStart(_points);
          _recalculateAndUpdateControllers();
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Неверный формат времени')),
          );
        }
      }
    }
  }

  Future<void> _deleteMedia(int mediaId, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить фото?'),
        content: const Text('Это действие нельзя отменить на сервере.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiClient = serviceLocator<ApiClient>();
        final response =
            await apiClient.delete('/api/v1/activities_media/$mediaId');
        if (response.statusCode == 200 || response.statusCode == 204) {
          setState(() {
            _media.removeAt(index);
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: $e')),
          );
        }
      }
    }
  }

  Future<void> _addNewPhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null && widget.activity.serverId != null) {
      setState(() => _isSaving = true);
      try {
        final apiClient = serviceLocator<ApiClient>();
        await apiClient.uploadFile(
          '/api/v1/activities_media/upload/activity_id/${widget.activity.serverId}',
          image.path,
          'file',
        );

        // Refresh media list
        final response = await apiClient.get(
          '/api/v1/activities_media/activity_id/${widget.activity.serverId}',
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            final List<dynamic> data = decoded;
            setState(() {
              _media = data
                  .map((m) => ActivityMedia.fromJson(m as Map<String, dynamic>))
                  .toList();
            });
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка загрузки: $e')),
          );
        }
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      double distMeters =
          (double.tryParse(_distanceController.text.replaceAll(',', '.')) ??
                  0.0) *
              1000;
      int durSeconds = int.tryParse(_durationController.text) ?? 0;
      final _prePointsChangedCheck = _points.length != widget.points.length || _points.where((p) => p.id == null).isNotEmpty || _points.asMap().entries.any((e) { if (e.key >= widget.points.length) return true; final orig = widget.points[e.key]; return (e.value.latitude - orig.latitude).abs() > 1e-7 || (e.value.longitude - orig.longitude).abs() > 1e-7; });
      if (_prePointsChangedCheck && _points.isNotEmpty) {
        _points = _recomputeDistanceFromStart(_points);
        final computedDist = _computeTotalDistanceMeters(_points);
        if (computedDist > 0) distMeters = computedDist;
        if (_points.length >= 2) { final computedDur = _points.last.timestamp.difference(_points.first.timestamp).inSeconds; if (computedDur > 0) durSeconds = computedDur; }
        _distanceController.text = (distMeters/1000).toStringAsFixed(3);
        _durationController.text = durSeconds.toString();
      }

      var updated = widget.activity.copyWith(
        title: _titleController.text,
        notes: _notesController.text,
        distanceMeters: distMeters,
        durationSeconds: durSeconds,
        kind: _kind,
        visibility: _visibility,
        gearId: _gearId,
      );

      // [comment removed - encoding corrupted]
      final repo = LocalActivityRepository.instance;
      if (updated.id != null) {
        await repo.updateActivity(updated);
      } else {
        final newId = await repo.createActivity(updated);
        updated = updated.copyWith(id: newId);
      }

      // [comment removed - encoding corrupted]
      final originalPointIds =
          widget.points.where((p) => p.id != null).map((p) => p.id!).toSet();
      final currentPointIds =
          _points.where((p) => p.id != null).map((p) => p.id!).toSet();

      final toDelete = originalPointIds.difference(currentPointIds);
      for (final id in toDelete) {
        await repo.deletePoint(id);
      }

      for (final p in _points) {
        if (p.id != null) {
          await repo.updatePoint(p);
        } else if (updated.id != null) {
          await repo.addPoint(p.copyWith(activityId: updated.id!));
        }
      }

      await repo.updateActivity(
        updated.copyWith(uploadStatus: UploadStatus.pending),
      );
      updated = updated.copyWith(uploadStatus: UploadStatus.pending);

      final bool pointsChanged = toDelete.isNotEmpty || _points.any((p) => p.id == null) || _points.length != widget.points.length || _points.asMap().entries.any((e) { if (e.key >= widget.points.length) return true; final orig = widget.points[e.key]; return (e.value.latitude - orig.latitude).abs() > 1e-7 || (e.value.longitude - orig.longitude).abs() > 1e-7; });
      if (pointsChanged && updated.id != null) {
        final recomputedDist = _computeTotalDistanceMeters(_points);
        int recomputedDur = updated.durationSeconds;
        DateTime? recomputedEnd = updated.endedAt;
        DateTime recomputedStart = updated.startedAt;
        if (_points.length >= 2) {
          recomputedDur = _points.last.timestamp.difference(_points.first.timestamp).inSeconds;
          recomputedEnd = _points.last.timestamp;
          recomputedStart = _points.first.timestamp;
        } else if (_points.isNotEmpty) {
          recomputedEnd = _points.last.timestamp;
          recomputedStart = _points.first.timestamp;
        }
        await repo.updateActivity(updated.copyWith(distanceMeters: recomputedDist, durationSeconds: recomputedDur, startedAt: recomputedStart, endedAt: recomputedEnd, uploadStatus: UploadStatus.pending));
        updated = updated.copyWith(distanceMeters: recomputedDist, durationSeconds: recomputedDur, startedAt: recomputedStart, endedAt: recomputedEnd, uploadStatus: UploadStatus.pending);
        final int? oldServerId = updated.serverId;
        if (oldServerId != null) {
          await repo.updateActivity(updated.copyWith(serverId: null, uploadStatus: UploadStatus.pending));
          updated = updated.copyWith(serverId: null, uploadStatus: UploadStatus.pending);
        }
        try {
          final uploadService = ActivityUploadService();
          await uploadService.uploadActivity(updated.id!);
          final refreshed = await repo.getActivity(updated.id!);
          if (refreshed != null) updated = refreshed;
          if (oldServerId != null && refreshed != null && refreshed.serverId != null && refreshed.serverId != oldServerId) {
            try {
              final apiClient = serviceLocator<ApiClient>();
              await apiClient.delete('/api/v1/activities/$oldServerId/delete').timeout(const Duration(seconds: 12));
            } catch (e) { debugPrint('Cleanup old server activity $oldServerId failed: $e'); }
          }
        } catch (e) { debugPrint('Re-upload failed (will retry on sync): $e'); }
      }

      // === ZAPFIT metrics ===
      // Сохраняем RPE и рассчитанный TSS (RpeToTssCalculator) для активности.
      if (updated.id != null && _rpe > 0) {
        final int durSeconds = updated.durationSeconds;
        final int durationMinutes = (durSeconds / 60).round();
        final double tss = RpeToTssCalculator.convert(
          durationMinutes: durationMinutes,
          rpe: _rpe,
        );
        await TrainingMetricsService.instance.saveTss(
          updated.id!,
          tss,
          durSeconds,
          rpe: _rpe,
        );
      }
      // === ZAPFIT metrics end ===

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сохранено локально')),
        );
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактирование'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Основная информация'),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Заметки / Комментарий',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _distanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Дистанция (км)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Время (сек)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ActivityKind>(
            initialValue: _kind,
            decoration: const InputDecoration(
              labelText: 'Спорт',
              border: OutlineInputBorder(),
            ),
            items: ActivityKind.values
                .map((k) => DropdownMenuItem(value: k, child: Text(k.labelRu)))
                .toList(),
            onChanged: (v) => setState(() => _kind = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _visibility,
            decoration: const InputDecoration(
              labelText: 'Приватность',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Публично')),
              DropdownMenuItem(value: 1, child: Text('Подписчики')),
              DropdownMenuItem(value: 2, child: Text('Только я')),
            ],
            onChanged: (v) => setState(() => _visibility = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _gearId,
            decoration: const InputDecoration(
              labelText: 'Снаряжение',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Не выбрано')),
              ...widget.availableGears.map(
                (g) => DropdownMenuItem(value: g.id, child: Text(g.nickname)),
              ),
            ],
            onChanged: (v) => setState(() => _gearId = v),
          ),
          const SizedBox(height: 24),
          // === ZAPFIT metrics ===
          _sectionTitle('Нагрузка (RPE → TSS)'),
          Row(
            children: [
              const Icon(Icons.speed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _rpe.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: _rpe == 0 ? 'Не указано' : _rpe.toString(),
                  onChanged: (v) {
                    setState(() {
                      _rpe = v.round();
                      _computedTss = _rpe > 0
                          ? RpeToTssCalculator.convert(
                              durationMinutes:
                                  (int.tryParse(_durationController.text) ?? 0) ~/ 60,
                              rpe: _rpe,
                            )
                          : null;
                    });
                  },
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  _rpe == 0 ? '—' : _rpe.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          Text('RPE (воспринимаемая нагрузка) от 1 до 10',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          const SizedBox(height: 8),
          if (_computedTss != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Расчётный TSS', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(_computedTss!.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          // === ZAPFIT metrics end ===
          const SizedBox(height: 24),
          _sectionTitle('Медиа (фото)'),
          if (_media.isEmpty)
            const Text('Нет фотографий', style: TextStyle(color: Colors.grey))
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _media.length,
                itemBuilder: (context, index) {
                  final m = _media[index];
                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: SecureImage(
                          imageUrl: m.mediaPath,
                          width: 100,
                          height: 100,
                          borderRadius: 8,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 4,
                        child: InkWell(
                          onTap: () => _deleteMedia(m.id!, index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addNewPhoto,
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Добавить фото'),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Точки маршрута (${_points.length})'),
          Builder(
            builder: (ctx) {
              final isRuBtn = Localizations.localeOf(ctx).languageCode == 'ru';
              return Row(
                children: [
                  Expanded(child: const SizedBox.shrink()),
                  TextButton.icon(
                    onPressed: _showMapPicker,
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: Text(isRuBtn ? 'Добавить на карте' : 'Add on map'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Container(
            height: 350,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              itemCount: _points.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = _points[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    '#${index + 1}: ${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}',
                  ),
                  subtitle: Text(
                    '${((p.speed ?? 0) * 3.6).toStringAsFixed(1)} км/ч • ${DateFormat('HH:mm:ss').format(p.timestamp)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 20,
                          color: Colors.blue,
                        ),
                        onPressed: () => _editPoint(index),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          size: 20,
                          color: Colors.red,
                        ),
                        onPressed: () => setState(() { _points.removeAt(index); _points = _recomputeDistanceFromStart(_points); _recalculateAndUpdateControllers(); }),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

