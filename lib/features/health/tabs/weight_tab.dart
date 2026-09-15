import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/core/utils/body_composition_calculator.dart';
import 'package:zapfit/features/health/tabs/weight_history_screen.dart';
import 'package:zapfit/l10n/app_localizations.dart';

class WeightTab extends StatelessWidget {
  const WeightTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, _) {
        final settings = AppSettingsController.instance;
        
        return Consumer<HealthService>(
          builder: (context, service, child) {
            final records = service.weightRecords;
            final latestWeight = records.isNotEmpty ? records.first : null;

            return Scaffold(
              body: RefreshIndicator(
                onRefresh: () => service.autoImportFromHealthConnect(force: true),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (latestWeight != null) ...[
                      _buildBodyCompositionCard(context, latestWeight, settings),
                      const SizedBox(height: 24),
                      // === ZAPFIT metrics ===
                      _buildAdvancedMetricsCard(context, latestWeight),
                      const SizedBox(height: 24),
                    ],
                    if (records.length >= 2) ...[
                      Text('${l10n.healthWeight} — график', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 10),
                      _buildWeightChart(context, records),
                      const SizedBox(height: 24),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.history, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        if (service.isSyncing)
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (records.isEmpty && !service.isLoading)
                      Center(child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(l10n.noWeightRecords),
                      ))
                    else ...[
                      ...records.take(7).map((r) => _buildWeightTile(context, r, service)),
                      if (records.length > 7)
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => WeightHistoryScreen(records: records)),
                          ),
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('Показать всё'),
                        ),
                    ],
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () => _showAddWeightDialog(context, service),
                child: const Icon(Icons.add),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBodyCompositionCard(BuildContext context, WeightRecord r, AppSettingsController settings) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final heightCm = settings.userHeight;
    final gender = settings.userGender == 'male' ? 1 : 0;
    final age = settings.userAge ?? 25;

    if (heightCm <= 0) {
      return Card(
        elevation: 0,
        color: Colors.amber.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.amber.withOpacity(0.3)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.amber),
              SizedBox(height: 8),
              Text(
                'Укажите рост и дату рождения в профиле для анализа состава тела',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate body composition (always recalculate for fresh display)
    BodyCompositionResult? composition;
    if (age >= 6) {
      composition = BodyCompositionCalculator.calculate(
        weightKg: r.weight,
        heightCm: heightCm,
        age: age,
        gender: gender,
      );
    }

    final bmi = r.bmi ?? (r.weight / ((heightCm / 100) * (heightCm / 100)));

    String bmiCategory;
    Color bmiColor;
    if (bmi < 18.5) {
      bmiCategory = 'Недостаточный';
      bmiColor = Colors.blue;
    } else if (bmi < 25) {
      bmiCategory = 'Норма';
      bmiColor = Colors.green;
    } else if (bmi < 30) {
      bmiCategory = 'Избыточный';
      bmiColor = Colors.orange;
    } else {
      bmiCategory = 'Ожирение';
      bmiColor = Colors.red;
    }

    // Body score from composition or stored
    final int bodyScore = composition?.bodyScore ?? r.bodyScore ?? 0;
    final BodyScoreGrade scoreGrade = composition?.bodyScoreGrade ?? BodyScoreGrade.normal;
    final String scoreLabel = composition?.bodyScoreLabel ?? '';
    final Color scoreColor = _scoreColor(bodyScore);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_weight_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Анализ состава тела', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 16),
            // Body Score Gauge
            if (bodyScore > 0) ...[
              Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: bodyScore / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$bodyScore', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: scoreColor)),
                          Text('балл', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (scoreLabel.isNotEmpty)
                Center(
                  child: Text(scoreLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: scoreColor)),
                ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
            ],
            // Weight + BMI row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _analysisStat('Вес', '${r.weight}', 'кг'),
                _analysisStat('ИМТ', bmi.toStringAsFixed(1), bmiCategory),
              ],
            ),
            const SizedBox(height: 16),
            // Body composition metrics
            if (composition != null) ...[
              _metricRow('Жир тела', '${composition.bodyFatPercentage.toStringAsFixed(1)}%', composition.bodyFatLabel, _levelColor(composition.bodyFatLevel)),
              _metricRow('Мышцы', '${composition.muscleMassKg.toStringAsFixed(1)} кг', composition.muscleLabel, _muscleColor(composition.muscleLevel)),
              _metricRow('Кости', '${composition.boneMassKg.toStringAsFixed(1)} кг', composition.boneLabel, _boneColor(composition.boneLevel)),
              _metricRow('Вода', '${composition.bodyWaterPercentage.toStringAsFixed(1)}%', composition.waterLabel, _waterColor(composition.waterLevel)),
              _metricRow('Висц. жир', '${composition.visceralFatLevel}', composition.visceralFatLabel, _visceralColor(composition.visceralFatGrade)),
              _metricRow('BMR', '${composition.bmr} ккал', composition.bmrLabel, theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                'Тип фигуры: ${BodyCompositionCalculator.bodyShapeTypeName(composition.bodyShapeType)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ] else ...[
              Text(
                settings.userBirthDate == null
                    ? 'Укажите дату рождения для расчёта состава тела'
                    : 'Недостаточно данных для расчёта',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // === ZAPFIT metrics ===
  Widget _buildAdvancedMetricsCard(BuildContext context, WeightRecord r) {
    final theme = Theme.of(context);
    final settings = AppSettingsController.instance;
    final heightCm = settings.userHeight;
    final male = settings.userGender == 'male';

    if (heightCm <= 0) {
      return Card(
        elevation: 0,
        color: Colors.amber.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.amber.withOpacity(0.3)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.amber),
              SizedBox(height: 8),
              Text(
                'Укажите рост в профиле для расчёта доп. метрик',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final weight = r.weight;
    final lbm = _boerLbm(weight, heightCm, male);
    final navy = _navyBodyFat(weightKg: weight, heightCm: heightCm, male: male);
    final ymca = _ymcaBodyFat(weightKg: weight, male: male);
    final whr = _whr();
    final whtr = _whtr(heightCm: heightCm);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Дополнительные метрики',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 8),
            _metricRow('Безжировая масса (LBM, Boer)', lbm != null ? '${lbm.toStringAsFixed(1)} кг' : 'Нет данных', '', theme.colorScheme.primary),
            _metricRow('Жир тела (Navy)', _fmtOrNd(navy), 'Нет данных', Colors.grey),
            _metricRow('Жир тела (YMCA)', _fmtOrNd(ymca), 'Нет данных', Colors.grey),
            _metricRow('WHR (талия/бёдра)', _fmtOrNd(whr), 'Нет данных', Colors.grey),
            _metricRow('WHtR (талия/рост)', _fmtOrNd(whtr), 'Нет данных', Colors.grey),
          ],
        ),
      ),
    );
  }

  String _fmtOrNd(double? v, [int digits = 1]) => v == null ? 'Нет данных' : v.toStringAsFixed(digits);

  // Boer formula for Lean Body Mass (kg)
  double? _boerLbm(double weightKg, double heightCm, bool male) {
    if (weightKg <= 0 || heightCm <= 0) return null;
    return male
        ? 0.407 * weightKg + 0.267 * heightCm - 19.2
        : 0.252 * weightKg + 0.473 * heightCm - 48.3;
  }

  // US Navy body fat % — requires waist/neck (and hip for women). Null = no data.
  double? _navyBodyFat({
    required double weightKg,
    required double heightCm,
    required bool male,
    double? waistCm,
    double? hipCm,
    double? neckCm,
  }) {
    if (waistCm == null || neckCm == null) return null;
    if (male) {
      final v = 495 /
              (1.0324 - 0.19077 * (log(waistCm - neckCm) / ln10) +
                  0.15456 * (log(heightCm) / ln10)) -
          450;
      return v.clamp(2.0, 60.0);
    } else {
      if (hipCm == null) return null;
      final v = 495 /
              (1.29579 - 0.35004 * (log(waistCm + hipCm - neckCm) / ln10) +
                  0.22100 * (log(heightCm) / ln10)) -
          450;
      return v.clamp(2.0, 60.0);
    }
  }

  // YMCA body fat % — requires waist circumference. Null = no data.
  double? _ymcaBodyFat({required double weightKg, required bool male, double? waistCm}) {
    if (waistCm == null || weightKg <= 0) return null;
    final v = male
        ? 100 * (waistCm * 0.1542 - weightKg * 0.0825 + 24.5) / weightKg
        : 100 * (waistCm * 0.1830 - weightKg * 0.0825 + 34.89) / weightKg;
    return v.clamp(2.0, 60.0);
  }

  double? _whr({double? waistCm, double? hipCm}) {
    if (waistCm == null || hipCm == null || hipCm <= 0) return null;
    return waistCm / hipCm;
  }

  double? _whtr({double? waistCm, required double heightCm}) {
    if (waistCm == null || heightCm <= 0) return null;
    return waistCm / heightCm;
  }

  Widget _analysisStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
            children: [
              TextSpan(text: value),
              TextSpan(text: ' $unit', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricRow(String label, String value, String level, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(level, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 80) return Colors.lightGreen;
    if (score >= 70) return Colors.orange;
    if (score >= 50) return Colors.deepOrange;
    return Colors.red;
  }

  Color _levelColor(int level) {
    // Body fat level: 0=low, 1=slightlyLower, 2=normal, 3=slightlyHigher, 4=high
    if (level == 2) return Colors.green;
    if (level == 1 || level == 3) return Colors.orange;
    return Colors.red;
  }

  Color _muscleColor(MuscleLevel level) {
    if (level == MuscleLevel.normal) return Colors.green;
    if (level == MuscleLevel.high) return Colors.blue;
    return Colors.orange;
  }

  Color _boneColor(BoneLevel level) {
    if (level == BoneLevel.normal) return Colors.green;
    return Colors.orange;
  }

  Color _waterColor(WaterLevel level) {
    if (level == WaterLevel.normal) return Colors.blue;
    return Colors.orange;
  }

  Color _visceralColor(VisceralFatLevel level) {
    if (level == VisceralFatLevel.normal) return Colors.green;
    if (level == VisceralFatLevel.slightlyHigher) return Colors.orange;
    return Colors.red;
  }

  Widget _buildWeightTile(BuildContext context, WeightRecord r, HealthService service) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.monitor_weight_outlined, color: Colors.blue, size: 20),
      ),
      title: Text('${r.weight} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(DateFormat('dd.MM.yyyy').format(r.date)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            r.isSynced ? Icons.cloud_done : Icons.cloud_upload_outlined,
            color: r.isSynced ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteDialog(context, () => service.deleteWeightRecord(r.id!));
              } else if (value == 'edit') {
                _showAddWeightDialog(context, service, existingRecord: r);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit), title: Text(l10n.edit), contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: Text(l10n.delete, style: const TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChart(BuildContext context, List<WeightRecord> records) {
    final spots = records.reversed.toList().asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weight);
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.only(right: 16, top: 16),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    Theme.of(context).colorScheme.primary.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddWeightDialog(BuildContext context, HealthService service, {WeightRecord? existingRecord}) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: existingRecord?.weight.toString() ?? '');
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingRecord == null ? l10n.addWeight : l10n.editEntry),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '75.5',
            suffixText: 'kg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text.replaceAll(',', '.'))),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      try {
        final settings = AppSettingsController.instance;
        final heightCm = settings.userHeight;
        final gender = settings.userGender == 'male' ? 1 : 0;
        final age = settings.userAge ?? 25;
        final bmi = heightCm > 0 ? result / ((heightCm / 100) * (heightCm / 100)) : null;

        BodyCompositionResult? composition;
        if (heightCm > 0 && age >= 6) {
          composition = BodyCompositionCalculator.calculate(
            weightKg: result,
            heightCm: heightCm,
            age: age,
            gender: gender,
          );
        }

        final record = WeightRecord(
          weight: result,
          date: DateTime.now(),
          isSynced: false,
          bmi: bmi,
          bodyFatPercentage: composition?.bodyFatPercentage,
          muscleMassKg: composition?.muscleMassKg,
          boneMassKg: composition?.boneMassKg,
          bodyWaterPercentage: composition?.bodyWaterPercentage,
          visceralFatLevel: composition?.visceralFatLevel,
          bmr: composition?.bmr,
          bodyScore: composition?.bodyScore,
        );

        if (existingRecord != null) {
          await service.updateWeight(existingRecord.copyWith(
            weight: result,
            isSynced: false,
            bmi: bmi,
            bodyFatPercentage: composition?.bodyFatPercentage,
            muscleMassKg: composition?.muscleMassKg,
            boneMassKg: composition?.boneMassKg,
            bodyWaterPercentage: composition?.bodyWaterPercentage,
            visceralFatLevel: composition?.visceralFatLevel,
            bmr: composition?.bmr,
            bodyScore: composition?.bodyScore,
          ));
        } else {
          await service.addWeightWithComposition(record);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(existingRecord != null ? l10n.editEntry : l10n.addWeight), duration: const Duration(seconds: 1)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showDeleteDialog(BuildContext context, VoidCallback onConfirm) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${l10n.deleteRecord}?'),
        content: Text(l10n.deleteRecordConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton.tonal(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
