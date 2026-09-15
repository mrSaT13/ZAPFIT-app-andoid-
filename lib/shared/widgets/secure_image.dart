import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:zapfit/core/services/api_client.dart';
import 'package:zapfit/core/di/service_locator.dart';

class ImageCache {
  ImageCache._();
  static final ImageCache instance = ImageCache._();

  final Map<String, Uint8List> _bytesCache = {};
  final Map<String, Future<Uint8List?>> _futureCache = {};
  final Set<String> _failed = {};
  final DefaultCacheManager _diskCache = DefaultCacheManager();

  bool isFailed(String url) => _failed.contains(url);
  bool hasCached(String url) => _bytesCache.containsKey(url);
  Uint8List? getCached(String url) => _bytesCache[url];

  Future<Uint8List?> load(String url) {
    if (_failed.contains(url)) return Future.value(null);
    if (_bytesCache.containsKey(url)) return Future.value(_bytesCache[url]);

    return _futureCache.putIfAbsent(url, () async {
      try {
        final file = await _diskCache.getSingleFile(url);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            _bytesCache[url] = bytes;
            _futureCache.remove(url);
            return bytes;
          }
        }
      } catch (_) {}

      try {
        final bytes = await serviceLocator<ApiClient>().getImageBytes(url);
        if (bytes != null && bytes.isNotEmpty) {
          _bytesCache[url] = bytes;
          _futureCache.remove(url);
          return bytes;
        }
        _failed.add(url);
        _futureCache.remove(url);
        return null;
      } catch (e) {
        _failed.add(url);
        _futureCache.remove(url);
        return null;
      }
    });
  }

  void clear() {
    _bytesCache.clear();
    _futureCache.clear();
    _failed.clear();
  }
}

class SecureImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  const SecureImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius = 0,
    this.fallbackIcon = Icons.map_outlined,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return _buildFallback(context);

    if (ImageCache.instance.hasCached(imageUrl!)) {
      final cached = ImageCache.instance.getCached(imageUrl!);
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.memory(cached!, width: width, height: height, fit: fit),
      );
    }

    if (ImageCache.instance.isFailed(imageUrl!)) return _buildFallback(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: FutureBuilder<Uint8List?>(
        future: ImageCache.instance.load(imageUrl!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return placeholder ??
                Container(
                  width: width,
                  height: height,
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  child: const Center(
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!, width: width, height: height, fit: fit);
          }
          return errorWidget ?? _buildFallback(context);
        },
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final color = fallbackColor ?? Theme.of(context).colorScheme.outline;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(fallbackIcon, color: color.withOpacity(0.7), size: 32),
            const SizedBox(height: 4),
            Text('Нет изображения', style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
