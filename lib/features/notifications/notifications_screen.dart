import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zapfit/core/models/notification_model.dart';
import 'package:zapfit/core/services/notification_service.dart';
import 'package:zapfit/core/di/service_locator.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = serviceLocator<NotificationService>();
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _service.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _service,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Уведомления'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_showAll ? Icons.mark_email_unread : Icons.mark_email_read),
              tooltip: _showAll ? 'Скрыть прочитанные' : 'Показать все',
              onPressed: () => setState(() => _showAll = !_showAll),
            ),
            TextButton(
              onPressed: () => _service.markAllAsRead(),
              child: const Text('Все прочитано'),
            ),
          ],
        ),
        body: Consumer<NotificationService>(
          builder: (context, service, _) {
            if (service.isLoading && service.notifications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final displayList = _showAll
                ? service.notifications
                : service.notifications.where((n) => !n.read).toList();

            if (displayList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      _showAll
                          ? 'Уведомлений пока нет'
                          : 'У вас нет новых уведомлений',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (!_showAll) ...[
                      const SizedBox(height: 8),
                      const Text('Прочитанные уведомления скрыты', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => service.fetchNotifications(),
              child: ListView.separated(
                itemCount: displayList.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final n = displayList[index];

                  return Dismissible(
                    key: ValueKey(n.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: n.read ? Colors.blue : Colors.green,
                      child: Icon(
                        n.read ? Icons.mark_email_unread : Icons.mark_email_read,
                        color: Colors.white,
                      ),
                    ),
                    confirmDismiss: (_) async {
                      await service.markAsRead(n.id);
                      return false;
                    },
                    child: ListTile(
                      tileColor: n.read
                          ? null
                          : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.05),
                      leading: CircleAvatar(
                        backgroundColor: _getIconColor(n.type),
                        child: Icon(_getIcon(n.type), color: Colors.white, size: 20),
                      ),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.message),
                          if (n.createdAt != null)
                            Text(
                              DateFormat('dd.MM.yyyy HH:mm').format(n.createdAt!),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                        ],
                      ),
                      onTap: () {
                        service.markAsRead(n.id);
                        _showNotificationDetail(context, n);
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showNotificationDetail(BuildContext context, NotificationRecord n) {
    final navTarget = n.navigationTarget;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: CircleAvatar(
          backgroundColor: _getIconColor(n.type),
          child: Icon(_getIcon(n.type), color: Colors.white),
        ),
        title: Text(n.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.message),
            if (n.createdAt != null) ...[
              const SizedBox(height: 12),
              Text(
                DateFormat('dd MMMM yyyy', 'ru').format(n.createdAt!),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
          if (navTarget != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // close notifications screen
                // Navigation will be handled by the parent navigator
                // based on the target route
              },
              child: const Text('Открыть'),
            ),
        ],
      ),
    );
  }

  IconData _getIcon(int? type) {
    switch (type) {
      case 1: return Icons.fitness_center;
      case 2: return Icons.content_copy;
      case 11: return Icons.person_add;
      case 12: return Icons.how_to_reg;
      case 21: return Icons.watch_off;
      case 101: return Icons.approval;
      default: return Icons.notifications;
    }
  }

  Color _getIconColor(int? type) {
    switch (type) {
      case 1: return Colors.green;
      case 2: return Colors.orange;
      case 11: return Colors.blue;
      case 12: return Colors.teal;
      case 21: return Colors.redAccent;
      case 101: return Colors.purple;
      default: return Colors.grey;
    }
  }
}
