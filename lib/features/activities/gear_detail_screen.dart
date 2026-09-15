import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/models/gear_model.dart';
import 'package:zapfit/core/models/gear_photo.dart';
import 'package:zapfit/core/models/gear_replacement.dart';
import 'package:zapfit/core/services/gear_service.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/services/gear_photo_sync_service.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/services/gear_replacement_history.dart';
import 'package:zapfit/features/activities/activity_detail_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class GearDetailScreen extends StatefulWidget {
  const GearDetailScreen({super.key, required this.gear});

  final GearRecord gear;

  @override
  State<GearDetailScreen> createState() => _GearDetailScreenState();
}

class _GearDetailScreenState extends State<GearDetailScreen> {
  GearDetail? _detail;
  bool _loading = true;
  String? _error;
  List<ActivityRecord> _recentActivities = [];
  List<double> _weeklyDistances = [];
  List<String> _weekLabels = [];
  List<GearComponent> _components = [];
  List<GearPhoto> _photos = [];
  final PageController _photoPageController = PageController();
  int _currentPhotoIndex = 0;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final gearService = serviceLocator<GearService>();
      final repository = LocalActivityRepository.instance;

      final detail = await gearService.fetchGearDetail(widget.gear.id);
      final activities = await repository.getActivitiesByGearId(widget.gear.id, limit: 20);
      final components = await gearService.fetchComponents(widget.gear.id);
      var photos = await repository.getGearPhotos(widget.gear.id);

      // Pull server images and cache offline (at detail open only)
      try {
        await GearPhotoSyncService.instance.syncFromServer(widget.gear.id);
        photos = await repository.getGearPhotos(widget.gear.id);
      } catch (_) {}

      // Calculate weekly distances for last 8 weeks
      final weeklyData = _calculateWeeklyDistances(activities);

      if (!mounted) return;
      setState(() {
        _detail = detail;
        _recentActivities = activities;
        _weeklyDistances = weeklyData.distances;
        _weekLabels = weeklyData.labels;
        _components = components;
        _photos = photos;
        _loading = false;
        if (detail == null) _error = 'Не удалось загрузить данные';
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Ошибка: $e'; });
    }
  }

  ({List<double> distances, List<String> labels}) _calculateWeeklyDistances(List<ActivityRecord> activities) {
    final now = DateTime.now();
    final distances = <double>[];
    final labels = <String>[];

    for (int i = 7; i >= 0; i--) {
      final weekEnd = now.subtract(Duration(days: i * 7));
      final weekStart = weekEnd.subtract(const Duration(days: 7));

      double totalDist = 0;
      for (final a in activities) {
        if (a.startedAt.isAfter(weekStart) && a.startedAt.isBefore(weekEnd)) {
          totalDist += a.distanceMeters / 1000;
        }
      }

      distances.add(totalDist);
      labels.add(DateFormat('dd.MM').format(weekStart));
    }

    return (distances: distances, labels: labels);
  }

