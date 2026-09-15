import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zapfit/l10n/app_localizations.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  String _buildNumber = '';
  String _refSearch = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('О приложении'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Приложение'),
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Справочник'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAboutTab(context),
            _buildReferenceTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/logo/logo.png', fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              Text(
                'ZAPFIT',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'v$_version ($_buildNumber)',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                '© 2024–${DateTime.now().year}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('Исходный код'),
          subtitle: const Text('github.com/mrSaT13/ZAPFIT'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => _launchUrl('https://github.com/mrSaT13/ZAPFIT'),
        ),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Описание',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'ZAPFIT — open-source фитнес-трекер для бега, велоспорта, плавания и '
          'других видов активности. Поддерживает GPS-трекинг, пульсометры Bluetooth, '
          'Health Connect, голосового коуча, тренировочные метрики (TSS/CTL/ATL) '
          'и синхронизацию с сервером.',
          style: TextStyle(height: 1.5),
        ),
        const SizedBox(height: 24),
        Text(
          'Возможности',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _featureItem(Icons.gps_fixed, 'GPS-трекинг с авто-паузой'),
        _featureItem(Icons.favorite, 'Пульсометры и датчики Bluetooth'),
        _featureItem(Icons.health_and_safety, 'Health Connect интеграция'),
        _featureItem(Icons.record_voice_over, 'Голосовой коуч'),
        _featureItem(Icons.show_chart, 'TSS, CTL, ATL, TSB метрики'),
        _featureItem(Icons.air, 'VO2max, VDOT, тренировочные зоны'),
        _featureItem(Icons.timer, 'Предсказание Riegel на другие дистанции'),
        _featureItem(Icons.local_fire_department, 'TDEE, BMR, БЖУ расчёт'),
        _featureItem(Icons.speed, 'FTP/Threshold/LTHR авто-определение'),
        _featureItem(Icons.favorite, 'Зоны пульса Карвонена'),
        _featureItem(Icons.flag, 'Цели и достижения'),
        _featureItem(Icons.map, 'Оффлайн-карты'),
        _featureItem(Icons.sync, 'Синхронизация с сервером'),
      ],
    );
  }

  Widget _featureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildReferenceTab(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final q = _refSearch.toLowerCase();
    bool matches(String title, String content) {
      if (q.isEmpty) return true;
      return title.toLowerCase().contains(q) || content.toLowerCase().contains(q);
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: Localizations.localeOf(context).languageCode == 'ru'
                ? 'Поиск по справочнику...'
                : 'Search reference...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _refSearch.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _refSearch = '';
                      _searchCtrl.clear();
                    }),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
          onChanged: (v) => setState(() => _refSearch = v),
        ),
        const SizedBox(height: 16),
        if (matches('VO2max', 'vo2max'))
        _referenceSection(
          context,
          title: 'VO2max (Jack Daniels)',
          icon: Icons.air,
          content: [
            _refParagraph(
              'VO2max — максимальный объём кислорода, который организм может '
              'потребить за минуту (мл/кг/мин). Показатель аэробной выносливости.',
            ),
            _refFormula('VO2max = -4.60 + 0.182258·v + 0.000104·v² / (0.8 + 0.1894393·e^(-0.012778·t) + 0.2989558·e^(-0.1932605·t))'),
            _refParagraph(
              'Расчёт через Health Connect: пульс покоя (HRrest) и максимальный пульс (HRmax). '
              'Точность ~90% от лабораторного теста.',
            ),
            _refTable([
              ['VO2max', 'Уровень'],
              ['20–30', 'Ниже среднего'],
              ['30–40', 'Средний'],
              ['40–50', 'Выше среднего'],
              ['50–60', 'Отличный'],
              ['60+', 'Элитный'],
            ]),
          ],
        ),
        const SizedBox(height: 24),
        if (matches('VDOT', 'vdot'))
        _referenceSection(
          context,
          title: 'VDOT (Training Zones)',
          icon: Icons.speed,
          content: [
            _refParagraph(
              'VDOT — индекс тренировочного темпа по Дэниелсу. '
              'Определяет зоны для каждого типа тренировки.',
            ),
            _refFormula('Зоны VDOT: E (65-79%), M (80-85%), T (86-90%), I (91-95%), R (96-100%)'),
            _refTable([
              ['Зона', 'Название', 'Описание'],
              ['E', 'Easy', 'Восстановительный темп (разговорный)'],
              ['M', 'Marathon', 'Марафонский темп'],
              ['T', 'Threshold', 'Пороговый темп (комфортно-трудно)'],
              ['I', 'Interval', 'Интервальный темп (3-5 мин)'],
              ['R', 'Repetition', 'Повторения (100-400м, отдых 2-3 мин)'],
            ]),
            _refParagraph(
              'Рассчитывается автоматически из VO2max. '
              'Чем выше VDOT, тем быстрее тренировочные темпы.',
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (matches('Riegel', 'riegel'))
        _referenceSection(
          context,
          title: 'Riegel Race Predictor',
          icon: Icons.timer,
          content: [
            _refParagraph(
              'Предсказание времени на другой дистанции по формуле Ригеля. '
              'Основан на законе степени: T₂ = T₁ × (D₂/D₁)^1.06',
            ),
            _refFormula('T₂ = T₁ × (D₂/D₁)^1.06'),
            _refParagraph(
              'Точность: ±2-3% для дистанций от 5 км до марафона. '
              'Показывает расчётные темпы по километрам.',
            ),
            _refTable([
              ['Дистанция', 'Пример (3:30 на 10км)'],
              ['5 км', '~1:42'],
              ['10 км', '~3:30'],
              ['Полумарафон', '~1:18:30'],
              ['Марафон', '~3:53:00'],
            ]),
          ],
        ),
        const SizedBox(height: 24),
        if (matches(isRu ? 'TDEE' : 'TDEE', 'tdee'))
        _referenceSection(
          context,
          title: isRu ? 'TDEE (Общий расход энергии)' : 'TDEE (Total Daily Energy Expenditure)',
          icon: Icons.local_fire_department,
          content: [
            _refParagraph(
              'TDEE = BMR × коэффициент активности. '
              'BMR рассчитывается по трём формулам:',
            ),
            _refFormula('Миффлин-Сент-Жеор: 10·вес + 6.25·рост − 5·возраст + 5'),
            _refFormula('Харрис-Бенедикт: 88.36 + 13.4·вес + 4.8·рост − 5.7·возраст'),
            _refFormula('Кэтч-Мак-Ардл: 370 + 21.6·(вес − жир)'),
            _refTable([
              ['Уровень активности', 'Коэффициент'],
              ['Сидячий (офис)', '1.2'],
              ['Лёгкая (1-3 р/нед)', '1.375'],
              ['Средняя (3-5 р/нед)', '1.55'],
              ['Высокая (6-7 р/нед)', '1.725'],
              ['Экстремальная', '1.9'],
            ]),
            _refParagraph(
              'При похудении: TDEE − 300-500 ккал. '
              'При наборе: TDEE + 300-500 ккал. '
              'БЖУ: белок 1.6-2.2 г/кг, жир 0.8-1.2 г/кг, углеводы — остаток.',
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (matches('Karvonen', 'karvonen'))
        _referenceSection(
          context,
          title: 'Karvonen HR Zones',
          icon: Icons.favorite,
          content: [
            _refParagraph(
              'Метод Карвонена использует резерв пульса (HRreserve) '
              'для более точного определения зон:',
            ),
            _refFormula('HRreserve = HRmax − HRrest'),
            _refFormula('Зона = HRreserve × % + HRrest'),
            _refTable([
              ['Зона', '% от HRreserve', 'Описание'],
              ['1', '50-60%', 'Восстановление'],
              ['2', '60-70%', 'Жиросжигание'],
              ['3', '70-80%', 'Аэробная выносливость'],
              ['4', '80-90%', 'Анаэробный порог'],
              ['5', '90-100%', 'Максимальная'],
            ]),
            _refParagraph(
              'Пример: HRmax=190, HRrest=50 → HRreserve=140. '
              'Зона 3 = 140×0.7 + 50 = 148 bpm.',
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (matches('FTP', 'ftp'))
        _referenceSection(
          context,
          title: 'FTP / Threshold / LTHR Auto-Detect',
          icon: Icons.speed,
          content: [
            _refParagraph(
              'Автоматическое определение пороговых значений по последним '
              '4 неделям тренировок через Health Connect:',
            ),
            _refFormula('FTP (FTP auto-detect) = средний NP за 20 мин × 0.95'),
            _refFormula('LTHR (LTHR auto-detect) = медиана максимальных HR за 20 мин'),
            _refFormula('Threshold Pace (FTP auto-detect) = 10-й перцентиль темпа за 20+ мин'),
            _refTable([
              ['Метрика', 'Источник', 'Пересчёт'],
              ['FTP', 'Велоспорт (NP)', 'Каждые 4 недели'],
              ['Threshold Pace', 'Бег (темп 20+ мин)', 'Каждые 4 недели'],
              ['LTHR', 'Любая (пульс 20+ мин)', 'Каждые 4 недели'],
            ]),
            _refFormula('NP (Normalized Power) = 4-е среднее кубов мощности'),
            _refFormula('IF = NP / FTP'),
            _refFormula('EF (Efficiency Factor) = темп / пульс'),
            _refFormula('Decoupling = (HR second half − HR first half) / HR first half × 100'),
          ],
        ),
        const SizedBox(height: 24),
        if (matches('TSS', 'tss'))
        _referenceSection(
          context,
          title: 'TSS (Training Stress Score)',
          icon: Icons.whatshot,
          content: [
            _refParagraph(
              'TSS — числовая оценка нагрузки тренировки. Чем длиннее и интенсивнее '
              'тренировка, тем выше TSS.',
            ),
            _refFormula('TSS = время (ч) × IF² × 100'),
            _refParagraph('Где IF (Intensity Factor) — коэффициент интенсивности:'),
            _refTable([
              ['Тип', 'IF', 'Пример TSS'],
              ['Бег (темп)', '0.75', '60 мин → 56'],
              ['Велосипед', '0.65', '60 мин → 42'],
              ['Силовая', '0.80', '60 мин → 64'],
              ['Ходьба', '0.35', '60 мин → 12'],
              ['Плавание', '0.70', '60 мин → 49'],
            ]),
            _refParagraph(
              'Если есть пульс — IF корректируется по пульсу. '
              'Оценка 1–3 (RPE) также влияет на расчёт.',
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (matches('CTL', 'ctl'))
        _referenceSection(
          context,
          title: 'CTL (Chronic Training Load)',
          icon: Icons.trending_up,
          content: [
            _refParagraph(
              'CTL — средняя нагрузка за 42 дня. Показывает базовую форму. '
              'Чем выше CTL, тем лучше подготовлен спортсмен.',
            ),
            _refFormula('CTL = EWMA(TSS, 42 дня)'),
            _refParagraph('Интерпретация CTL:'),
            _refTable([
              ['CTL', 'Описание'],
              ['< 30', 'Низкая форма'],
              ['30–60', 'Средняя форма'],
              ['60–100', 'Хорошая форма'],
              ['> 100', 'Отличная форма'],
            ]),
            _refParagraph(
              'CTL растёт медленно (за недели). Резкий рост CTL за короткий '
              'срок приводит к перетренировке.',
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (matches('ATL', 'atl'))
        _referenceSection(
          context,
          title: 'ATL (Acute Training Load)',
          icon: Icons.bolt,
          content: [
            _refParagraph(
              'ATL — средняя нагрузка за 7 дней. Показывает текущую усталость. '
              'Высокий ATL = тяжёлая неделя.',
            ),
            _refFormula('ATL = EWMA(TSS, 7 дней)'),
            _refParagraph('Интерпретация ATL:'),
            _refTable([
              ['ATL', 'Описание'],
              ['< 20', 'Минимальная нагрузка'],
              ['20–50', 'Лёгкая неделя'],
              ['50–80', 'Нормальная неделя'],
              ['80–120', 'Тяжёлая неделя'],
              ['> 120', 'Экстремальная нагрузка'],
            ]),
          ],
        ),
        const SizedBox(height: 24),
        if (matches('TSB', 'tsb'))
        _referenceSection(
          context,
          title: 'TSB (Training Stress Balance)',
          icon: Icons.balance,
          content: [
            _refParagraph(
              'TSB — разница между CTL и ATL. Показывает баланс между '
              'формой и усталостью.',
            ),
            _refFormula('TSB = CTL − ATL'),
            _refParagraph('Интерпретация TSB:'),
            _refTable([
              ['TSB', 'Состояние'],
              ['> +25', 'Отдых — организм восстановлен'],
              ['+5 … +25', 'Свежесть — готов к нагрузке'],
              ['−10 … +5', 'Нейтрально'],
              ['−30 … −10', 'Усталость — нужен отдых'],
              ['< −30', 'Перетренировка — риск травмы!'],
            ]),
            _refParagraph(
              'Перед соревнованием TSB должен быть положительным '
              '(+5 … +25) — это «относительная форма».',
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (matches('ACWR', 'acwr'))
        _referenceSection(
          context,
          title: 'ACWR (Acute:Chronic Workload Ratio)',
          icon: Icons.speed,
          content: [
            _refParagraph(
              'ACWR — соотношение острой и хронической нагрузки. '
              'Помогает оптимально дозировать тренировки.',
            ),
            _refFormula('ACWR = ATL / CTL'),
            _refParagraph('Интерпретация ACWR:'),
            _refTable([
              ['ACWR', 'Зона риска'],
              ['0.8–1.3', 'Оптимальная зона (sweet spot)'],
              ['> 1.5', 'Зона высокого риска травмы'],
              ['> 2.0', 'Опасная зона'],
            ]),
          ],
        ),
        const SizedBox(height: 24),
        if (matches('Восстановление Recovery', 'восстановление recovery'))
        _referenceSection(
          context,
          title: isRu ? 'Восстановление' : 'Recovery',
          icon: Icons.nightlight_round,
          content: [
            _refParagraph(
              'Приложение оценивает дни до восстановления на основе: '
              'ACWR, TSB, возраста и пульса покоя.',
            ),
            _refTable([
              ['Фактор', 'Влияние'],
              ['Возраст > 30', '+1 день за каждые 10 лет'],
              ['Пульс покоя > 70', '+1–2 дня'],
              ['Пульс покоя < 50', '−1 день (отличная форма)'],
            ]),
            _refParagraph(
              'Сон с низким пульсом покоя — лучший индикатор восстановления. '
              'Если пульс покоя высокий — организм ещё восстанавливается.',
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (matches(isRu ? 'Новые возможности' : 'New Features', isRu ? 'новые' : 'new'))
        _referenceSection(
          context,
          title: isRu ? 'Новые возможности ZAPFIT' : 'New Features ZAPFIT',
          icon: Icons.new_releases,
          content: isRu
              ? [
                  _refParagraph('ZAPFIT 0.8.7 — добавлены Похожие тренировки, выбор Камера/Галерея, поиск по справочнику, время в истории, системные уведомления и добавление точек на карте.'),
                  _refParagraph('Похожие тренировки: тап на карточке Анализ тренировки открывает список с процентом похожести (дистанция 35% + время 35% + скорость 30%, фильтр <25%).'),
                  _refParagraph('Карта в редактировании: точки маршрута добавляются тапом по карте, сохраняются локально и уйдут на сервер при следующем GPX-синхроне.'),
                  _refParagraph('RPE→TSS: оценка 1–10 сохраняется с TSS и показывается в деталях без редактирования.'),
                  _refParagraph('История: в списке теперь дата/время старта и длительность.'),
                  _refParagraph('Уведомления: серверные WebSocket/polling дублируются в системный трей.'),
                  _refParagraph('Версия берётся автоматически из pubspec через PackageInfo.'),
                ]
              : [
                  _refParagraph('ZAPFIT 0.8.7 — Similar workouts, Camera/Gallery picker, reference search, time in history, system notifications and map point editing.'),
                  _refParagraph('Similar workouts: tap on Analysis card opens list with similarity % (distance 35% + duration 35% + speed 30%, filter <25%).'),
                  _refParagraph('Map editing: tap on map to add track points, saved locally and uploaded via GPX on next sync.'),
                  _refParagraph('RPE→TSS: 1–10 rating saved with TSS and shown in details without editing.'),
                  _refParagraph('History: list now shows start date/time and duration.'),
                  _refParagraph('Notifications: server WebSocket/polling forwarded to system tray.'),
                  _refParagraph('Version auto from pubspec via PackageInfo.'),
                ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _referenceSection(BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> content,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...content,
          ],
        ),
      ),
    );
  }

  Widget _refParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(height: 1.5)),
    );
  }

  Widget _refFormula(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _refTable(List<List<String>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final header = rows.first;
    final data = rows.skip(1).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              children: header.map((h) => Expanded(
                child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              )).toList(),
            ),
          ),
          // Data rows
          ...data.map((row) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.5)),
            ),
            child: Row(
              children: row.map((cell) => Expanded(
                child: Text(cell, style: const TextStyle(fontSize: 12)),
              )).toList(),
            ),
          )),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
