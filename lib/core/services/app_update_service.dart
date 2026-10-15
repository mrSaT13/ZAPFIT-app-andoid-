import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Информация о релизе с GitHub.
class AppReleaseInfo {
  final String tag;
  final String name;
  final String body;
  final String htmlUrl;
  final String downloadUrl;
  final String version;
  final int build;
  final DateTime? publishedAt;
  final int sizeBytes;

  const AppReleaseInfo({
    required this.tag,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.downloadUrl,
    required this.version,
    required this.build,
    required this.publishedAt,
    required this.sizeBytes,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = (json['tag_name'] ?? '') as String;
    final parsed = AppUpdateService.parseTag(tag);
    String downloadUrl = (json['html_url'] ?? '') as String;
    int sizeBytes = 0;
    final assets = json['assets'] as List?;
    if (assets != null) {
      for (final a in assets) {
        final m = a as Map<String, dynamic>;
        final assetName = (m['name'] ?? '').toString().toLowerCase();
        if (assetName.endsWith('.apk')) {
          downloadUrl = (m['browser_download_url'] ?? downloadUrl).toString();
          sizeBytes = (m['size'] ?? 0) as int;
          break;
        }
      }
    }
    DateTime? published;
    try {
      final p = json['published_at']?.toString();
      if (p != null && p.isNotEmpty) published = DateTime.parse(p);
    } catch (_) {}
    return AppReleaseInfo(
      tag: tag,
      name: (json['name'] ?? tag).toString(),
      body: (json['body'] ?? '').toString(),
      htmlUrl: (json['html_url'] ?? '').toString(),
      downloadUrl: downloadUrl,
      version: parsed.version,
      build: parsed.build,
      publishedAt: published,
      sizeBytes: sizeBytes,
    );
  }

  /// true, если релиз новее установленной версии.
  bool isNewerThan(String currentVersion, int currentBuild) {
    final cmp = AppUpdateService.compareVersions(version, currentVersion);
    if (cmp != 0) return cmp > 0;
    return build > currentBuild;
  }

  String get shortVersion => build > 0 ? 'v$version+$build' : 'v$version';
}

/// Проверка обновлений ZAPFIT через GitHub Releases.
///
/// Релизы публикуются в репозитории `mrSaT13/ZAPFIT-app-andoid-`
/// (теги вида `MC_ZAPFITv0.8.9+38`).
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String owner = 'mrSaT13';
  static const String releasesRepo = 'ZAPFIT-app-andoid-';

  static String get releasesPageUrl =>
      'https://github.com/$owner/$releasesRepo/releases';
  static String get _latestApiUrl =>
      'https://api.github.com/repos/$owner/$releasesRepo/releases/latest';

  static const String _lastCheckKey = 'zapfit_update_last_check';
  static const Duration autoCheckInterval = Duration(hours: 24);

  /// Разбирает тег вида `MC_ZAPFITv0.8.9+38` -> (version: 0.8.9, build: 38).
  static ({String version, int build}) parseTag(String tag) {
    final m = RegExp(r'(\d+\.\d+\.\d+)(?:\+(\d+))?').firstMatch(tag);
    if (m == null) return (version: '', build: 0);
    return (
      version: m.group(1) ?? '',
      build: int.tryParse(m.group(2) ?? '') ?? 0,
    );
  }

