import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:endurain/core/di/service_locator.dart';
import 'package:endurain/core/models/workouts_models.dart';
import 'package:endurain/core/services/app_settings_controller.dart';
import 'package:endurain/core/services/bluetooth_sensor_service.dart';
import 'package:endurain/core/services/catalog_service.dart';
import 'package:endurain/core/services/workouts_service.dart';
import 'package:endurain/features/workouts/widgets/exercise_info_dialog.dart';

/// Live strength workout recording screen.
///
/// Full-screen session player: total timer with start/pause/finish, current
/// exercise with progress (3/6), per-set weight/reps logging with an automatic
/// circular rest countdown between sets, live BLE heart rate chip, and a
/// finish summary (edit duration/comment, save + optional auto-sync).
class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({super.key, required this.plan});

  final WorkoutPlan plan;

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  final WorkoutsService _service = WorkoutsService.instance;

  // ---- session timer ----
  late final Stopwatch _stopwatch;
  Timer? _uiTick;
  bool _paused = false;

  // ---- exercise state ----
  late final List<_ExerciseState> _exercises;
  int _currentExercise = 0;

  // ---- rest timer ----
  int _restSecondsLeft = 0;
  int _restSecondsTotal = 60;
  Timer? _restTick;

  // ---- BLE HR ----
  StreamSubscription<int>? _hrSub;
  int? _bpm;

  // ---- finish ----
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _uiTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_paused) setState(() {});
    });
    _exercises = [
      for (final ex in widget.plan.exercises)
        _ExerciseState(
          name: ex.name,
          wgerId: ex.wgerExerciseId,
          defaultWeight: ex.targetWeightKg,
          defaultReps: int.tryParse(ex.targetReps ?? ''),
          restSeconds: ex.restSeconds ?? 60,
          sets: [
            for (var s = 0; s < (ex.targetSets ?? 3); s++)
              _SetInput(
                weight: ex.targetWeightKg,
                reps: int.tryParse(ex.targetReps ?? ''),
              ),
          ],
        ),
    ];
    final ble = serviceLocator<BluetoothSensorService>();
    _bpm = ble.lastHeartRate;
    _hrSub = ble.heartRate.listen((bpm) {
      if (bpm > 0 && mounted) setState(() => _bpm = bpm);
    });
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    _uiTick?.cancel();
    _restTick?.cancel();
    _hrSub?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    super.dispose();
  }

  String _fmtElapsed() {
    final s = _stopwatch.elapsed;
    final m = s.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = s.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = s.inHours;
    return h > 0 ? '$h:$m:$sec' : '$m:$sec';
  }

  void _togglePause() {
    setState(() {
      if (_paused) {
        _paused = false;
        _stopwatch.start();
      } else {
        _paused = true;
        _stopwatch.stop();
      }
    });
  }

  void _startRest(int seconds) {
    _restTick?.cancel();
    setState(() {
      _restSecondsTotal = seconds;
      _restSecondsLeft = seconds;
    });
    _restTick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_restSecondsLeft > 0) {
        setState(() => _restSecondsLeft--);
      } else {
        t.cancel();
        // короткая вибрация по окончании отдыха
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _skipRest() {
    _restTick?.cancel();
    setState(() => _restSecondsLeft = 0);
  }

  void _logSet(_ExerciseState ex, int index) {
    HapticFeedback.selectionClick();
    setState(() => ex.logged.add(index));
    _startRest(ex.restSeconds);
  }

  Color _hrColor(int bpm) {
    if (bpm < 60) return Colors.blue;
    if (bpm < 100) return Colors.green;
    if (bpm < 140) return Colors.orange;
    if (bpm < 170) return Colors.deepOrange;
    return Colors.red;
  }

  // ---- finish ----

  Future<void> _confirmFinish() async {
    final theme = Theme.of(context);
    final anySet = _exercises.any((e) => e.sets.any((s) => s.weight != null || s.reps != null));
    if (!anySet) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Отметьте хотя бы один подход (вес или повторы)'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final durationMin = (_stopwatch.elapsedMilliseconds / 60000).roundToDouble();
    final totalSets = _exercises.fold<int>(0, (sum, e) => sum + e.logged.length);
    final volumeKg = _exercises.fold<double>(
        0, (sum, e) => sum + e.logged.fold<double>(0, (s, i) {
              final set = e.sets[i];
              return s + (set.weight ?? 0) * (set.reps ?? 0);
            }));
    final rpes = _exercises
        .expand((e) => e.sets)
        .map((s) => s.rpe)
        .whereType<double>()
        .toList();
    final avgRpe = rpes.isNotEmpty ? rpes.reduce((a, b) => a + b) / rpes.length : 6.0;
    final tss = durationMin > 0 ? durationMin * avgRpe / 10 : 0.0;

    final durationCtrl = TextEditingController(
        text: durationMin > 0 ? durationMin.toStringAsFixed(0) : '');
    final commentCtrl = TextEditingController();
    final autoSync = AppSettingsController.instance.strengthAutoSyncEnabled;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Завершить тренировку', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _summaryTile(theme, 'Время', _fmtElapsed())),
                const SizedBox(width: 8),
                Expanded(child: _summaryTile(theme, 'Подходы', '$totalSets')),
                const SizedBox(width: 8),
                Expanded(child: _summaryTile(
                    theme, 'Объём', '${volumeKg.toStringAsFixed(0)} кг')),
                const SizedBox(width: 8),
                Expanded(child: _summaryTile(
                    theme, 'TSS', tss.toStringAsFixed(0))),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Длительность, мин',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: commentCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              StatefulBuilder(builder: (ctx, setSheet) {
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: autoSync,
                  title: const Text(
                      'Автосинхронизация силовых (отправить сразу)',
                      style: TextStyle(fontSize: 13)),
                  onChanged: (v) {
                    setSheet(() {});
                    AppSettingsController.instance
                        .setStrengthAutoSyncEnabled(v ?? false);
                  },
                );
              }),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.save),
                  label: const Text('Сохранить'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );

    if (saved != true) return;
    await _saveSession(durationCtrl, commentCtrl);
  }

  Widget _summaryTile(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _saveSession(
    TextEditingController durationCtrl,
    TextEditingController commentCtrl,
  ) async {
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final sets = <WorkoutSetLog>[];
      for (final ex in _exercises) {
        var setNo = 1;
        for (final i in ex.logged) {
          final s = ex.sets[i];
          sets.add(WorkoutSetLog(
            exerciseName: ex.name,
            wgerExerciseId: ex.wgerId,
            setNo: setNo++,
            weightKg: s.weight,
            reps: s.reps,
            rpe: s.rpe,
            completed: true,
          ));
        }
      }
      final session = WorkoutSession(
        planId: widget.plan.id,
        date:
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        durationMin: double.tryParse(durationCtrl.text),
        calories: null,
        comment: commentCtrl.text.isNotEmpty ? commentCtrl.text : null,
        sets: sets,
      );
      final saved = await _service.logSession(session);

      // Автосинхронизация силовых: сразу дожимаем офлайн-очередь на сервер.
      var sentNow = saved != null;
      if (!sentNow &&
          AppSettingsController.instance.strengthAutoSyncEnabled) {
        try {
          final confirmed = await _service.syncPending();
          sentNow = confirmed > 0;
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sentNow
            ? 'Сессия сохранена и отправлена на сервер'
            : 'Сохранено локально — отправится при следующей связи'),
        backgroundColor: sentNow ? Colors.green : Colors.orange,
      ));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка сохранения: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ex = _exercises[_currentExercise];

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _askExit(theme),
          ),
          title: Text(widget.plan.name, overflow: TextOverflow.ellipsis),
          actions: [
            // live HR chip
            if (_bpm != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.favorite, color: _hrColor(_bpm!), size: 16),
                    const SizedBox(width: 4),
                    Text('$_bpm',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _hrColor(_bpm!))),
                  ]),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // total timer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                Text(_fmtElapsed(),
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _togglePause,
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                  tooltip: _paused ? 'Продолжить' : 'Пауза',
                ),
                const Spacer(),
                Text('${_currentExercise + 1}/${_exercises.length}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
              ]),
            ),
            const Divider(height: 1),
            // exercise
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(ex.name,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      if (ex.wgerId != null)
                        IconButton(
                          tooltip: 'Описание упражнения',
                          icon: const Icon(Icons.info_outline),
                          onPressed: () {
                            final cat = CatalogService.instance.byId(ex.wgerId!);
                            if (cat != null && mounted) {
                              showExerciseInfoDialog(context, cat);
                            }
                          },
                        ),
                    ]),
                    if (ex.restSeconds > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Отдых между подходами: ${ex.restSeconds} с',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ),
                    const SizedBox(height: 12),
                    ...[
                      for (var i = 0; i < ex.sets.length; i++)
                        _setRow(ex, i, theme),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => ex.sets.add(_SetInput(
                                weight: ex.defaultWeight,
                                reps: ex.defaultReps,
                              ))),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Добавить подход'),
                    ),
                  ],
                ),
              ),
            ),
            // rest timer strip
            if (_restSecondsLeft > 0)
              _buildRestStrip(theme),
          ],
        ),
        // nav + finish
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _currentExercise > 0
                      ? () => setState(() => _currentExercise--)
                      : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Назад'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _currentExercise < _exercises.length - 1
                      ? () => setState(() => _currentExercise++)
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Далее'),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _saving ? null : _confirmFinish,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                icon: const Icon(Icons.check),
                label: const Text('Финиш'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildRestStrip(ThemeData theme) {
    final progress = _restSecondsTotal > 0
        ? _restSecondsLeft / _restSecondsTotal
        : 0.0;
    return Container(
      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(children: [
            CircularProgressIndicator(value: progress, strokeWidth: 4),
            Center(
              child: Text('$_restSecondsLeft',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        const Text('Отдых', style: TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        TextButton(onPressed: _skipRest, child: const Text('Пропустить')),
      ]),
    );
  }

  Widget _setRow(_ExerciseState ex, int index, ThemeData theme) {
    final s = ex.sets[index];
    final logged = ex.logged.contains(index);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: logged ? Colors.green : theme.colorScheme.outlineVariant,
          width: logged ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          SizedBox(
            width: 28,
            child: Text('${index + 1}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _numField(
              theme,
              value: s.weight?.toString(),
              hint: 'кг',
              onChanged: (v) => s.weight = double.tryParse(v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _numField(
              theme,
              value: s.reps?.toString(),
              hint: 'повторы',
              onChanged: (v) => s.reps = int.tryParse(v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _numField(
              theme,
              value: s.rpe?.toString(),
              hint: 'RPE',
              onChanged: (v) => s.rpe = double.tryParse(v),
            ),
          ),
          IconButton(
            tooltip: 'Записать подход',
            onPressed: () => _logSet(ex, index),
            icon: Icon(logged ? Icons.check_circle : Icons.play_circle_outline,
                color: logged ? Colors.green : theme.colorScheme.primary),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: () {
              setState(() {
                ex.sets.removeAt(index);
                ex.logged.remove(index);
              });
            },
            icon: const Icon(Icons.remove_circle_outline, size: 20),
          ),
        ]),
      ),
    );
  }

  Widget _numField(
    ThemeData theme, {
    String? value,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: value,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
      ],
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      onChanged: onChanged,
    );
  }

  Future<void> _askExit(ThemeData theme) async {
    final elapsed = _stopwatch.elapsed;
    final hasData = _exercises.any((e) => e.logged.isNotEmpty);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти без записи?'),
        content: Text(hasData
            ? 'Есть записанные подходы (${elapsed.inMinutes} мин). Сохранить сессию?'
            : 'Прошло ${elapsed.inMinutes} мин. Тренировка не будет сохранена.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'stay'),
              child: const Text('Остаться')),
          if (hasData)
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const Text('Сохранить')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'exit'),
              child: const Text('Выйти')),
        ],
      ),
    );
    if (action == 'exit') {
      if (mounted) Navigator.pop(context);
    } else if (action == 'save') {
      if (mounted) await _confirmFinish();
    }
  }
}

class _SetInput {
  double? weight;
  int? reps;
  double? rpe;
  _SetInput({this.weight, this.reps, this.rpe});
}

class _ExerciseState {
  final String name;
  final int? wgerId;
  final double? defaultWeight;
  final int? defaultReps;
  final int restSeconds;
  final List<_SetInput> sets;
  final List<int> logged = [];

  _ExerciseState({
    required this.name,
    required this.wgerId,
    required this.defaultWeight,
    required this.defaultReps,
    required this.restSeconds,
    required this.sets,
  });
}
