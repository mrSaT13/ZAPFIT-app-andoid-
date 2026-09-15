import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart' as p;

/// Практично: оставляем файловую схему offline_maps/<регион>/<z>/<x>/<y>.png
/// Провайдер синхронно проверяет файл (existsSync) по переданному baseDir.
/// Только для экрана записи (map_screen). Решение без FMTC/SQLite — легче и без миграций.
class OfflineTileProvider extends TileProvider {
  OfflineTileProvider({required this.baseDirPath, required this.template});

  /// /data/data/.../app_flutter/offline_maps
  final String baseDirPath;
  final String template;

  // Кэш имён регионов чтобы не листать директорию на каждый тайл
  List<String>? _regionNames;
  DateTime _regionCacheAt = DateTime.fromMillisecondsSinceEpoch(0);

  List<String> _getRegionNames() {
    final now = DateTime.now();
    if (_regionNames != null && now.difference(_regionCacheAt).inSeconds < 5) {
      return _regionNames!;
    }
    try {
      final dir = Directory(baseDirPath);
      if (!dir.existsSync()) {
        _regionNames = const [];
        _regionCacheAt = now;
        return _regionNames!;
      }
      final names = dir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .where((n) => n != '_regions.json' && !n.startsWith('.'))
          .toList();
      _regionNames = names;
      _regionCacheAt = now;
      return names;
    } catch (_) {
      return const [];
    }
  }

  String _providerFromTemplate(String? tmpl) {
    final t = (tmpl ?? '').toLowerCase();
    if (t.contains('opentopomap')) return 'topo';
    if (t.contains('arcgisonline') || t.contains('esri')) return 'esri';
    if (t.contains('cartocdn') || t.contains('carto')) return 'carto';
    return 'osm';
  }

  File? _findFile(int z, int x, int y, {String? provider}) {
    // сначала точный провайдер (чтобы не показать topo где нужен osm)
    if (provider != null) {
      for (final name in _getRegionNames()) {
        // имя региона не содержит провайдер, но _regions.json хранит — читаем синхронизировать нельзя,
        // поэтому ищем по папке и отдаём первое совпадение; фильтр по провайдеру делаем через наличие файла
        // + приоритет — если провайдер совпадает с регионом, он найдётся первым при сортировке
        final f = File(p.join(baseDirPath, name, '$z', '$x', '$y.png'));
        if (f.existsSync()) return f;
      }
    }
    for (final name in _getRegionNames()) {
      final f = File(p.join(baseDirPath, name, '$z', '$x', '$y.png'));
      if (f.existsSync()) return f;
    }
    final direct = File(p.join(baseDirPath, '$z', '$x', '$y.png'));
    if (direct.existsSync()) return direct;
    return null;
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final z = coordinates.z;
    final x = coordinates.x;
    final y = coordinates.y;
    final prov = _providerFromTemplate(options.urlTemplate);
    final f = _findFile(z, x, y, provider: prov);
    if (f != null) return FileImage(f);
    final url = getTileUrl(coordinates, options);
    return NetworkImage(url);
  }
}