  /// Сравнение версий `x.y.z`: 1 — a новее, -1 — старее, 0 — равны.
  static int compareVersions(String a, String b) {
    List<int> pa() {
      return a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    }

    List<int> pb() {
      return b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    }

    final la = pa();
    final lb = pb();
    for (var i = 0; i < 3; i++) {
      final x = i < la.length ? la[i] : 0;
      final y = i < lb.length ? lb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  /// Возвращает релиз, если на GitHub есть версия новее установленной.
  /// Ошибки сети глушатся — возвращается null.
  Future<AppReleaseInfo?> checkForUpdate() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(pkg.buildNumber) ?? 0;
      final currentVersion = pkg.version;
      final res = await http
          .get(Uri.parse(_latestApiUrl),
              headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final release = AppReleaseInfo.fromJson(json);
      if (release.version.isEmpty) return null;
      if (release.isNewerThan(currentVersion, currentBuild)) return release;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Тихая автопроверка при запуске: не чаще раза в сутки,
  /// диалог — только если найдено обновление.
  Future<void> checkOnStartup(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < autoCheckInterval.inMilliseconds) return;
      final release = await checkForUpdate();
      if (!context.mounted) return;
      await prefs.setInt(_lastCheckKey, now);
      if (release != null && context.mounted) {
        await showUpdateDialog(context, release);
      }
    } catch (_) {}
  }

  /// Ручная проверка по кнопке: со спиннером и результатом в любом случае.
  Future<void> checkManually(BuildContext context) async {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(isRu ? 'Проверка обновлений…' : 'Checking for updates…'),
              ],
            ),
          ),
        ),
      ),
    );
    final release = await checkForUpdate();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted) return;
    if (release != null) {
      await showUpdateDialog(context, release);
    } else {
      await showUpToDateDialog(context);
    }
  }

  /// Стильный диалог о доступном обновлении: версии, описание, кнопка скачать.
  Future<void> showUpdateDialog(
      BuildContext context, AppReleaseInfo release) async {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final theme = Theme.of(context);
    final pkg = await PackageInfo.fromPlatform();
    final currentShort =
        'v${pkg.version}+${pkg.buildNumber}';
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.system_update,
            size: 32,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(isRu ? 'Доступно обновление' : 'Update available'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Chip(
                    label: Text(currentShort),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Icon(Icons.arrow_forward, size: 18),
                  Chip(
                    label: Text(
                      release.shortVersion,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _metaLine(release, isRu),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Text(
                isRu ? 'Что нового:' : "What's new:",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _cleanReleaseBody(release.body),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(height: 1.45),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isRu ? 'Позже' : 'Later'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: Text(isRu ? 'Скачать' : 'Download'),
            onPressed: () async {
              final uri = Uri.parse(release.downloadUrl);
              try {
                final ok = await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
                if (!ok && ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(isRu
                          ? 'Не удалось открыть ссылку'
                          : 'Could not open the link'),
                    ),
                  );
                }
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(isRu
                          ? 'Не удалось открыть ссылку'
                          : 'Could not open the link'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  /// Диалог «у вас последняя версия» для ручной проверки.
  Future<void> showUpToDateDialog(BuildContext context) async {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final theme = Theme.of(context);
    final pkg = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.green.withValues(alpha: 0.15),
          child: const Icon(Icons.check_circle_outline,
              size: 32, color: Colors.green),
        ),
        title: Text(isRu ? 'Обновлений нет' : 'No updates'),
        content: Text(
          isRu
              ? 'Установлена последняя версия\nv${pkg.version} (${pkg.buildNumber}).\nАвтопроверка выполняется при каждом запуске.'
              : 'You have the latest version\nv${pkg.version} (${pkg.buildNumber}).\nAuto-check runs on every launch.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isRu ? 'Хорошо' : 'OK'),
          ),
        ],
      ),
    );
  }

  String _metaLine(AppReleaseInfo r, bool isRu) {
    final parts = <String>[r.name];
    if (r.publishedAt != null) {
      final d = r.publishedAt!.toLocal();
      parts.add(
          '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}');
    }
    if (r.sizeBytes > 0) {
      parts.add('${(r.sizeBytes / 1048576).toStringAsFixed(1)} ${isRu ? 'МБ' : 'MB'}');
    }
    return parts.join(' · ');
  }

  /// Чистим markdown релиза для компактного показа в диалоге.
  String _cleanReleaseBody(String body) {
    var t = body;
    t = t.replaceAll(RegExp(r'<img[^>]*>', multiLine: true), '');
    t = t.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');
    t = t.replaceAllMapped(
        RegExp(r'\[(.*?)\]\(.*?\)'), (m) => m.group(1) ?? '');
    t = t.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    t = t.replaceAll('**', '');
    t = t.replaceAll(RegExp(r'^---+\s*$', multiLine: true), '');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    t = t.trim();
    if (t.length > 2000) t = '${t.substring(0, 2000)}…';
    return t.isEmpty ? '—' : t;
  }
}