  bool get _isDefaultForType {
    final gearService = serviceLocator<GearService>();
    final typeKey = widget.gear.gearType == 1 ? 'bike' : 'shoes';
    return gearService.defaultGears[typeKey] == widget.gear.id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gear = widget.gear;

    return Scaffold(
      appBar: AppBar(
        title: Text(gear.nickname),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditGearDialog(),
          ),
          if (!gear.active)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Не активно', style: TextStyle(color: Colors.orange, fontSize: 12)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      FilledButton.tonal(onPressed: _loadData, child: const Text('Повторить')),
                    ],
                  ),
                )
              : _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final d = _detail!;
    final distanceKm = d.totalDistance / 1000;
    final initialKm = d.initialKms ?? 0;
    final totalKm = distanceKm + (initialKm / 1000);
    final hours = (d.totalTime / 3600).floor();
    final minutes = ((d.totalTime % 3600) / 60).floor();

    // Average speed
    final avgSpeed = d.totalTime > 0 ? (d.totalDistance / 1000) / (d.totalTime / 3600) : 0.0;

    // Activity count
    final activityCount = _recentActivities.length;

    final gearIcon = d.gearType == 1 ? Icons.directions_bike : d.gearType == 2 ? Icons.directions_run : Icons.inventory_2_outlined;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero card
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(gearIcon, size: 40, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.nickname, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        if (d.brand != null || d.model != null)
                          Text(
                            [d.brand, d.model].whereType<String>().join(' '),
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7)),
                          ),
                        const SizedBox(height: 4),
                        Text(d.typeLabel, style: theme.textTheme.bodySmall),
                        if (d.gearType == 1 && d.wheelDiameterCm != null) ...[
                          const SizedBox(height: 2),
                          Text('Диаметр колеса: ${d.wheelDiameterCm!.toStringAsFixed(1)} см', style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Make default button
          const SizedBox(height: 12),
          if (_isDefaultForType)
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const ListTile(
                leading: Icon(Icons.star, color: Colors.amber),
                title: Text('Основное снаряжение', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Используется по умолчанию'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final typeKey = widget.gear.gearType == 1 ? 'bike' : 'shoes';
                  await serviceLocator<GearService>().setDefaultGear(typeKey, widget.gear.id);
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${widget.gear.nickname} установлено как основное')),
                    );
                  }
                },
                icon: const Icon(Icons.star_outline, size: 18),
                label: const Text('Сделать основным'),
              ),
            ),

          // Photo gallery
          const SizedBox(height: 16),
          _buildPhotoSection(theme),

          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(child: _statCard(theme, Icons.route_outlined, 'Пробег', '${totalKm.toStringAsFixed(1)} км')),
              const SizedBox(width: 8),
              Expanded(child: _statCard(theme, Icons.timer_outlined, 'Время', '${hours}ч ${minutes}м')),
              const SizedBox(width: 8),
              Expanded(child: _statCard(theme, Icons.speed, 'Ср. скорость', '${avgSpeed.toStringAsFixed(1)} км/ч')),
            ],
          ),

          const SizedBox(height: 12),

          // Weekly mileage graph
          if (_weeklyDistances.any((d) => d > 0)) ...[
            _sectionHeader(theme, 'Пробег по неделям'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _weeklyDistances.reduce((a, b) => a > b ? a : b) * 1.2,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < _weekLabels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(_weekLabels[idx], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: _weeklyDistances.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value,
                              color: theme.colorScheme.primary,
                              width: 16,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Details section
          const SizedBox(height: 12),
          _sectionHeader(theme, 'Параметры'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                if (d.initialKms != null && d.initialKms! > 0)
                  _detailRow(theme, 'Начальный пробег', '${(d.initialKms! / 1000).toStringAsFixed(1)} км'),
                _detailRow(theme, 'Пробег (трекер)', '${distanceKm.toStringAsFixed(1)} км'),
                _detailRow(theme, 'Суммарный пробег', '${totalKm.toStringAsFixed(1)} км', highlight: true),
                _detailRow(theme, 'Активностей', '$activityCount'),
                if (avgSpeed > 0)
                  _detailRow(theme, 'Средняя скорость', '${avgSpeed.toStringAsFixed(1)} км/ч'),
                if (d.purchaseValue != null)
_detailRow(theme, 'Стоимость покупки', '${d.purchaseValue!.toStringAsFixed(0)} ${AppSettingsController.instance.currencySymbol}'),
                  if (d.totalComponentsCost > 0)
                    _detailRow(theme, 'Стоимость запчастей', '${d.totalComponentsCost.toStringAsFixed(0)} ${AppSettingsController.instance.currencySymbol}'),
                if (d.createdAt != null)
                  _detailRow(theme, 'Добавлено', DateFormat('dd.MM.yyyy').format(d.createdAt!)),
              ],
            ),
          ),

          // Components section
          if (_components.isNotEmpty || widget.gear.gearType == 1 || widget.gear.gearType == 2) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader(theme, 'Компоненты'),
                TextButton.icon(
                  onPressed: () => _showAddComponentDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить'),
                ),
              ],
            ),
            if (_components.isEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Нет компонентов', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              )
            else ...[
              // Active components
              ..._components.where((c) => c.active).map((c) => _buildComponentCard(theme, c, isActive: true)),
              // Retired components section
              if (_components.any((c) => !c.active)) ...[
                const SizedBox(height: 12),
                Text('Заменённые компоненты', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                const SizedBox(height: 8),
                ..._components.where((c) => !c.active).map((c) => _buildComponentCard(theme, c, isActive: false)),
              ],
            ],
          ],

          // Recent activities
          if (_recentActivities.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionHeader(theme, 'Последние активности'),
            ..._recentActivities.take(5).map((a) => _buildActivityTile(theme, a)),
          ],

          if (d.stravaGearId != null || d.garminconnectGearId != null) ...[
            const SizedBox(height: 12),
            _sectionHeader(theme, 'Интеграции'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  if (d.stravaGearId != null)
                    _detailRow(theme, 'Strava ID', d.stravaGearId!),
                  if (d.garminconnectGearId != null)
                    _detailRow(theme, 'Garmin ID', d.garminconnectGearId!),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActivityTile(ThemeData theme, ActivityRecord activity) {
    final distanceKm = (activity.distanceMeters / 1000).toStringAsFixed(2);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ActivityDetailScreen(activity: activity)),
        ),
        leading: Icon(
          _activityIcon(activity.kind),
          color: theme.colorScheme.primary,
        ),
        title: Text(activity.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${activity.kind.labelRu} • $distanceKm км • ${DateFormat('dd.MM').format(activity.startedAt)}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
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
      case ActivityKind.virtualCycling:
      case ActivityKind.indoorCycling:
      case ActivityKind.eBikeCycling:
      case ActivityKind.eBikeMountainCycling:
        return Icons.directions_bike;
      case ActivityKind.walk:
      case ActivityKind.indoorWalk:
      case ActivityKind.hike:
        return Icons.directions_walk;
      case ActivityKind.yoga:
        return Icons.self_improvement;
      case ActivityKind.strengthTraining:
      case ActivityKind.crossfit:
      case ActivityKind.hiit:
        return Icons.fitness_center;
      default:
        return Icons.sports;
    }
  }

  Widget _statCard(ThemeData theme, IconData icon, String label, String value) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, size: 24, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, letterSpacing: 1.2)),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentCard(ThemeData theme, GearComponent c, {required bool isActive}) {
    final typeLabel = gearComponentTypeLabels[c.type] ?? c.type;
    final wearPct = c.wearPercentage;
    final wearColor = c.isOverdue ? Colors.red : (wearPct > 0.8 ? Colors.orange : theme.colorScheme.primary);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showReplacementHistory(c),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.settings, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(typeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${c.brand} ${c.model}', style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Активен', style: TextStyle(color: Colors.green, fontSize: 11)),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Заменён', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  ],
                ],
              ),
              if (isActive) ...[
                if (c.expectedKms != null && c.expectedKms! > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${c.currentDistanceKm.toStringAsFixed(0)} км / ${(c.expectedKms! / 1000).toStringAsFixed(0)} км', style: const TextStyle(fontSize: 12)),
                      Text('${(wearPct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: wearColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: wearPct.clamp(0.0, 1.0),
                      backgroundColor: theme.colorScheme.outlineVariant.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(wearColor),
                      minHeight: 6,
                    ),
                  ),
                ],
                if (c.purchaseDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Установлен: ${DateFormat('dd.MM.yyyy').format(c.purchaseDate!)}', style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
                  ),
              ],
              if (!isActive && c.retiredDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Заменён: ${DateFormat('dd.MM.yyyy').format(c.retiredDate!)}', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              if (c.active)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    final commentController = TextEditingController();
                    final comment = await showDialog<String?>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Заменить компонент?'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('"${gearComponentTypeLabels[c.type] ?? c.type}" будет списан, а на его место добавлен новый с нулевым износом.'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: commentController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Комментарий (по желанию)',
                                hintText: 'Например: "Износ 1500 км, смена на новые"',
                                border: OutlineInputBorder(),
                              ),
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Отмена')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, commentController.text.trim()), child: const Text('Заменить')),
                        ],
                      ),
                    );
                    if (comment != null) {
                      final gearService = serviceLocator<GearService>();
                      final historyService = GearReplacementHistory.instance;
                      await historyService.load();
                      // 1) Сохраняем запись в историю замен
                      await historyService.addReplacement(c, comment, purchaseValue: c.purchaseValue);
                      // 2) Списываем старый компонент (фиксируем его накопленный износ)
                      await gearService.retireComponent(c);
                      // 3) Создаём новый активный компонент той же модели.
                      //    Сервер считает износ от purchase_date, поэтому новый
                      //    начинается с 0 км / 0% износа.
                      await gearService.createComponent(
                        gearId: c.gearId,
                        type: c.type,
                        brand: c.brand,
                        model: c.model,
                        purchaseDate: DateTime.now(),
                        expectedKms: c.expectedKms,
                        purchaseValue: c.purchaseValue,
                      );
                      _loadData();
                    }
                  },
                  child: const Text('Заменить', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],                  // closes children list of Column
          ),                // closes Column
        ),                  // closes Padding
      ),                    // closes InkWell
    );                      // closes Card (return statement)
  }

  void _showReplacementHistory(GearComponent component) async {
    final historyService = GearReplacementHistory.instance;
    await historyService.load();
    final typeLabel = gearComponentTypeLabels[component.type] ?? component.type;

    // Filter history for this component type
    final relevantHistory = historyService.history
        .where((h) => h.oldComponentType == component.type)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('История замен', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(typeLabel, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: relevantHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Нет записей о заменах', style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Text('Записи появятся после замены компонента', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: relevantHistory.length,
                      itemBuilder: (ctx, i) {
                        final h = relevantHistory[i];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.swap_horiz, size: 16, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${h.oldComponentBrand} ${h.oldComponentModel}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormat('dd.MM.yyyy').format(h.timestamp),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Пробег при замене: ${h.oldComponentDistance.toStringAsFixed(0)} км',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                if (h.purchaseValue != null && h.purchaseValue! > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Стоимость: ${h.purchaseValue!.toStringAsFixed(0)} ${AppSettingsController.instance.currencySymbol}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ),
                                if (h.comment != null && h.comment!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      h.comment!,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGearDialog() {
    final d = _detail;
    if (d == null) return;
    final nicknameCtrl = TextEditingController(text: d.nickname);
    final brandCtrl = TextEditingController(text: d.brand ?? '');
    final modelCtrl = TextEditingController(text: d.model ?? '');
    final initialKmsCtrl = TextEditingController(text: d.initialKms != null ? (d.initialKms! / 1000).toStringAsFixed(1) : '');
    final wheelDiameterCtrl = TextEditingController(text: d.wheelDiameterCm != null ? d.wheelDiameterCm!.toStringAsFixed(1) : '');
    final isBicycle = d.gearType == 1;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать снаряжение'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nicknameCtrl, decoration: const InputDecoration(labelText: 'Название')),
              TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Бренд')),
              TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Модель')),
              TextField(controller: initialKmsCtrl, decoration: const InputDecoration(labelText: 'Начальный пробег (км)'), keyboardType: TextInputType.number),
              if (isBicycle) ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 4),
                Text('Велосипед', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                TextField(
                  controller: wheelDiameterCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Диаметр колеса (см)',
                    helperText: 'Стандарт: 700c=63.3, 29"=62.2, 27.5"=58.4, 26"=66.0',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              final gearService = serviceLocator<GearService>();
              final wheelDiameter = double.tryParse(wheelDiameterCtrl.text);
              final updated = d.copyWith(
                nickname: nicknameCtrl.text,
                brand: brandCtrl.text.isNotEmpty ? brandCtrl.text : null,
                model: modelCtrl.text.isNotEmpty ? modelCtrl.text : null,
                initialKms: double.tryParse(initialKmsCtrl.text) != null ? double.parse(initialKmsCtrl.text) * 1000 : null,
                wheelDiameterCm: wheelDiameter,
              );
              await gearService.updateGear(updated);
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showAddComponentDialog() {
    final typeCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final expectedKmsCtrl = TextEditingController();
    String? selectedType;

    final availableTypes = widget.gear.gearType == 1
        ? ['chain', 'cassette', 'front_tire', 'back_tire', 'front_break_pads', 'back_break_pads', 'front_break_rotor', 'back_break_rotor', 'saddle', 'pedals', 'handlebar_tape', 'grips']
        : widget.gear.gearType == 2
            ? ['cleats', 'insoles', 'laces']
            : widget.gear.gearType == 5
                ? ['bindings', 'boots', 'poles', 'helmet', 'goggles', 'ski_brakes', 'skins', 'deviation_skins']
                : [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Добавить компонент'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (availableTypes.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: availableTypes.map((t) => DropdownMenuItem<String>(value: t as String, child: Text(gearComponentTypeLabels[t] ?? t))).toList(),
                    onChanged: (v) => setDialogState(() => selectedType = v),
                  )
                else
                  TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Тип')),
                const SizedBox(height: 8),
                TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Бренд')),
                const SizedBox(height: 8),
                TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Модель')),
                const SizedBox(height: 8),
                TextField(controller: expectedKmsCtrl, decoration: const InputDecoration(labelText: 'Ожидаемый ресурс (км)'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                final type = selectedType ?? typeCtrl.text;
                if (type.isEmpty || brandCtrl.text.isEmpty || modelCtrl.text.isEmpty) return;
                final gearService = serviceLocator<GearService>();
                await gearService.createComponent(
                  gearId: widget.gear.id,
                  type: type,
                  brand: brandCtrl.text,
                  model: modelCtrl.text,
                  expectedKms: (int.tryParse(expectedKmsCtrl.text) ?? 0) * 1000,
                );
                Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader(theme, 'Фото'),
            TextButton.icon(
              onPressed: _addPhoto,
              icon: const Icon(Icons.add_a_photo, size: 18),
              label: const Text('Добавить'),
            ),
          ],
        ),
        if (_photos.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: SizedBox(
              height: 160,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_camera_outlined, size: 40, color: theme.colorScheme.outline.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text('Нет фото', style: TextStyle(color: theme.colorScheme.outline, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Добавьте фото вашего снаряжения', style: TextStyle(color: theme.colorScheme.outline.withOpacity(0.6), fontSize: 11)),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                PageView.builder(
                  controller: _photoPageController,
                  itemCount: _photos.length,
                  onPageChanged: (i) => setState(() => _currentPhotoIndex = i),
                  itemBuilder: (ctx, i) {
                    final photo = _photos[i];
                    final file = File(photo.filePath);
                    return GestureDetector(
                      onTap: () => _openGallery(i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: file.existsSync()
                            ? Image.file(file, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)))
                            : const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                      ),
                    );
                  },
                ),
                if (_photos.length > 1)
                  Positioned(
                    bottom: 8,
                    child: Row(
                      children: List.generate(_photos.length, (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentPhotoIndex == i ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentPhotoIndex == i
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _deletePhoto(_photos[_currentPhotoIndex]),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Камера'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Галерея'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final xFile = await _imagePicker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
    if (xFile == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final gearDir = Directory(p.join(appDir.path, 'gear_photos', '${widget.gear.id}'));
    if (!gearDir.existsSync()) await gearDir.create(recursive: true);

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedFile = await File(xFile.path).copy(p.join(gearDir.path, fileName));

    final photo = GearPhoto(gearId: widget.gear.id, filePath: savedFile.path, synced: false);
    await LocalActivityRepository.instance.addGearPhoto(photo);
    // Fire-and-forget upload
    try {
      await GearPhotoSyncService.instance.syncAll();
    } catch (_) {}
    _loadData();
  }

  void _openGallery(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GalleryScreen(photos: _photos, initialIndex: initialIndex),
      ),
    );
  }

  Future<void> _deletePhoto(GearPhoto photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить фото?'),
        content: const Text('Фото будет удалено навсегда'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm == true) {
      // Delete from server if it has serverId
      if (photo.serverId != null) {
        try {
          await serviceLocator<GearService>().deleteGearImage(photo.serverId!);
        } catch (_) {}
      }
      final file = File(photo.filePath);
      if (await file.exists()) {
        try { await file.delete(); } catch (_) {}
      }
      if (photo.id != null) {
        await LocalActivityRepository.instance.deleteGearPhoto(photo.id!);
      }
      if (mounted) _loadData();
    }
  }
}

class _GalleryScreen extends StatelessWidget {
  final List<GearPhoto> photos;
  final int initialIndex;

  const _GalleryScreen({required this.photos, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${initialIndex + 1} / ${photos.length}'),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: photos.length,
        itemBuilder: (ctx, i) {
          final f = File(photos[i].filePath);
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: f.existsSync()
                  ? Image.file(f, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48, color: Colors.white54))
                  : const Icon(Icons.broken_image, size: 48, color: Colors.white54),
            ),
          );
        },
      ),
    );
  }
}
