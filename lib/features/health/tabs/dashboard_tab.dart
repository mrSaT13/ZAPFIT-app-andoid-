import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zapfit/core/services/health_service.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/core/utils/vo2max_calculator.dart';
import 'package:zapfit/core/utils/tdee_calculator.dart';
import 'package:zapfit/core/utils/vdot_calculator.dart';
import 'package:zapfit/core/utils/recovery_score_calculator.dart';
import 'package:zapfit/core/utils/stress_score_calculator.dart';
import 'package:zapfit/core/utils/steps_converter.dart';
import 'package:zapfit/core/utils/sleep_need_calculator.dart';
import 'package:zapfit/core/utils/fitness_age_calculator.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/features/health/widgets/training_metrics_card.dart';
import 'package:intl/intl.dart';
import 'package:zapfit/l10n/app_localizations.dart';

class HealthDashboardTab extends StatelessWidget {
  final void Function(int) onTabRequested;

  const HealthDashboardTab({super.key, required this.onTabRequested});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<HealthService>(
      builder: (context, service, child) {
        final dashboard = service.dashboard;
        
        return RefreshIndicator(
          onRefresh: () => service.autoImportFromHealthConnect(force: true),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTodaySummary(context),
              const SizedBox(height: 16),
              _buildMetricCard(
                context,
                title: l10n.healthWeight,
                value: dashboard?.latestWeight != null ? '${dashboard!.latestWeight!.weight} kg' : '--',
                subtitle: dashboard?.latestWeight != null 
                    ? DateFormat('dd.MM.yyyy').format(dashboard!.latestWeight!.date)
                    : l10n.noData,
                icon: Icons.monitor_weight_outlined,
                color: Colors.blue,
                onTap: () => onTabRequested(1),
              ),
              _buildMetricCard(
                context,
                title: l10n.healthSleep,
                value: dashboard?.latestSleep != null 
                    ? _formatDuration(dashboard!.latestSleep!.totalSleepSeconds)
                    : '--',
                subtitle: dashboard?.latestSleep != null 
                    ? '${l10n.quality}: ${_calcSleepQuality(dashboard!.latestSleep!)}'
                    : l10n.noData,
                icon: Icons.bedtime_outlined,
                color: Colors.indigo,
                onTap: () => onTabRequested(2),
              ),
              _buildMetricCard(
                context,
                title: l10n.healthWater,
                value: '${dashboard?.todayWaterMl.toInt() ?? 0} ml',
                subtitle: '${l10n.goal}: 2000 ml',
                icon: Icons.water_drop_outlined,
                color: Colors.cyan,
                progress: (dashboard?.todayWaterMl ?? 0) / 2000,
                onTap: () => onTabRequested(3),
              ),
              _buildMetricCard(
                context,
                title: l10n.healthSteps,
                value: '${dashboard?.todaySteps ?? 0}',
                subtitle: '${l10n.goal}: 10000',
                icon: Icons.directions_walk,
                color: Colors.green,
                progress: (dashboard?.todaySteps ?? 0) / 10000,
                onTap: () => onTabRequested(4),
              ),
              const SizedBox(height: 12),
              _sectionHeader(context, 'МЕТРИКИ ФОРМЫ'),
              const SizedBox(height: 8),
              const TrainingMetricsCard(),
              const SizedBox(height: 12),
              _buildVo2MaxCard(context),
              const SizedBox(height: 12),
              _sectionHeader(context, 'РАСЧИТАННЫЕ МЕТРИКИ'),
              const SizedBox(height: 8),
              _buildCalculatedMetricsCard(context),
              const SizedBox(height: 12),
              _sectionHeader(context, 'ZAPFIT МЕТРИКИ'),
              const SizedBox(height: 8),
              _buildZapfitMetricsCard(context),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '--';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}ч ${minutes}м';
  }

  String _calcSleepQuality(SleepRecord record) {
    final score = record.sleepScoreOverall;
    if (score != null) {
      if (score >= 90) return 'Отлично';
      if (score >= 75) return 'Хорошо';
      if (score >= 60) return 'Удовл.';
      if (score >= 40) return 'Плохо';
      return 'Критично';
    }
    // Fallback: calculate from stages
    final totalH = record.totalSleepSeconds / 3600.0;
    final deepRatio = record.totalSleepSeconds > 0
        ? (record.deepSleepSeconds / record.totalSleepSeconds)
        : 0.0;
    final remRatio = record.totalSleepSeconds > 0
        ? (record.remSleepSeconds / record.totalSleepSeconds)
        : 0.0;
    final awakeRatio = record.totalSleepSeconds > 0
        ? (record.awakeSleepSeconds / record.totalSleepSeconds)
        : 0.0;
    // Simple weighted score
    int scoreCalc = 0;
    if (totalH >= 7) scoreCalc += 30; else if (totalH >= 6) scoreCalc += 20; else if (totalH >= 5) scoreCalc += 10;
    if (deepRatio >= 0.2) scoreCalc += 25; else if (deepRatio >= 0.15) scoreCalc += 15; else if (deepRatio >= 0.1) scoreCalc += 10;
    if (remRatio >= 0.2) scoreCalc += 20; else if (remRatio >= 0.15) scoreCalc += 10;
    if (awakeRatio <= 0.1) scoreCalc += 25; else if (awakeRatio <= 0.2) scoreCalc += 15; else if (awakeRatio <= 0.3) scoreCalc += 5;
    if (scoreCalc >= 80) return 'Отлично';
    if (scoreCalc >= 60) return 'Хорошо';
    if (scoreCalc >= 40) return 'Удовл.';
    return 'Плохо';
  }

  Widget _buildTodaySummary(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(l10n.todaySummary, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(DateFormat('EEEE, d MMMM', 'ru').format(DateTime.now())),
          ],
        ),
      ),
    );
  }

  Widget _buildVo2MaxCard(BuildContext context) {
    final settings = AppSettingsController.instance;
    final gender = settings.userGender == 'male' ? 1 : 0;
    final age = settings.userAge ?? 25;
    int restingHr = settings.userRestingHeartRate;

    // Try to get resting HR from recent sleep records (Health Connect source)
    if (restingHr <= 0) {
      final sleepRecords = serviceLocator<HealthService>().sleepRecords;
      if (sleepRecords.isNotEmpty) {
        for (final r in sleepRecords) {
          if (r.restHeartRate != null && r.restHeartRate! > 0) {
            restingHr = r.restHeartRate!;
            break;
          }
        }
      }
    }

    double displayVo2max = 0;
    if (restingHr > 0) {
      displayVo2max = Vo2MaxCalculator.estimateFromHeartRate(
        restingHr: restingHr,
        maxHr: settings.userMaxHeartRate,
        age: age,
      );
    }
    if (displayVo2max <= 0) {
      displayVo2max = settings.userVo2max;
    }

    if (displayVo2max <= 0) {
      return _buildMetricCard(
        context,
        title: 'VO2 Max',
        value: '--',
        subtitle: 'Укажите пульс покоя в настройках',
        icon: Icons.air,
        color: Colors.teal,
        onTap: () {},
      );
    }

    final result = Vo2MaxCalculator.calculate(
      vo2max: displayVo2max,
      gender: gender,
      age: age,
    );
    final color = Vo2MaxCalculator.levelColor(result.level);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.air, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VO2 Max', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  Text(
                    '${displayVo2max.toStringAsFixed(1)} мл/кг/мин',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${result.levelLabel}  •  ${result.description}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculatedMetricsCard(BuildContext context) {
    final settings = AppSettingsController.instance;
    final h = settings.userHeight;
    final w = settings.userWeight;
    final age = settings.userAge ?? 25;
    final gender = settings.userGender == 'male' ? 1 : 0;

    if (h <= 0 || w <= 0) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.calculate, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Рассчитанные метрики', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              const SizedBox(height: 8),
              const Text('Укажите рост и вес в настройках профиля', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final bmi = w / ((h / 100) * (h / 100));
    final tdeeResult = TdeeCalculator.calculate(
      weightKg: w, heightCm: h, age: age, gender: gender,
      activityLevel: ActivityLevel.moderatelyActive,
    );

    final vdot = settings.userVo2max > 0 ? settings.userVo2max.toDouble() : 0.0;
    final trainingPaces = vdot > 0 ? VdotCalculator.trainingPaces(vdot) : <String, double>{};

    final bmiColor = bmi < 18.5 ? Colors.orange : bmi < 25 ? Colors.green : bmi < 30 ? Colors.orange : Colors.red;
    final bmiLabel = bmi < 18.5 ? 'Недостаточный' : bmi < 25 ? 'Норма' : bmi < 30 ? 'Избыточный' : 'Ожирение';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.calculate, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Рассчитанные метрики', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
            _metricRow(Icons.monitor_weight, 'BMI', '${bmi.toStringAsFixed(1)} кг/м²', bmiLabel, bmiColor),
            _metricRow(Icons.local_fire_department, 'TDEE', '${tdeeResult.tdee.round()} ккал/день',
                '${tdeeResult.activityLabel}', Colors.orange),
            _metricRow(Icons.restaurant, 'BMR', '${tdeeResult.bmrMifflin.round()} ккал', 'Метаболизм в покое', Colors.teal),
            const Divider(height: 16),
            _macroRow('Белки', '${tdeeResult.maintenanceMacros.proteinGrams.round()} г',
                '${tdeeResult.maintenanceMacros.proteinCal.round()} ккал', Colors.blue),
            _macroRow('Жиры', '${tdeeResult.maintenanceMacros.fatGrams.round()} г',
                '${tdeeResult.maintenanceMacros.fatCal.round()} ккал', Colors.amber),
            _macroRow('Углеводы', '${tdeeResult.maintenanceMacros.carbGrams.round()} г',
                '${tdeeResult.maintenanceMacros.carbCal.round()} ккал', Colors.green),
            if (trainingPaces.isNotEmpty) ...[
              const Divider(height: 16),
              const Text('Тренировочные зоны (VDOT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              for (final entry in trainingPaces.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(Icons.speed, size: 16, color: Colors.purple),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 13))),
                      Text(VdotCalculator.formatPace(entry.value) + ' мин/км',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // === ZAPFIT metrics ===
  Widget _buildZapfitMetricsCard(BuildContext context) {
    final health = serviceLocator<HealthService>();
    final dash = health.dashboard;
    final settings = AppSettingsController.instance;
    final age = settings.userAge ?? 25;
    final male = settings.userGender == 'male';
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    // Восстановление и стресс требуют HRV (rmssd). В экране/моделях нет источника
    // HRV, поэтому вызываем калькуляторы только при наличии этого входа, иначе — «Нет данных».
    final restingHr = dash?.latestSleep?.restHeartRate ?? settings.userRestingHeartRate;
    final sleepScore = dash?.latestSleep?.sleepScoreOverall ?? 0;
    final hrvSetting = settings.userHrvRmssd;
    final double? hrvRmssd = hrvSetting > 0 ? hrvSetting : null;

    String recoveryValue;
    String recoveryLabel;
    if (hrvRmssd != null) {
      final score = RecoveryScoreCalculator.calculate(
        hrvRmssd: hrvRmssd,
        restingHr: restingHr > 0 ? restingHr.toDouble() : null,
        sleepScore: sleepScore,
        previousDayLoad: null,
      );
      recoveryValue = score.toString();
      recoveryLabel = RecoveryScoreCalculator.classify(score);
    } else {
      recoveryValue = 'Нет данных';
      recoveryLabel = 'нет данных HRV';
    }

    String stressValue;
    String stressLabel;
    if (hrvRmssd != null) {
      final score = StressScoreCalculator.calculate(
        hrvRmssd: hrvRmssd,
        lfHfRatio: null,
        restingHr: restingHr > 0 ? restingHr.toDouble() : null,
      );
      stressValue = score.toString();
      stressLabel = StressScoreCalculator.classify(score);
    } else {
      stressValue = 'Нет данных';
      stressLabel = 'нет данных HRV';
    }

    // Активные минуты за неделю (производные от шагов, порог 100 шаг/мин, цель 150/нед)
    int weekSteps = 0;
    for (final r in health.stepsRecords) {
      if (r.date.isAfter(weekAgo)) weekSteps += r.steps;
    }
    final weeklyActiveMinutes = StepsConverter.stepsToActiveMinutes(weekSteps);
    final activeProgress = (weeklyActiveMinutes / 150).clamp(0.0, 1.0);

    // Потребность во сне vs факт + долг
    final needHours = SleepNeedCalculator.recommendedHours(age);
    final actualHours = (dash?.latestSleep?.totalSleepSeconds ?? 0) / 3600.0;
    final recentSleepHours = health.sleepRecords
        .where((r) => r.date.isAfter(weekAgo))
        .map((r) => (r.totalSleepSeconds / 3600.0).round())
        .toList();
    final sleepDebt = SleepNeedCalculator.sleepDebtHours(
      recentSleepHours: recentSleepHours,
      ageYears: age,
    );

    // Биологический возраст (фитнес) на основе VO2max
    final vo2max = settings.userVo2max;
    final fitnessAgeStr = vo2max > 0
        ? FitnessAgeCalculator.estimate(vo2max: vo2max, chronologicalAge: age, male: male).toString()
        : 'Нет данных';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.monitor_heart, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('ZAPFIT метрики', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
            _metricRow(Icons.favorite, 'Восстановление', recoveryValue, recoveryLabel, Colors.grey),
            _metricRow(Icons.psychology, 'Стресс', stressValue, stressLabel, Colors.grey),
            _metricRow(Icons.timer, 'Активные минуты', '$weeklyActiveMinutes мин/нед',
                'цель 150/нед', Colors.green),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: activeProgress,
              backgroundColor: Colors.green.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            _metricRow(Icons.bedtime, 'Сон нужно/факт',
                '$needHours ч / ${actualHours.toStringAsFixed(1)} ч',
                'долг ${sleepDebt.toStringAsFixed(1)} ч', Colors.indigo),
            _metricRow(Icons.cake, 'Био-возраст', fitnessAgeStr,
                'хроно $age лет', male ? Colors.teal : Colors.pink),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(IconData icon, String label, String value, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroRow(String label, String grams, String cals, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          Text('$grams / $cals', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double? progress,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        backgroundColor: color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.outline,
        letterSpacing: 1.2,
      )),
    );
  }
}
