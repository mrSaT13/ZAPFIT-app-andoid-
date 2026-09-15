import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:zapfit/core/services/map_cache_service.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/constants/map_constants.dart';

class OfflineMapDownloadScreen extends StatefulWidget {
  const OfflineMapDownloadScreen({super.key});

  @override
  State<OfflineMapDownloadScreen> createState() => _OfflineMapDownloadScreenState();
}

class _OfflineMapDownloadScreenState extends State<OfflineMapDownloadScreen> {
  final MapController _mapController = MapController();
  final MapCacheService _cacheService = MapCacheService();

  double _north = 56.0;
  double _south = 54.0;
  double _east = 38.0;
  double _west = 36.0;
  int _maxZoom = 14;
  int _minZoom = 8;
  bool _isDownloading = false;
  int _downloaded = 0;
  int _total = 0;
  String _status = '';
  List<DownloadedRegionInfo> _downloadedRegions = [];

  @override
  void initState() {
    super.initState();
    _loadDownloadedRegions();
  }

  Future<void> _loadDownloadedRegions() async {
    final regions = await _cacheService.getDownloadedRegions();
    if (mounted) setState(() => _downloadedRegions = regions);
  }

  Future<void> _startDownload() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloaded = 0;
      _total = 0;
      _status = 'Подготовка...';
    });

    try {
      final settings = AppSettingsController.instance;
      final template = _getTileTemplate(settings.mapStyle.name);

      int totalTiles = 0;
      for (int z = _minZoom; z <= _maxZoom; z++) {
        final minX = _lonToTileX(_west, z);
        final maxX = _lonToTileX(_east, z);
        final minY = _latToTileY(_north, z);
        final maxY = _latToTileY(_south, z);
        totalTiles += (maxX - minX + 1) * (maxY - minY + 1);
      }

      setState(() {
        _total = totalTiles;
        _status = 'Скачивание 0 из $totalTiles';
      });

      int downloaded = 0;
      for (int z = _minZoom; z <= _maxZoom; z++) {
        if (!_isDownloading) break;
        final minX = _lonToTileX(_west, z);
        final maxX = _lonToTileX(_east, z);
        final minY = _latToTileY(_north, z);
        final maxY = _latToTileY(_south, z);

        for (var x = minX; x <= maxX; x++) {
          for (var y = minY; y <= maxY; y++) {
            if (!_isDownloading) break;
            final url = template
                .replaceAll('{z}', '$z')
                .replaceAll('{x}', '$x')
                .replaceAll('{y}', '$y');
            final bytes = await _cacheService.downloadTile(url);
            if (bytes != null) {
              await _cacheService.saveTile(z, x, y, bytes, folderName: _regionName());
              downloaded++;
              if (mounted) {
                setState(() {
                  _downloaded = downloaded;
                  _status = 'Скачивание $downloaded из $totalTiles';
                });
              }
            }
          }
        }
      }

      if (_isDownloading && mounted) {
        final prov = settings.mapProvider == AppSettingsController.instance.mapProvider
            ? _providerKey(settings.mapProvider.name, settings.mapStyle.name)
            : 'osm';
        // _providerKey использует текущий провайдер из настроек
        await _cacheService.addDownloadedRegion(
          name: _regionName(),
          north: _north,
          south: _south,
          east: _east,
          west: _west,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
          tileCount: downloaded,
          provider: _providerKey(settings.mapProvider.name, settings.mapStyle.name),
        );
        _loadDownloadedRegions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Скачано $downloaded тайлов'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _status = 'Готово';
        });
      }
    }
  }

  void _stopDownload() {
    setState(() => _isDownloading = false);
  }

  String _regionName() {
    return '${_south.toStringAsFixed(1)}-${_north.toStringAsFixed(1)}_${_west.toStringAsFixed(1)}-${_east.toStringAsFixed(1)}';
  }

  String _getTileTemplate(String mapStyle) {
    switch (mapStyle) {
      case 'topographic':
        return 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  String _providerKey(String providerName, String styleName) {
    // esri/cartotopo требуют отдельных тайлов — иначе покажем osm где есть
    if (providerName.toLowerCase().contains('esri')) return 'esri';
    if (providerName.toLowerCase().contains('carto')) return 'carto';
    if (styleName == 'topographic') return 'topo';
    return 'osm';
  }

  static int _lonToTileX(double lon, int zoom) => ((lon + 180.0) / 360.0 * (1 << zoom)).floor();

  static int _latToTileY(double lat, int zoom) {
    final latRad = lat * math.pi / 180.0;
    return ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * (1 << zoom)).floor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оффлайн карты'),
        actions: [
          if (_isDownloading)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopDownload,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(38.7223, -9.1393),
                initialZoom: 10,
                onPositionChanged: (pos, _) {
                  if (pos.zoom != null) {
                    final bounds = _mapController.camera.visibleBounds;
                    setState(() {
                      _north = bounds.north;
                      _south = bounds.south;
                      _east = bounds.east;
                      _west = bounds.west;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: MapConstants.userAgent,
                ),
                PolylineLayer(polylines: [
                  Polyline(
                    points: [
                      LatLng(_north, _west),
                      LatLng(_north, _east),
                      LatLng(_south, _east),
                      LatLng(_south, _west),
                      LatLng(_north, _west),
                    ],
                    color: Colors.blue.withValues(alpha: 0.5),
                    strokeWidth: 3,
                  ),
                ]),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Выберите область на карте', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Область: ${_south.toStringAsFixed(2)}°–${_north.toStringAsFixed(2)}° N, '
                            '${_west.toStringAsFixed(2)}°–${_east.toStringAsFixed(2)}° E'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Зум: '),
                            Expanded(
                              child: RangeSlider(
                                values: RangeValues(_minZoom.toDouble(), _maxZoom.toDouble()),
                                min: 1, max: 18,
                                divisions: 17,
                                labels: RangeLabels('$_minZoom', '$_maxZoom'),
                                onChanged: (v) => setState(() {
                                  _minZoom = v.start.round();
                                  _maxZoom = v.end.round();
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_isDownloading) ...[
                          LinearProgressIndicator(value: _total > 0 ? _downloaded / _total : 0),
                          const SizedBox(height: 4),
                          Text(_status, style: const TextStyle(fontSize: 12)),
                        ] else
                          Text('Примерное количество тайлов: ~$_total', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isDownloading ? null : _startDownload,
                            icon: Icon(_isDownloading ? Icons.hourglass_empty : Icons.download),
                            label: Text(_isDownloading ? 'Скачивание...' : 'Скачать регион'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_downloadedRegions.isNotEmpty) ...[
                  const Text('Скачанные регионы', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._downloadedRegions.map((r) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.map),
                      title: Text(r.name),
                      subtitle: Text('${r.tileCount} тайлов • зум ${r.minZoom}-${r.maxZoom} • ${r.provider}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await _cacheService.deleteRegion(r.name);
                          _loadDownloadedRegions();
                        },
                      ),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
