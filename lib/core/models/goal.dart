enum GoalType { weeklyDistance, monthlyDistance, monthlyActivities, streak, personalBest }

class Goal {
  final int? id;
  final GoalType type;
  final String title;
  final double target;
  final double current;
  final DateTime startDate;
  final DateTime endDate;
  final bool completed;
  final DateTime? completedAt;

  Goal({
    this.id,
    required this.type,
    required this.title,
    required this.target,
    this.current = 0.0,
    required this.startDate,
    required this.endDate,
    this.completed = false,
    this.completedAt,
  });

  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
  bool get isExpired => DateTime.now().isAfter(endDate);
  bool get isAchieved => current >= target;

  Goal copyWith({
    int? id,
    GoalType? type,
    String? title,
    double? target,
    double? current,
    DateTime? startDate,
    DateTime? endDate,
    bool? completed,
    DateTime? completedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      target: target ?? this.target,
      current: current ?? this.current,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toDbMap() => {
    if (id != null) 'id': id,
    'type': type.index,
    'title': title,
    'target': target,
    'current': current,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'completed': completed ? 1 : 0,
    'completed_at': completedAt?.toIso8601String(),
  };

  factory Goal.fromDbMap(Map<String, dynamic> map) => Goal(
    id: map['id'] as int?,
    type: GoalType.values[map['type'] as int],
    title: map['title'] as String,
    target: (map['target'] as num).toDouble(),
    current: (map['current'] as num).toDouble(),
    startDate: DateTime.parse(map['start_date'] as String),
    endDate: DateTime.parse(map['end_date'] as String),
    completed: (map['completed'] as int) == 1,
    completedAt: map['completed_at'] != null ? DateTime.tryParse(map['completed_at'] as String) : null,
  );

  String get typeLabel {
    switch (type) {
      case GoalType.weeklyDistance: return 'Пробег за неделю';
      case GoalType.monthlyDistance: return 'Пробег за месяц';
      case GoalType.monthlyActivities: return 'Тренировки за месяц';
      case GoalType.streak: return 'Серия тренировок';
      case GoalType.personalBest: return 'Личный рекорд';
    }
  }

  String get unit {
    switch (type) {
      case GoalType.weeklyDistance:
      case GoalType.monthlyDistance:
      case GoalType.personalBest:
        return 'км';
      case GoalType.monthlyActivities:
      case GoalType.streak:
        return 'тренировок';
    }
  }
}
