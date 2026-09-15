import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/services/websocket_service.dart';
import 'package:zapfit/core/models/notification_model.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:zapfit/core/services/local_notification_service.dart';

class NotificationService extends ChangeNotifier {
  final ApiClient _apiClient = serviceLocator<ApiClient>();
  WebSocketService? _wsService;
  Timer? _pollingTimer;

  List<NotificationRecord> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  List<NotificationRecord> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isWsConnected => _wsService?.isConnected ?? false;

  /// Initialize with optional WebSocket service for real-time updates.
  void init({WebSocketService? wsService}) {
    _wsService = wsService;
    if (_wsService != null) {
      _wsSubscription = _wsService!.notificationStream.listen(_onWsMessage);
      // Listen for connection state changes to restart polling on disconnect
      _wsService!.addListener(_onWsStateChanged);
    }
    // Start polling as fallback (always active, even with WS)
    _startPolling();
  }

  void _onWsStateChanged() {
    // If WS disconnects, polling will catch up. No action needed since
    // polling is always running.
  }

  void _onWsMessage(Map<String, dynamic> message) {
    final msgType = message['message'] as String?;
    final notificationId = message['notification_id'] as int?;
    if (notificationId == null) return;
    debugPrint('NotificationService: WS message: $msgType (id=$notificationId)');
    if (msgType != null && msgType.contains('NOTIFICATION')) {
      fetchNotifications();
      fetchUnreadCount();
      try {
        final title = message['title'] as String? ?? 'ZAPFIT';
        final body = message['body'] as String? ?? msgType;
        LocalNotificationService.instance.showServerNotification(id: notificationId, title: title, body: body);
      } catch (e) {
        debugPrint('showServerNotification failed: $e');
      }
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Poll every 60 seconds as fallback (WS handles real-time)
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      fetchUnreadCount();
    });
  }

  Future<void> fetchUnreadCount() async {
    try {
      final response = await _apiClient.get('/api/v1/notifications/number');
      if (response.statusCode == 200) {
        final newCount = int.tryParse(response.body) ?? 0;
        if (newCount != _unreadCount) {
          _unreadCount = newCount;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error fetching notification count: $e');
    }
  }

  Future<void> fetchNotifications() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.get('/api/v1/notifications/page_number/1/num_records/50');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        final oldUnreadIds = _notifications.where((n) => !n.read).map((n) => n.id).toSet();
        _notifications = data.map((item) => NotificationRecord.fromJson(item as Map<String, dynamic>)).toList();
        _unreadCount = _notifications.where((n) => !n.read).length;
        notifyListeners();
        for (final n in _notifications.where((x) => !x.read)) {
          if (!oldUnreadIds.contains(n.id)) {
            try {
              final title = n.title.isNotEmpty ? n.title : 'ZAPFIT';
              final body = n.message;
              await LocalNotificationService.instance.showServerNotification(id: n.id, title: title, body: body.toString());
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      final response = await _apiClient.put('/api/v1/notifications/$id/mark_as_read');
      if (response.statusCode == 200 || response.statusCode == 204) {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          final n = _notifications[index];
          if (!n.read) {
            _notifications[index] = NotificationRecord(
              id: n.id,
              userId: n.userId,
              type: n.type,
              options: n.options,
              read: true,
              createdAt: n.createdAt,
            );
            if (_unreadCount > 0) _unreadCount--;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final unreadIds = _notifications.where((n) => !n.read).map((n) => n.id).toList();
      for (final id in unreadIds) {
        await markAsRead(id);
      }
      await fetchUnreadCount();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _wsSubscription?.cancel();
    _wsService?.removeListener(_onWsStateChanged);
    super.dispose();
  }
}


