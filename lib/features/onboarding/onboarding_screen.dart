import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zapfit/l10n/app_localizations.dart';
import 'package:zapfit/features/onboarding/mode_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  static const _kOnboardingDone = 'onboarding_done';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kOnboardingDone) ?? false);
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDone, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<_OnboardingPage> _buildPages() {
    return [
      _OnboardingPage(
        icon: Icons.waving_hand,
        color: Colors.blue,
        title: 'Добро пожаловать в ZAPFIT!',
        description: 'Твой персональный трекер активности.\nБег, велосипед, ходьба и многое другое.',
      ),
      _OnboardingPage(
        icon: Icons.play_circle_outline,
        color: Colors.green,
        title: 'Записывай активности',
        description: 'Нажми кнопку ▶ на карте, выбери вид спорта и начни.\nGPS автоматически запишет маршрут.',
      ),
      _OnboardingPage(
        icon: Icons.map_outlined,
        color: Colors.orange,
        title: 'Карта и метрики',
        description: 'Отслеживай скорость, дистанцию, пульс.\nКарта кешируется для оффлайн-использования.',
      ),
      _OnboardingPage(
        icon: Icons.favorite_outline,
        color: Colors.red,
        title: 'Здоровье',
        description: 'Шаги, вес, сон, вода.\nВсё в одном месте с графиками и статистикой.',
      ),
      _OnboardingPage(
        icon: Icons.sync,
        color: Colors.purple,
        title: 'Синхронизация',
        description: 'Подключись к серверу для синхронизации.\nИли работай локально — данные сохраняются на устройстве.',
      ),
    ];
  }

  bool get _isModePage => _currentPage == _buildPages().length;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();
    final totalPages = pages.length + 1; // +1 для выбора режима
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalPages,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  if (index == pages.length) {
                    return _buildModeSelectionPage(context);
                  }
                  final page = pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: page.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page.icon, size: 60, color: page.color),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Точки-индикаторы
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalPages, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            // Кнопки
            if (!_isModePage)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => _pageController.animateToPage(pages.length, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      child: const Text('Пропустить'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: const Text('Далее'),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelectionPage(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storage_rounded, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('Как хранить данные?', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Выберите режим работы. Можно изменить позже в настройках.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey, height: 1.4)),
          const SizedBox(height: 32),
          _OnboardingModeCard(
            icon: Icons.phone_android,
            color: Colors.green,
            title: 'Локально',
            subtitle: 'Без регистрации и сервера.\nВсе данные на устройстве.',
            onTap: () => _selectMode(AppMode.local),
          ),
          const SizedBox(height: 16),
          _OnboardingModeCard(
            icon: Icons.cloud_outlined,
            color: Colors.blue,
            title: 'Подключиться к серверу',
            subtitle: 'Синхронизация, бэкап,\nдоступ с любого устройства.',
            onTap: () => _selectMode(AppMode.server),
          ),
        ],
      ),
    );
  }

  Future<void> _selectMode(AppMode mode) async {
    await ModeSelectionScreen.setMode(mode);
    await OnboardingScreen.markDone();
    widget.onComplete();
  }

  void _finish() {
    // старый fallback: просто листаем к выбору режима, а не завершаем
    _pageController.animateToPage(_buildPages().length, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

class _OnboardingModeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _OnboardingModeCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.3), width: 1.5)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3))])),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
