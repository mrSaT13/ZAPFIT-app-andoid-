import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { local, server }

class ModeSelectionScreen extends StatefulWidget {
  final Function(AppMode) onModeSelected;
  const ModeSelectionScreen({super.key, required this.onModeSelected});

  static const _kModeKey = 'app_mode';

  static Future<AppMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_kModeKey);
    if (modeStr == 'server') return AppMode.server;
    return AppMode.local;
  }

  static Future<void> setMode(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModeKey, mode.name);
  }

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),
              // Логотип
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo/logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.fitness_center,
                      size: 50,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'ZAPFIT',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Выберите режим работы',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
              const Spacer(flex: 2),

              // Локальный режим
              _ModeCard(
                icon: Icons.phone_android,
                color: Colors.green,
                title: 'Локальный режим',
                subtitle: 'Данные хранятся только на устройстве.\nНе нужен сервер, не нужен интернет.',
                onTap: () {
                  ModeSelectionScreen.setMode(AppMode.local);
                  widget.onModeSelected(AppMode.local);
                },
              ),
              const SizedBox(height: 16),

              // Серверный режим
              _ModeCard(
                icon: Icons.cloud_outlined,
                color: Colors.blue,
                title: 'Подключиться к серверу',
                subtitle: 'Синхронизация данных, бэкап,\nдоступ с любого устройства.',
                onTap: () {
                  ModeSelectionScreen.setMode(AppMode.server);
                  widget.onModeSelected(AppMode.server);
                },
              ),

              const Spacer(),
              Text(
                'Режим можно изменить в настройках',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
