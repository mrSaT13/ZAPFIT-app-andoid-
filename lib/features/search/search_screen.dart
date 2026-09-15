import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/user_service.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/features/activities/activity_detail_screen.dart';
import 'package:intl/intl.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiClient _apiClient = serviceLocator<ApiClient>();
  final TextEditingController _searchCtrl = TextEditingController();
  List<ActivityRecord> _results = [];
  bool _isLoading = false;
  String? _error;

  int? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;

  static const Map<int, String> _activityTypes = {
    0: 'Бег',
    1: 'Вело',
    2: 'Плавание',
    3: 'Ходьба',
    4: 'Силовая',
    5: 'Тренировка',
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty && _selectedType == null && _startDate == null && _endDate == null) return;

    setState(() { _isLoading = true; _error = null; });

    try {
      final userService = serviceLocator<UserService>();
      if (userService.profile == null) await userService.fetchProfile();
      final userId = userService.profile?.id;
      if (userId == null) {
        _error = 'Не удалось определить пользователя';
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final queryParams = <String, String>{};
      if (query.isNotEmpty) queryParams['name_search'] = query;
      if (_selectedType != null) queryParams['type'] = _selectedType.toString();
      if (_startDate != null) queryParams['start_date'] = DateFormat('yyyy-MM-dd').format(_startDate!);
      if (_endDate != null) queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';
      final response = await _apiClient.get('/api/v1/activities/user/$userId/page_number/1/num_records/50$queryString');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        _results = data.map((item) {
          try {
            return ActivityRecord.fromServerJson(item as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        }).whereType<ActivityRecord>().toList();
      } else {
        _error = 'Ошибка поиска (${response.statusCode})';
      }
    } catch (e) {
      _error = 'Ошибка сети';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск активностей'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Поиск по названию...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() { _results = []; _error = null; });
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) => _search(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Activity type filter
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      hintText: 'Тип',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Все типы')),
                      ..._activityTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                    ],
                    onChanged: (v) => setState(() => _selectedType = v),
                  ),
                ),
                const SizedBox(width: 8),
                // Date range
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      _startDate != null && _endDate != null
                          ? '${DateFormat('dd.MM').format(_startDate!)}-${DateFormat('dd.MM').format(_endDate!)}'
                          : 'Даты',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Search button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _search,
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: const Text('Найти'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Error
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          // Results
          if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Найдено: ${_results.length}', style: TextStyle(color: theme.colorScheme.outline)),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _results.isEmpty && !_isLoading
                ? Center(
                    child: Text(
                      _searchCtrl.text.isEmpty ? 'Введите запрос для поиска' : 'Ничего не найдено',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final act = _results[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ActivityDetailScreen(activity: act)),
                          ),
                          leading: Icon(_activityIcon(act.kind), color: theme.colorScheme.primary),
                          title: Text(act.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${act.kind.labelRu} • ${(act.distanceMeters / 1000).toStringAsFixed(1)} км • ${DateFormat('dd.MM.yyyy').format(act.startedAt)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
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
}
