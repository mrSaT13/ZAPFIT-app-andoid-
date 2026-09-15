import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadedRegionInfo {
  final String name;
  final double north, south, east, west;
  final int minZoom, maxZoom, tileCount;
  final String provider; // osm/topo/esri/carto — чтобы не показывать чужие тайлы
  const DownloadedRegionInfo({
    required this.name,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
    required this.minZoom,
    required this.maxZoom,
    required this.tileCount,
    this.provider = 'osm',
  });

  Map<String, dynamic> toJson() => {
    'name': name, 'north': north, 'south': south, 'east': east, 'west': west,
    'minZoom': minZoom, 'maxZoom': maxZoom, 'tileCount': tileCount,
    'provider': provider,
  };

  factory DownloadedRegionInfo.fromJson(Map<String, dynamic> j) => DownloadedRegionInfo(
    name: j['name'] as String,
    north: (j['north'] as num).toDouble(),
    south: (j['south'] as num).toDouble(),
    east: (j['east'] as num).toDouble(),
    west: (j['west'] as num).toDouble(),
    minZoom: (j['minZoom'] as num).toInt(),
    maxZoom: (j['maxZoom'] as num).toInt(),
    tileCount: (j['tileCount'] as num).toInt(),
    provider: (j['provider'] as String?) ?? 'osm',
  );
}

class MapCacheService {
  // Унифицированный корень offline_maps — чтобы скачанное совпадало с чтением
  Future<Directory> _offlineRoot() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'offline_maps'));
  }

  Future<int> cacheBounds({
    required double north,
    required double south,
    required double west,
    required double east,
    required int zoom,
    required String template,
    required String folderName,
  }) async {
    final rootBase = await _offlineRoot();
    final root = Directory(p.join(rootBase.path, folderName));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    final minX = _lonToTileX(west, zoom);
    final maxX = _lonToTileX(east, zoom);
    final minY = _latToTileY(north, zoom);
    final maxY = _latToTileY(south, zoom);

    var downloaded = 0;

    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        if (x < 0 || y < 0) {
          continue;
        }

        final url = template
            .replaceAll('{z}', '$zoom')
            .replaceAll('{x}', '$x')
            .replaceAll('{y}', '$y');

        final bytes = await _downloadBytes(url);
        if (bytes == null) {
          continue;
        }

        final tileFile = File(p.join(root.path, '$zoom', '$x', '$y.png'));
        await tileFile.parent.create(recursive: true);
        await tileFile.writeAsBytes(bytes, flush: true);
        downloaded++;
      }
    }

    return downloaded;
  }

  Future<int> cacheArea({
    required double centerLat,
    required double centerLon,
    required int zoom,
    required int radius,
    required String template,
    required String folderName,
  }) async {
    final rootBase = await _offlineRoot();
    final root = Directory(p.join(rootBase.path, folderName));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    final centerTileX = _lonToTileX(centerLon, zoom);
    final centerTileY = _latToTileY(centerLat, zoom);

    var downloaded = 0;

    for (var dx = -radius; dx <= radius; dx++) {
      for (var dy = -radius; dy <= radius; dy++) {
        final x = centerTileX + dx;
        final y = centerTileY + dy;
        if (x < 0 || y < 0) {
          continue;
        }

        final url = template
            .replaceAll('{z}', '$zoom')
            .replaceAll('{x}', '$x')
            .replaceAll('{y}', '$y');

        final bytes = await _downloadBytes(url);
        if (bytes == null) {
          continue;
        }

        final tileFile = File(p.join(root.path, '$zoom', '$x', '$y.png'));
        await tileFile.parent.create(recursive: true);
        await tileFile.writeAsBytes(bytes, flush: true);
        downloaded++;
      }
    }

    return downloaded;
  }

  static const _userAgent = 'com.dev.zapfit/1.0';

  Future<List<int>?> _downloadBytes(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  int _lonToTileX(double lon, int zoom) {
    return (((lon + 180.0) / 360.0) * (1 << zoom)).floor();
  }

  int _latToTileY(double lat, int zoom) {
    final latRad = lat * math.pi / 180.0;
    return ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2 *
            (1 << zoom))
        .floor();
  }

  Future<List<int>?> downloadTile(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTile(int z, int x, int y, List<int> bytes, {required String folderName}) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final tileFile = File(p.join(baseDir.path, 'offline_maps', folderName, '$z', '$x', '$y.png'));
    await tileFile.parent.create(recursive: true);
    await tileFile.writeAsBytes(bytes, flush: true);
  }

  Future<void> addDownloadedRegion({
    required String name,
    required double north, required double south,
    required double east, required double west,
    required int minZoom, required int maxZoom,
    required int tileCount,
    String provider = 'osm',
  }) async {
    final regions = await getDownloadedRegions();
    regions.removeWhere((r) => r.name == name);
    regions.add(DownloadedRegionInfo(
      name: name, north: north, south: south, east: east, west: west,
      minZoom: minZoom, maxZoom: maxZoom, tileCount: tileCount, provider: provider,
    ));
    await _saveRegions(regions);
  }

  Future<File?> getTileFile(int z, int x, int y, {String? provider}) async {
    try {
      final root = await _offlineRoot();
      final regions = await getDownloadedRegions();
      for (final r in regions) {
        if (z < r.minZoom || z > r.maxZoom) continue;
        if (provider != null && r.provider != provider) continue;
        final f = File(p.join(root.path, r.name, '$z', '$x', '$y.png'));
        if (await f.exists()) return f;
      }
      // fallback — любой провайдер если точного нет (для совместимости старых регионов без provider)
      for (final r in regions) {
        if (z < r.minZoom || z > r.maxZoom) continue;
        final f = File(p.join(root.path, r.name, '$z', '$x', '$y.png'));
        if (await f.exists()) return f;
      }
      final direct = File(p.join(root.path, '$z', '$x', '$y.png'));
      if (await direct.exists()) return direct;
      return null;
    } catch (_) { return null; }
  }

  Future<bool> hasTile(int z, int x, int y, {String? provider}) async => (await getTileFile(z, x, y, provider: provider)) != null;

  Future<List<DownloadedRegionInfo>> getDownloadedRegions() async {
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(baseDir.path, 'offline_maps', '_regions.json'));
      if (!await file.exists()) return [];
      final json = jsonDecode(await file.readAsString()) as List;
      return json.map((j) => DownloadedRegionInfo.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteRegion(String name) async {
    final regions = await getDownloadedRegions();
    regions.removeWhere((r) => r.name == name);
    await _saveRegions(regions);
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(baseDir.path, 'offline_maps', name));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> _saveRegions(List<DownloadedRegionInfo> regions) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(baseDir.path, 'offline_maps', '_regions.json'));
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(regions.map((r) => r.toJson()).toList()));
  }
}
