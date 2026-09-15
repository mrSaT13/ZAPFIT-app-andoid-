class NotificationRecord {
  final int id;
  final int userId;
  final int? type;
  final Map<String, dynamic>? options;
  final bool read;
  final DateTime? createdAt;

  NotificationRecord({
    required this.id,
    required this.userId,
    this.type,
    this.options,
    required this.read,
    this.createdAt,
  });

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      type: (json['type'] as num?)?.toInt(),
      options: json['options'] != null ? Map<String, dynamic>.from(json['options'] as Map) : null,
      read: (json['read'] as bool?) ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  /// Notification type labels matching server constants:
  /// 1=NEW_ACTIVITY, 2=DUPLICATE_ACTIVITY, 11=NEW_FOLLOWER_REQUEST,
  /// 12=NEW_FOLLOWER_REQUEST_ACCEPTED, 21=GARMIN_TOKEN_EXPIRED,
  /// 101=ADMIN_NEW_SIGN_UP_APPROVAL_REQUEST
  String get title {
    switch (type) {
      case 1: return 'Новая активность';
      case 2: return 'Дубликат активности';
      case 11: return 'Запрос на подписку';
      case 12: return 'Подписка принята';
      case 21: return 'Токен Garmin истёк';
      case 101: return 'Заявка на регистрацию';
      default: return 'Уведомление';
    }
  }

  String get message {
    switch (type) {
      case 1:
        return 'Новая тренировка добавлена в ленту';
      case 2:
        return 'Обнаружен дубликат тренировки по времени начала';
      case 11: {
        final userName = options?['user_name'] as String? ?? 'Пользователь';
        final userUsername = options?['user_username'] as String?;
        final suffix = userUsername != null ? ' (@$userUsername)' : '';
        return '$userName хочет подписаться на вас$suffix';
      }
      case 12: {
        final userName = options?['user_name'] as String? ?? 'Пользователь';
        final userUsername = options?['user_username'] as String?;
        final suffix = userUsername != null ? ' (@$userUsername)' : '';
        return '$userName принял вашу подписку$suffix';
      }
      case 21:
        return 'Токен Garmin Connect истёк. Переподключите интеграцию в настройках.';
      case 101: {
        final userName = options?['user_name'] as String? ?? 'Пользователь';
        final userUsername = options?['user_username'] as String?;
        final suffix = userUsername != null ? ' (@$userUsername)' : '';
        return '$userName запросил регистрацию$suffix';
      }
      default:
        return 'У вас новое уведомление';
    }
  }

  /// Navigation route info for tapping a notification.
  /// Returns a map with 'route' name and optional 'params' / 'queryParams'.
  Map<String, dynamic>? get navigationTarget {
    switch (type) {
      case 1:
      case 2:
        final activityId = options?['activity_id'];
        if (activityId != null) {
          return {'route': 'activity', 'params': {'id': activityId}};
        }
        return null;
      case 11:
        return {'route': 'notifications'}; // follower requests tab
      case 12:
        final userId = options?['user_id'];
        if (userId != null) {
          return {'route': 'user', 'params': {'id': userId}};
        }
        return null;
      case 21:
        return {'route': 'settings', 'queryParams': {'tab': 'integrations'}};
      case 101:
        final userUsername = options?['user_username'];
        return {
          'route': 'settings',
          'queryParams': {'tab': 'users', if (userUsername != null) 'username': userUsername},
        };
      default:
        return null;
    }
  }
}
