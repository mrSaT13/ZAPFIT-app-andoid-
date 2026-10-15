import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endurain/core/services/local_activity_repository.dart';
import 'package:endurain/core/services/local_notification_service.dart';
import 'package:endurain/core/services/ollama_service.dart';

/// Соревнование (локально, синхронизация с сервером — TODO под API).
class Competition {
  final String id;
  final String name;
  final DateTime date;
  final double distanceKm;
  final String? note;
  final bool synced;
  final bool finished;
  final int? place;
  final int? totalParticipants;
  final int? resultTimeSec;
  final List<int> notifIds;

  Competition({
    required this.id,
    required this.name,
    required this.date,
    required this.distanceKm,
    this.note,
    this.synced = false,
    this.finished = false,
    this.place,
    this.totalParticipants,
    this.resultTimeSec,
    List<int>? notifIds,
  }) : notifIds = notifIds ?? const [];

  Competition copyWith({
    bool? finished,
    int? place,
    int? totalParticipants,
    int? resultTimeSec,
    List<int>? notifIds,
  }) {
    return Competition(
      id: id,
      name: name,
      date: date,
      distanceKm: distanceKm,
      note: note,
      synced: synced,
      finished: finished ?? this.finished,
      place: place ?? this.place,
      totalParticipants: totalParticipants ?? this.totalParticipants,
      resultTimeSec: resultTimeSec ?? this.resultTimeSec,
      notifIds: notifIds ?? this.notifIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dateMs': date.millisecondsSinceEpoch,
        'distanceKm': distanceKm,
        'note': note,
        'synced': synced,
        'finished': finished,
        'place': place,
        'totalParticipants': totalParticipants,
        'resultTimeSec': resultTimeSec,
        'notifIds': notifIds,
      };

  factory Competition.fromJson(Map<String, dynamic> j) => Competition(
        id: j['id'] as String,
        name: j['name'] as String,
        date: DateTime.fromMillisecondsSinceEpoch((j['dateMs'] as num).toInt()),
        distanceKm: (j['distanceKm'] as num).toDouble(),
        note: j['note'] as String?,
        synced: j['synced'] as bool? ?? false,
        finished: j['finished'] as bool? ?? false,
        place: (j['place'] as num?)?.toInt(),
        totalParticipants: (j['totalParticipants'] as num?)?.toInt(),
        resultTimeSec: (j['resultTimeSec'] as num?)?.toInt(),
        notifIds: (j['notifIds'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
      );
}

class PreparationTab extends StatefulWidget {
  const PreparationTab({super.key});

  @override
  State<PreparationTab> createState() => _PreparationTabState();
}

class _PreparationTabState extends State<PreparationTab> {
  static const _kCompetitionsKey = 'competitions_v1';

  List<Competition> _competitions = [];
  String? _selectedId;
  bool _loading = true;

  // Stats for selected competition
  double _avgWeeklyKm = 0;
  int _activities28d = 0;
  double _longestKm = 0;
  int _daysSinceLast = -1;
  double _readiness = 0;
  List<String> _suggestions = [];

  String? _aiAnalysis;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCompetitionsKey);
      final list = <Competition>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw) as List;
        for (final e in decoded) {
          try {
            list.add(Competition.fromJson(e as Map<String, dynamic>));
          } catch (_) {}
        }
      }
      list.sort((a, b) => a.date.compareTo(b.date));
      if (mounted) {
        setState(() {
          _competitions = list;
          if (_selectedId == null || !list.any((c) => c.id == _selectedId)) {
            _selectedId = list.isNotEmpty ? list.first.id : null;
          }
        });
        await _computeStats();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveCompetitions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kCompetitionsKey,
        json.encode(_competitions.map((c) => c.toJson()).toList()),
      );
    } catch (_) {}
    // TODO(server): POST /api/v1/competitions/sync — отправить list, проставить synced=true.
    // Пока серверного API нет: записи хранятся локально с synced=false.
  }

  int _notifBaseId(Competition c) {
    final num = int.tryParse(c.id) ?? c.id.hashCode;
    return 200000 + (num.abs() % 9000) * 10;
  }

  /// Текст этапа от алгоритма (офлайн, детерминированный — приходит и без сети).
  /// ИИ-комментарий в пуши не кладём: на момент срабатывания сети/ключа может не быть,
  /// ИИ разбор доступен по кнопке во вкладке.
  String _stageBody(int daysBefore, Competition c) {
    final dist = c.distanceKm.toStringAsFixed(0);
    switch (daysBefore) {
      case 14:
        return '«${c.name}» через 2 недели ($dist км). Пик объёма: длительная + интервалы по плану.';
      case 7:
        return '«${c.name}» через неделю. Снижай объём на 30%, интенсивность оставь.';
      case 3:
        return '«${c.name}» через 3 дня. Только лёгкие, сон 8 ч, углеводы.';
      case 1:
        return '«${c.name}» завтра! Отдых, проверь снаряжение, ложись раньше.';
      case 0:
        return '«${c.name}» сегодня! Удачи на старте!';
      default:
        return '«${c.name}» через $daysBefore дн. Держи план подготовки.';
    }
  }

  DateTime _atMorning(DateTime day, int hour, int minute) {
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  /// Планирует пуши этапов: 14/7/3/1 дней в 9:00, старт тейпера, день гонки в 8:00.
  Future<List<int>> _scheduleStages(Competition c) async {
    final svc = LocalNotificationService.instance;
    final base = _notifBaseId(c);
    final ids = <int>[];
    final stages = <({int daysBefore, String title, DateTime when})>[
      (daysBefore: 14, title: 'До старта 14 дней', when: _atMorning(c.date.subtract(const Duration(days: 14)), 9, 0)),
      (daysBefore: 7, title: 'До старта 7 дней', when: _atMorning(c.date.subtract(const Duration(days: 7)), 9, 0)),
      (daysBefore: 3, title: 'До старта 3 дня', when: _atMorning(c.date.subtract(const Duration(days: 3)), 9, 0)),
      (daysBefore: 1, title: 'Старт завтра', when: _atMorning(c.date.subtract(const Duration(days: 1)), 9, 0)),
      (
        daysBefore: -1,
        title: 'Начало тейпера',
        when: _atMorning(c.date.subtract(Duration(days: _restDays(c.distanceKm))), 9, 0)
      ),
      (daysBefore: 0, title: 'День гонки', when: _atMorning(c.date, 8, 0)),
    ];
    var idx = 0;
    for (final s in stages) {
      final ok = await svc.scheduleCompetitionStage(
        id: base + idx,
        title: '${c.name} • ${s.title}',
        body: _stageBody(s.daysBefore, c),
        when: s.when,
      );
      if (ok) ids.add(base + idx);
      idx++;
    }
    return ids;
  }

  Future<void> _cancelStages(Competition c) async {
    if (c.notifIds.isEmpty) return;
    await LocalNotificationService.instance.cancelCompetitionNotifications(c.notifIds);
  }

  static const _calendarChannel = MethodChannel('com.zapfit/calendar');

  /// Открывает системный календарь с заполненным событием «Старт в 8:00».
  /// Разрешение не требуется — пользователь подтверждает в своём приложении календаря.
  Future<void> _addToCalendar(Competition c) async {
    try {
      final begin = DateTime(c.date.year, c.date.month, c.date.day, 8, 0);
      // Грубая оценка длительности: темп 6:00/км, минимум 1 час.
      final minutes = (c.distanceKm * 6).clamp(60, 600).toInt();
      final end = begin.add(Duration(minutes: minutes));
      final ok = await _calendarChannel.invokeMethod<bool>('addEvent', {
        'title': 'Старт: ${c.name}',
        'description': '${c.name}, ${c.distanceKm.toStringAsFixed(1)} км. Тейпер с ${_restDays(c.distanceKm)} дн. отдыха.',
        'beginMs': begin.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      });
      if (mounted && ok != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Календарь не найден на устройстве')),
        );
      }
    } catch (e) {
      debugPrint('Calendar addEvent error: $e');
    }
  }

  Future<void> _finishCompetition() async {
    final comp = _selected;
    if (comp == null || comp.finished) return;
    final placeCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Закрыть соревнование'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: placeCtrl, decoration: const InputDecoration(labelText: 'Место (например 5)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: totalCtrl, decoration: const InputDecoration(labelText: 'Всего участников', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Результат (ММ:СС или Ч:ММ:СС)', border: OutlineInputBorder()), keyboardType: TextInputType.datetime),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Финишировать')),
        ],
      ),
    );
    if (result != true) return;
    int? secs;
    final parts = timeCtrl.text.trim().split(':').map((p) => int.tryParse(p) ?? -1).toList();
    if (!parts.any((p) => p < 0)) {
      if (parts.length == 2) secs = parts[0] * 60 + parts[1];
      if (parts.length == 3) secs = parts[0] * 3600 + parts[1] * 60 + parts[2];
    }
    await _cancelStages(comp);
    setState(() {
      final i = _competitions.indexWhere((c) => c.id == comp.id);
      if (i >= 0) {
        _competitions[i] = comp.copyWith(
          finished: true,
          place: int.tryParse(placeCtrl.text.trim()),
          totalParticipants: int.tryParse(totalCtrl.text.trim()),
          resultTimeSec: secs,
          notifIds: const [],
        );
        _selectedId = _competitions[i].id;
      }
    });
    await _saveCompetitions();
  }

  Competition? get _selected {
    if (_selectedId == null) return null;
    try {
      return _competitions.firstWhere((c) => c.id == _selectedId);
    } catch (_) {
      return null;
    }
  }

  double _requiredWeeklyKm(double distKm) {
    if (distKm <= 5) return 20;
    if (distKm <= 10) return 30;
    if (distKm <= 21.5) return 45;
    return 60;
  }

  int _restDays(double distKm) {
    if (distKm <= 5) return 2;
    if (distKm <= 10) return 3;
    if (distKm <= 21.5) return 7;
    return 14;
  }

  Future<void> _computeStats() async {
    final comp = _selected;
    if (comp == null) return;
    try {
      final repo = LocalActivityRepository.instance;
      final all = await repo.getActivities();
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 28));
      final recent = all.where((a) => a.startedAt.isAfter(from)).toList();

      double totalKm = 0;
      double longest = 0;
      DateTime? lastDate;
      for (final a in recent) {
        final km = a.distanceMeters / 1000;
        totalKm += km;
        if (km > longest) longest = km;
        if (lastDate == null || a.startedAt.isAfter(lastDate)) {
          lastDate = a.startedAt;
        }
      }
      final avgWeekly = totalKm / 4;
      final required = _requiredWeeklyKm(comp.distanceKm);
      final readiness = required <= 0 ? 0.0 : (avgWeekly / required).clamp(0.0, 1.0);
      final daysSince = lastDate == null ? -1 : now.difference(lastDate).inDays;

      if (!mounted) return;
      setState(() {
        _avgWeeklyKm = avgWeekly;
        _activities28d = recent.length;
        _longestKm = longest;
        _daysSinceLast = daysSince;
        _readiness = readiness;
        _suggestions = _buildSuggestions(
          comp: comp,
          readiness: readiness,
          longestKm: longest,
          activities: recent.length,
        );
      });
    } catch (_) {}
  }

  List<String> _buildSuggestions({
    required Competition comp,
    required double readiness,
    required double longestKm,
    required int activities,
  }) {
    if (activities == 0) {
      return [
        'База: 3 лёгкие тренировки по 5 км в неделю',
        'Длительная: 8 км в conversational темпе',
        'Отдых: минимум 1 полный день между тренировками',
      ];
    }
    if (readiness >= 1.0) {
      return [
        'Тейпер: снижай объём на 30–40%, интенсивность оставь',
        'Контрольная: ${((comp.distanceKm / 3).clamp(3, 12)).toStringAsFixed(0)} км в целевом темпе',
        'Отдых: ${_restDays(comp.distanceKm)} дн. перед стартом без нагрузки',
      ];
    }
    final longTarget = (longestKm * 1.2).clamp(6, comp.distanceKm * 0.7);
    return [
      'Длительная: ${longTarget.toStringAsFixed(0)} км (было макс. ${longestKm.toStringAsFixed(0)} км)',
      'Интервалы: 6 × 800 м через 400 м трусцы, 1 раз в неделю',
      'Восстановительная: 5 км очень легко после каждой жёсткой',
    ];
  }

  Future<void> _runAiAnalysis() async {
    final comp = _selected;
    if (comp == null) return;
    setState(() {
      _aiLoading = true;
      _aiAnalysis = null;
    });
    try {
      final daysLeft = comp.date.difference(DateTime.now()).inDays;
      final summary =
          'Соревнование: ${comp.name}, дистанция ${comp.distanceKm.toStringAsFixed(1)} км, дней до старта: $daysLeft. '
          'Средний недельный объём за 28 дней: ${_avgWeeklyKm.toStringAsFixed(1)} км, тренировок: $_activities28d, '
          'максимальная длительная: ${_longestKm.toStringAsFixed(1)} км, дней с последней тренировки: ${_daysSinceLast < 0 ? 'нет данных' : _daysSinceLast}. '
          'Готовность: ${(_readiness * 100).toStringAsFixed(0)}%.';
      final text = await OllamaService.instance.generatePreparationAnalysis(summary: summary);
      if (mounted) setState(() => _aiAnalysis = text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ИИ анализ не удался: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final distCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 30));
    bool addToCalendar = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Новое соревнование'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: distCtrl, decoration: const InputDecoration(labelText: 'Дистанция (км)', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month),
                  title: Text('${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'),
                  subtitle: const Text('Дата старта'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
                TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Заметка (необязательно)', border: OutlineInputBorder())),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Добавить в календарь', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Старт в 8:00, откроется приложение календаря', style: TextStyle(fontSize: 12)),
                  value: addToCalendar,
                  onChanged: (v) => setDialogState(() => addToCalendar = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Добавить')),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final dist = double.tryParse(distCtrl.text.replaceAll(',', '.')) ?? 10.0;
      var comp = Competition(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameCtrl.text.trim(),
        date: date,
        distanceKm: dist,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      final ids = await _scheduleStages(comp);
      comp = comp.copyWith(notifIds: ids);
      setState(() {
        _competitions.add(comp);
        _competitions.sort((a, b) => a.date.compareTo(b.date));
        _selectedId = comp.id;
      });
      await _saveCompetitions();
      await _computeStats();
      if (mounted && ids.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Напоминания запланированы: ${ids.length}')),
        );
      }
      if (addToCalendar && mounted) {
        await _addToCalendar(comp);
      }
    }
  }

  Future<void> _deleteSelected() async {
    final comp = _selected;
    if (comp == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить соревнование?'),
        content: Text('"${comp.name}" будет удалено'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm == true) {
      await _cancelStages(comp);
      setState(() {
        _competitions.removeWhere((c) => c.id == comp.id);
        _selectedId = _competitions.isNotEmpty ? _competitions.first.id : null;
        _aiAnalysis = null;
      });
      await _saveCompetitions();
      await _computeStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: _competitions.isEmpty ? _buildEmpty(theme) : _buildContent(theme),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_competition',
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 64, color: theme.colorScheme.outline.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('Нет соревнований', style: TextStyle(color: theme.colorScheme.outline, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Добавьте старт — посчитаем дни, отдых и готовность\nпо вашим последним тренировкам',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline.withOpacity(0.6), fontSize: 13)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add),
            label: const Text('Добавить соревнование'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final comp = _selected!;
    final daysLeft = comp.date.difference(DateTime.now()).inDays;
    final rest = _restDays(comp.distanceKm);
    final taperDate = comp.date.subtract(Duration(days: rest));
    final pct = (_readiness * 100).clamp(0, 100);
    final color = pct >= 100 ? Colors.green : pct >= 60 ? Colors.orange : theme.colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_competitions.length > 1)
          DropdownButtonFormField<String>(
            value: _selectedId,
            decoration: const InputDecoration(labelText: 'Соревнование', border: OutlineInputBorder()),
            items: _competitions
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) async {
              if (v == null) return;
              setState(() {
                _selectedId = v;
                _aiAnalysis = null;
              });
              await _computeStats();
            },
          ),
        if (_competitions.length > 1) const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: theme.colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(comp.name,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    if (comp.finished)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Финиш', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: _deleteSelected,
                    ),
                  ],
                ),
                if (comp.finished && comp.place != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Место ${comp.place}${comp.totalParticipants != null ? ' из ${comp.totalParticipants}' : ''}'
                      '${comp.resultTimeSec != null ? ' • ${_formatSecs(comp.resultTimeSec!)}' : ''}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                Text('${comp.distanceKm.toStringAsFixed(1)} км • ${comp.date.day.toString().padLeft(2, '0')}.${comp.date.month.toString().padLeft(2, '0')}.${comp.date.year}',
                    style: theme.textTheme.bodyMedium),
                if (comp.note != null && comp.note!.isNotEmpty)
                  Text(comp.note!, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _countdownBox(theme, '$daysLeft', 'дней до старта')),
                    const SizedBox(width: 8),
                    Expanded(child: _countdownBox(theme, '$rest', 'дней отдыха')),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Тейпер с ${taperDate.day.toString().padLeft(2, '0')}.${taperDate.month.toString().padLeft(2, '0')} — снижай объём',
                    style: theme.textTheme.bodySmall),
                if (!comp.finished) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _finishCompetition,
                      icon: const Icon(Icons.flag, size: 18),
                      label: const Text('Закрыть соревнование (место)'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionHeader(theme, 'Готовность по последним тренировкам'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(pct >= 100 ? Icons.check_circle : Icons.trending_up, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('Готовность ${pct.toStringAsFixed(0)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.outlineVariant.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Неделя: ${_avgWeeklyKm.toStringAsFixed(1)} км (надо ${_requiredWeeklyKm(comp.distanceKm).toStringAsFixed(0)}) • '
                  'Тренировок за 28 дн.: $_activities28d • '
                  'Макс. длительная: ${_longestKm.toStringAsFixed(1)} км • '
                  '${_daysSinceLast < 0 ? 'тренировок нет' : 'последняя $_daysSinceLast дн. назад'}',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionHeader(theme, 'План добора'),
        ..._suggestions.map((s) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: ListTile(
                leading: Icon(Icons.fitness_center, color: theme.colorScheme.primary, size: 20),
                title: Text(s, style: const TextStyle(fontSize: 14)),
              ),
            )),
        const SizedBox(height: 12),
        _sectionHeader(theme, 'ИИ анализ'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_aiAnalysis != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_aiAnalysis!, style: const TextStyle(fontSize: 14)),
                  ),
                FilledButton.tonalIcon(
                  onPressed: _aiLoading ? null : _runAiAnalysis,
                  icon: _aiLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.psychology, size: 18),
                  label: Text(_aiLoading ? 'Анализ...' : 'Получить ИИ разбор'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 72),
      ],
    );
  }

  String _formatSecs(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _countdownBox(ThemeData theme, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(),
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.outline, letterSpacing: 1.2)),
    );
  }
}
