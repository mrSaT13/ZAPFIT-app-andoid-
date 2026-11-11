import 'dart:io';

import 'package:flutter/material.dart';

import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/core/utils/url_utils.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Exercise media (GIF animation + thumbnail) with a disk cache.
///
/// Files live on the server under `/exercise_media/{wger_id}.gif` (imported
/// once from the hasaneyldrm/exercises-dataset). The app downloads a GIF once
/// into the app documents folder (`exercise_media/{wger_id}.gif`) and serves
/// it from disk afterwards — the APK stays light.
class ExerciseMediaService {
  ExerciseMediaService._();

  static final ExerciseMediaService instance = ExerciseMediaService._();

  static const String _basePath = '/exercise_media';

  /// In-flight downloads to avoid parallel duplicate requests.
  final Map<int, Future<File?>> _pending = {};

  Directory? _cacheDir;

  Future<Directory> _dir() async {
    final cached = _cacheDir;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}exercise_media');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  /// Local cached GIF for [wgerId] or null (no cache, no server file).
  Future<File?> gifFile(int wgerId) async {
    final dir = await _dir();
    final f = File('${dir.path}${Platform.pathSeparator}$wgerId.gif');
    if (f.existsSync() && f.lengthSync() > 0) return f;
    return _download(wgerId);
  }

  /// Downloads once; concurrent callers share the same future.
  Future<File?> _download(int wgerId) {
    return _pending.putIfAbsent(wgerId, () => _downloadImpl(wgerId));
  }

  Future<File?> _downloadImpl(int wgerId) async {
    try {
      final serverUrl = await SecureStorageService().getServerUrl();
      if (serverUrl == null) return null;
      final base = UrlUtils.normalizeBaseUrl(serverUrl);
      final url = '$base$_basePath/$wgerId.gif';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200 && response.bodyBytes.length > 100) {
        final dir = await _dir();
        final f = File('${dir.path}${Platform.pathSeparator}$wgerId.gif');
        await f.writeAsBytes(response.bodyBytes);
        return f;
      }
      debugPrint(
          'ExerciseMediaService: status ${response.statusCode} for $wgerId');
    } catch (e) {
      debugPrint('ExerciseMediaService: download error for $wgerId: $e');
    }
    return null;
  }

  /// Cache stats for the settings screen (files, total MB).
  Future<({int files, double mb})> cacheStats() async {
    final dir = await _dir();
    final files = dir.existsSync()
        ? dir.listSync().whereType<File>().toList()
        : <File>[];
    final bytes =
        files.fold<int>(0, (sum, f) => sum + (f.existsSync() ? f.lengthSync() : 0));
    return (files: files.length, mb: bytes / 1024 / 1024);
  }

  /// Clears the disk cache.
  Future<void> clearCache() async {
    final dir = await _dir();
    if (dir.existsSync()) await dir.delete(recursive: true);
    _cacheDir = null;
  }
}

/// Animated GIF widget backed by [ExerciseMediaService]: shows the cached
/// file (or downloads it first) with a placeholder while loading; silently
/// blank when the exercise has no media.
class ExerciseGif extends StatefulWidget {
  const ExerciseGif({super.key, required this.wgerId, this.size = 180});

  final int wgerId;
  final double size;

  @override
  State<ExerciseGif> createState() => _ExerciseGifState();
}

class _ExerciseGifState extends State<ExerciseGif> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await ExerciseMediaService.instance.gifFile(widget.wgerId);
    if (mounted && f != null) setState(() => _file = f);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_file == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.fitness_center,
            size: widget.size * 0.35, color: theme.colorScheme.outline),
      );
    }
    // Flutter animates multi-frame GIFs natively via Image.
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        _file!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Icon(Icons.broken_image,
            size: widget.size * 0.3, color: theme.colorScheme.outline),
      ),
    );
  }
}
