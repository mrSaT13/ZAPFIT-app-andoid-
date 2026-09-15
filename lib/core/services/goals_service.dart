import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';

class ServerGoal {
  final int id;
  final String interval;    // daily, weekly, monthly, yearly
  final String activityType; // run, bike, swim, walk, strength, cardio
  final String goalType;     // calories, activities, distance, elevation, duration
  final int? goalCalories;
  final int? goalActivitiesNumber;
  final int? goalDistance;    // meters
  final int? goalElevation;
  final int? goalDuration;   // seconds

  ServerGoal({
    required this.id,
    required this.interval,
    required this.activityType,
    required this.goalType,
    this.goalCalories,
    this.goalActivitiesNumber,
    this.goalDistance,
    this.goalElevation,
    this.goalDuration,
  });

  factory ServerGoal.fromJson(Map<String, dynamic> json) => ServerGoal(
    id: json['id'] as int,
    interval: json['interval'] as String,
    activityType: json['activity_type'] as String,
    goalType: json['goal_type'] as String,
    goalCalories: json['goal_calories'] as int?,
    goalActivitiesNumber: json['goal_activities_number'] as int?,
    goalDistance: json['goal_distance'] as int?,
    goalElevation: json['goal_elevation'] as int?,
    goalDuration: json['goal_duration'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'interval': interval,
    'activity_type': activityType,
    'goal_type': goalType,
    if (goalCalories != null) 'goal_calories': goalCalories,
    if (goalActivitiesNumber != null) 'goal_activities_number': goalActivitiesNumber,
    if (goalDistance != null) 'goal_distance': goalDistance,
    if (goalElevation != null) 'goal_elevation': goalElevation,
    if (goalDuration != null) 'goal_duration': goalDuration,
  };

  String get intervalLabel {
    switch (interval) {
      case 'daily': return 'Ежедневно';
      case 'weekly': return 'Еженедельно';
      case 'monthly': return 'Ежемесячно';
      case 'yearly': return 'Ежегодно';
      default: return interval;
    }
  }

  String get activityTypeLabel {
    switch (activityType) {
      case 'run': return 'Бег';
      case 'bike': return 'Велосипед';
      case 'swim': return 'Плавание';
      case 'walk': return 'Ходьба';
      case 'strength': return 'Силовая';
      case 'cardio': return 'Кардио';
      default: return activityType;
    }
  }

  String get goalTypeLabel {
    switch (goalType) {
      case 'calories': return 'Калории';
      case 'activities': return 'Тренировки';
      case 'distance': return 'Дистанция';
      case 'elevation': return 'Набор высоты';
      case 'duration': return 'Время';
      default: return goalType;
    }
  }

  String get targetDisplay {
    switch (goalType) {
      case 'calories': return '$goalCalories ккал';
      case 'activities': return '$goalActivitiesNumber трен.';
      case 'distance': return '${((goalDistance ?? 0) / 1000).toStringAsFixed(1)} км';
      case 'elevation': return '$goalElevation м';
      case 'duration': return _formatDuration(goalDuration ?? 0);
      default: return '';
    }
  }

  String _formatDuration(int seconds) {
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).floor();
    if (h > 0) return '$hч ${m}м';
    return '$m мин';
  }
}

class GoalProgress {
  final int goalId;
  final String interval;
  final String activityType;
  final String goalType;
  final String startDate;
  final String endDate;
  final int? percentageCompleted;
  final int? totalDistance;
  final int? totalActivitiesNumber;
  final int? goalDistance;
  final int? goalActivitiesNumber;

  GoalProgress({
    required this.goalId,
    required this.interval,
    required this.activityType,
    required this.goalType,
    required this.startDate,
    required this.endDate,
    this.percentageCompleted,
    this.totalDistance,
    this.totalActivitiesNumber,
    this.goalDistance,
    this.goalActivitiesNumber,
  });

  factory GoalProgress.fromJson(Map<String, dynamic> json) => GoalProgress(
    goalId: json['goal_id'] as int,
    interval: json['interval'] as String,
    activityType: json['activity_type'] as String,
    goalType: json['goal_type'] as String,
    startDate: json['start_date'] as String? ?? '',
    endDate: json['end_date'] as String? ?? '',
    percentageCompleted: json['percentage_completed'] as int?,
    totalDistance: json['total_distance'] as int?,
    totalActivitiesNumber: json['total_activities_number'] as int?,
    goalDistance: json['goal_distance'] as int?,
    goalActivitiesNumber: json['goal_activities_number'] as int?,
  );

