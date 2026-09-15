class TrainingMetrics {
  final double ctl;   // Chronic Training Load (42-day average)
  final double atl;   // Acute Training Load (7-day average)
  final double tsb;   // Training Stress Balance (CTL - ATL)
  final double tssToday; // TSS за сегодня
  final int recoveryDays; // Дни до восстановления
  final int? estimatedRestingHr; // Оцененный пульс покоя
  final int? estimatedMaxHr; // Оцененный максимальный пульс

  TrainingMetrics({
    required this.ctl,
    required this.atl,
    required this.tsb,
    required this.tssToday,
    required this.recoveryDays,
    this.estimatedRestingHr,
    this.estimatedMaxHr,
  });

  /// Описание формы
  String get formDescription {
    if (tsb > 25) return 'Отдых';
    if (tsb > 5) return 'Свежесть';
    if (tsb > -10) return 'Нейтрально';
    if (tsb > -30) return 'Усталость';
    return 'Перетренировка';
  }

  /// Цвет для отображения
  String get formColor {
    if (tsb > 25) return 'blue';
    if (tsb > 5) return 'green';
    if (tsb > -10) return 'yellow';
    if (tsb > -30) return 'orange';
    return 'red';
  }

  /// Описание CTL
  String get ctlDescription {
    if (ctl < 30) return 'Низкая базовая форма';
    if (ctl < 60) return 'Средняя форма';
    if (ctl < 100) return 'Хорошая форма';
    return 'Отличная форма';
  }

  /// Описание ATL
  String get atlDescription {
    if (atl < 20) return 'Минимальная нагрузка';
    if (atl < 50) return 'Лёгкая неделя';
    if (atl < 80) return 'Нормальная неделя';
    if (atl < 120) return 'Тяжёлая неделя';
    return 'Экстремальная нагрузка';
  }

  /// Рекомендация по восстановлению
  String get recoveryAdvice {
    if (recoveryDays <= 0) return 'Можно тренироваться';
    if (recoveryDays == 1) return 'Отдых 1 день';
    if (recoveryDays <= 3) return 'Отдых $recoveryDays дня';
    return 'Отдых $recoveryDays дней';
  }
}

class DailyTss {
  final DateTime date;
  final double tss;

  DailyTss(this.date, this.tss);
}
