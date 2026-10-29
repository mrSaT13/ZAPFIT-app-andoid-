/// Strength-workout models mirroring the server's `/api/v1/workouts` schemas
/// (`backend/app/workouts/schema.py`). Field names match the wire format so
/// payloads round-trip without manual mapping.
class WorkoutPlanExercise {
  final int? id; // server row id (plan exercises), null while editing
  final int position;
  final String? dayLabel;
  final String name; // canonical (display) name of the exercise
  final String? muscleGroup;
  final int? wgerExerciseId;
  final String? notes;
  final int? targetSets;
  final String? targetReps;
  final double? targetWeightKg;
  final int? restSeconds;

  const WorkoutPlanExercise({
    this.id,
    required this.position,
    this.dayLabel,
    required this.name,
    this.muscleGroup,
    this.wgerExerciseId,
    this.notes,
    this.targetSets,
    this.targetReps,
    this.targetWeightKg,
    this.restSeconds,
  });

  Map<String, dynamic> toPayload() {
    final payload = <String, dynamic>{
      'position': position,
      'name': name.length > 250 ? name.substring(0, 250) : name,
    };
    if (dayLabel != null) payload['day_label'] = dayLabel;
    if (muscleGroup != null) payload['muscle_group'] = muscleGroup;
    if (wgerExerciseId != null) payload['wger_exercise_id'] = wgerExerciseId;
    if (notes != null) payload['notes'] = notes;
    if (targetSets != null) payload['target_sets'] = targetSets;
    if (targetReps != null) payload['target_reps'] = targetReps;
    if (targetWeightKg != null) payload['target_weight_kg'] = targetWeightKg;
    if (restSeconds != null) payload['rest_s'] = restSeconds;
    return payload;
  }

  factory WorkoutPlanExercise.fromJson(Map<String, dynamic> j) => WorkoutPlanExercise(
        id: (j['id'] as num?)?.toInt(),
        position: (j['position'] as num?)?.toInt() ?? 0,
        dayLabel: j['day_label'] as String?,
        name: j['name'] as String? ?? '',
        muscleGroup: j['muscle_group'] as String?,
        wgerExerciseId: (j['wger_exercise_id'] as num?)?.toInt(),
        notes: j['notes'] as String?,
        targetSets: (j['target_sets'] as num?)?.toInt(),
        targetReps: j['target_reps'] as String?,
        targetWeightKg: (j['target_weight_kg'] as num?)?.toDouble(),
        restSeconds: (j['rest_s'] as num?)?.toInt(),
      );
}

class WorkoutPlan {
  final int? id; // null for a not-yet-created plan
  final int? userId;
  final String name;
  final String? description;
  final String source;
  final List<WorkoutPlanExercise> exercises;

  const WorkoutPlan({
    this.id,
    this.userId,
    required this.name,
    this.description,
    this.source = 'manual',
    this.exercises = const [],
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> j) => WorkoutPlan(
        id: (j['id'] as num?)?.toInt(),
        userId: (j['user_id'] as num?)?.toInt(),
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        source: j['source'] as String? ?? 'manual',
        exercises: (j['exercises'] as List<dynamic>?)
                ?.map((e) => WorkoutPlanExercise.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  /// Current max weight per exercise (rough loading hint for logging sets).
  double? bestWeightFor(int wgerId) {
    final ex = exercises.where((e) => e.wgerExerciseId == wgerId).toList();
    if (ex.isEmpty) return null;
    final weights = ex.map((e) => e.targetWeightKg).whereType<double>().toList();
    if (weights.isEmpty) return null;
    return weights.reduce((a, b) => a > b ? a : b);
  }

  String? repsHintFor(int wgerId) {
    final ex = exercises.where((e) => e.wgerExerciseId == wgerId).toList();
    if (ex.isEmpty) return null;
    for (final e in ex) {
      if (e.targetReps != null && e.targetReps!.isNotEmpty) return e.targetReps;
    }
    return null;
  }
}

class WorkoutSetLog {
  final String exerciseName;
  final int? wgerExerciseId;
  final int setNo; // 1-based
  final double? weightKg;
  final int? reps;
  final double? rpe;
  final bool completed;

  const WorkoutSetLog({
    required this.exerciseName,
    this.wgerExerciseId,
    required this.setNo,
    this.weightKg,
    this.reps,
    this.rpe,
    this.completed = true,
  });

  Map<String, dynamic> toPayload() {
    final payload = <String, dynamic>{
      'exercise_name': exerciseName.length > 250 ? exerciseName.substring(0, 250) : exerciseName,
      'set_no': setNo,
      'completed': completed,
    };
    if (wgerExerciseId != null) payload['wger_exercise_id'] = wgerExerciseId;
    if (weightKg != null) payload['weight_kg'] = weightKg;
    if (reps != null) payload['reps'] = reps;
    if (rpe != null) payload['rpe'] = rpe;
    return payload;
  }

  factory WorkoutSetLog.fromJson(Map<String, dynamic> j) => WorkoutSetLog(
        exerciseName: j['exercise_name'] as String? ?? '',
        wgerExerciseId: (j['wger_exercise_id'] as num?)?.toInt(),
        setNo: (j['set_no'] as num?)?.toInt() ?? 1,
        weightKg: (j['weight_kg'] as num?)?.toDouble(),
        reps: (j['reps'] as num?)?.toInt(),
        rpe: (j['rpe'] as num?)?.toDouble(),
        completed: j['completed'] as bool? ?? true,
      );
}

class WorkoutSession {
  final int? id;
  final int? planId;
  /// ISO date `YYYY-MM-DD`.
  final String date;
  final double? durationMin;
  final double? calories;
  final String? comment;
  final List<WorkoutSetLog> sets;

  const WorkoutSession({
    this.id,
    this.planId,
    required this.date,
    this.durationMin,
    this.calories,
    this.comment,
    this.sets = const [],
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
        id: (j['id'] as num?)?.toInt(),
        planId: (j['plan_id'] as num?)?.toInt(),
        date: j['date'] as String? ?? '',
        durationMin: (j['duration_min'] as num?)?.toDouble(),
        calories: (j['calories'] as num?)?.toDouble(),
        comment: j['comment'] as String?,
        sets: (j['sets'] as List<dynamic>?)
                ?.map((e) => WorkoutSetLog.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toCreatePayload() {
    final payload = <String, dynamic>{
      'date': date,
      'sets': sets.map((s) => s.toPayload()).toList(),
    };
    if (planId != null) payload['plan_id'] = planId;
    if (durationMin != null) payload['duration_min'] = durationMin;
    if (calories != null) payload['calories'] = calories;
    if (comment != null && comment!.isNotEmpty) {
      payload['comment'] = comment!.length > 1000 ? comment!.substring(0, 1000) : comment;
    }
    return payload;
  }
}