  String get progressDisplay {
    switch (goalType) {
      case 'distance':
        final done = ((totalDistance ?? 0) / 1000).toStringAsFixed(1);
        final target = ((goalDistance ?? 0) / 1000).toStringAsFixed(1);
        return '$done / $target км';
      case 'activities':
        return '${totalActivitiesNumber ?? 0} / $goalActivitiesNumber';
      default:
        return '${percentageCompleted ?? 0}%';
    }
  }
}

class GoalsService {
  GoalsService._();
  static final GoalsService instance = GoalsService._();

  final ApiClient _apiClient = serviceLocator<ApiClient>();

  static const String _basePath = '/api/v1/profile/goals';

  Future<List<ServerGoal>> fetchGoals() async {
    try {
      final response = await _apiClient.get(_basePath);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data.map((e) => ServerGoal.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('GoalsService: fetchGoals error: $e');
    }
    return [];
  }

  Future<List<GoalProgress>> fetchGoalsProgress() async {
    try {
      final response = await _apiClient.get('$_basePath/results');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data.map((e) => GoalProgress.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('GoalsService: fetchGoalsProgress error: $e');
    }
    return [];
  }

  Future<ServerGoal?> createGoal({
    required String interval,
    required String activityType,
    required String goalType,
    int? goalCalories,
    int? goalActivitiesNumber,
    int? goalDistance,
    int? goalElevation,
    int? goalDuration,
  }) async {
    try {
      final body = <String, dynamic>{
        'interval': interval,
        'activity_type': activityType,
        'goal_type': goalType,
      };
      if (goalCalories != null) body['goal_calories'] = goalCalories;
      if (goalActivitiesNumber != null) body['goal_activities_number'] = goalActivitiesNumber;
      if (goalDistance != null) body['goal_distance'] = goalDistance;
      if (goalElevation != null) body['goal_elevation'] = goalElevation;
      if (goalDuration != null) body['goal_duration'] = goalDuration;

      final response = await _apiClient.post(_basePath, body: body);
      if (response.statusCode == 201) {
        return ServerGoal.fromJson(json.decode(response.body) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('GoalsService: createGoal error: $e');
    }
    return null;
  }

  Future<void> deleteGoal(int goalId) async {
    try {
      await _apiClient.delete('$_basePath/$goalId');
    } catch (e) {
      debugPrint('GoalsService: deleteGoal error: $e');
    }
  }

  /// Автогенерация целей на основе истории активностей
  /// Создаёт новые цели даже если уже есть существующие
  Future<List<ServerGoal>> autoGenerateGoals() async {
    final existing = await fetchGoals();
    final existingKeys = existing.map((g) => '${g.interval}_${g.activityType}_${g.goalType}').toSet();

    final repo = LocalActivityRepository.instance;
    final activities = await repo.getActivities();
    final now = DateTime.now();
    final generated = <ServerGoal>[];

    // Анализ активностей за 30 дней
    final recent = activities.where((a) => now.difference(a.startedAt).inDays <= 30).toList();
    if (recent.isEmpty) return [];

    // Бег
    final runs = recent.where((a) => a.kind == ActivityKind.run || a.kind == ActivityKind.trailRun || a.kind == ActivityKind.treadmillRun);
    if (runs.isNotEmpty && !existingKeys.contains('weekly_run_distance')) {
      final weeklyDist = runs.fold(0.0, (sum, a) => sum + a.distanceMeters) / 4;
      final targetDist = ((weeklyDist * 1.2) / 1000).ceil() * 1000;
      final goal = await createGoal(
        interval: 'weekly',
        activityType: 'run',
        goalType: 'distance',
        goalDistance: targetDist,
      );
      if (goal != null) generated.add(goal);
    }

    // Велосипед
    final bikes = recent.where((a) => a.kind == ActivityKind.roadCycling || a.kind == ActivityKind.mtbCycling || a.kind == ActivityKind.gravelCycling);
    if (bikes.isNotEmpty && !existingKeys.contains('weekly_bike_distance')) {
      final weeklyDist = bikes.fold(0.0, (sum, a) => sum + a.distanceMeters) / 4;
      final targetDist = ((weeklyDist * 1.2) / 1000).ceil() * 1000;
      final goal = await createGoal(
        interval: 'weekly',
        activityType: 'bike',
        goalType: 'distance',
        goalDistance: targetDist,
      );
      if (goal != null) generated.add(goal);
    }

    // Количество тренировок в месяц
    final monthlyCount = recent.length;
    if (monthlyCount >= 4 && !existingKeys.contains('monthly_cardio_activities')) {
      final target = (monthlyCount * 1.2 / 30 * 30).ceil();
      final goal = await createGoal(
        interval: 'monthly',
        activityType: 'cardio',
        goalType: 'activities',
        goalActivitiesNumber: target,
      );
      if (goal != null) generated.add(goal);
    }

    return generated;
  }
}
