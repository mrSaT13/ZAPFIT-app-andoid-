import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';

class OllamaService {
  OllamaService._();
  static final OllamaService instance = OllamaService._();

  final AppSettingsController _settings = AppSettingsController.instance;

  static const _defaultBaseUrl = 'https://ollama.com';

  /// List available models via GET {baseUrl}/api/tags
  Future<List<String>> listModels({String? baseUrl, String? apiKey}) async {
    final url = _buildUrl(baseUrl, '/api/tags');
    final headers = _buildHeaders(apiKey);
    try {
      final resp = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        debugPrint('Ollama listModels ${resp.statusCode}: ${resp.body}');
        return _fallbackModels;
      }
      final decoded = json.decode(resp.body);
      final List models = decoded is Map ? (decoded['models'] as List? ?? []) : (decoded as List? ?? []);
      final names = models.map((m) {
        if (m is Map) return (m['name'] ?? m['model'] ?? '').toString();
        return m.toString();
      }).where((n) => n.isNotEmpty).toList();
      if (names.isEmpty) return _fallbackModels;
      return names;
    } catch (e) {
      debugPrint('Ollama listModels error: $e');
      return _fallbackModels;
    }
  }

  /// Generate comment for activity via POST {baseUrl}/api/chat (non-stream)
  Future<String> generateComment({
    required ActivityRecord activity,
    double? totalAscent,
    double? totalDescent,
    int? avgHr,
    int? maxHr,
    double? tss,
    double? avgSpeed,
    double? avgPace, // min per km
    String? modelOverride,
    String? apiKeyOverride,
    String? baseUrlOverride,
    String? promptTemplateOverride,
  }) async {
    final baseUrl = (baseUrlOverride ?? _settings.ollamaBaseUrl).trim();
    final model = (modelOverride ?? _settings.ollamaModel).trim();
    final apiKey = apiKeyOverride ?? await _settings.getOllamaApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Ollama API key не задан. Укажите ключ в настройках.');
    }
    if (model.isEmpty) throw Exception('Модель Ollama не выбрана');

    final metrics = await _buildMetricsContextAsync(
      activity: activity,
      totalAscent: totalAscent,
      totalDescent: totalDescent,
      avgHr: avgHr,
      maxHr: maxHr,
      tss: tss,
      avgSpeed: avgSpeed,
      avgPace: avgPace,
    );
    final template = (promptTemplateOverride ?? _settings.ollamaPromptTemplate).trim();
    final userPrompt = _interpolate(template, metrics);
    final systemPrompt = 'Ты — дружелюбный тренер по бегу/велоспорту. Отвечай кратко, мотивирующе, без эмодзи, на русском языке. 2-3 предложения.';

    final url = _buildUrl(baseUrl, '/api/chat');
    final headers = _buildHeaders(apiKey);
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'stream': false,
    });

    http.Response resp;
    try {
      resp = await http.post(Uri.parse(url), headers: headers, body: body).timeout(const Duration(seconds: 22));
    } on TimeoutException {
      // one retry with shorter timeout
      debugPrint('Ollama timeout, retry once');
      try {
        resp = await http.post(Uri.parse(url), headers: headers, body: body).timeout(const Duration(seconds: 18));
      } on TimeoutException {
        throw Exception('Таймаут: сервер Ollama не ответил за 22с. Проверьте интернет, API ключ и модель. Попробуйте модель меньше (gemma4:31b) или baseUrl https://ollama.com');
      }
    } on http.ClientException catch (e) {
      throw Exception('Сеть: ${e.message}. Проверьте интернет и baseUrl $baseUrl');
    }
    if (resp.statusCode != 200) {
      debugPrint('Ollama chat ${resp.statusCode}: ${resp.body}');
      final err = _extractError(resp.body);
      if (resp.statusCode == 401 || resp.statusCode == 403) throw Exception('Ошибка авторизации (${resp.statusCode}): проверьте API ключ в настройках. $err');
      if (resp.statusCode == 404) throw Exception('Модель не найдена (404): проверьте название модели $model и baseUrl $baseUrl');
      if (resp.statusCode == 429) throw Exception('Лимит запросов (429): подождите минуту и попробуйте снова');
      throw Exception('Ollama ошибка ${resp.statusCode}: $err');
    }
    final decoded = json.decode(resp.body);
    // Ollama chat returns {message:{content:...}} or {response:...}
    String? content;
    if (decoded is Map) {
      final msg = decoded['message'];
      if (msg is Map && msg['content'] is String) content = msg['content'] as String;
      content ??= decoded['response'] as String?;
      // OpenAI compatible fallback: choices[0].message.content
      if (content == null && decoded['choices'] is List) {
        final c = (decoded['choices'] as List).first;
        if (c is Map) {
          final m = c['message'];
          if (m is Map) content = m['content'] as String?;
        }
      }
    }
    if (content == null || content.trim().isEmpty) {
      throw Exception('Пустой ответ от Ollama');
    }
    // sanitize: remove emojis остатки
    return _sanitize(content.trim());
  }

  String _buildUrl(String? base, String path) {
    final b = (base == null || base.isEmpty) ? _defaultBaseUrl : base;
    final normalized = b.replaceAll(RegExp(r'/+$'), '');
    return '$normalized$path';
  }

  Map<String, String> _buildHeaders(String? apiKey) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (apiKey != null && apiKey.isNotEmpty) {
      h['Authorization'] = 'Bearer $apiKey';
    }
    return h;
  }

  String _extractError(String body) {
    try {
      final d = json.decode(body);
      if (d is Map && d['error'] != null) return d['error'].toString();
    } catch (_) {}
    return body.length > 200 ? '${body.substring(0, 200)}...' : body;
  }

  Future<Map<String, String>> _buildMetricsContextAsync({
    required ActivityRecord activity,
    double? totalAscent,
    double? totalDescent,
    int? avgHr,
    int? maxHr,
    double? tss,
    double? avgSpeed,
    double? avgPace,
  }) async {
    final distKm = (activity.distanceMeters / 1000).toStringAsFixed(2);
    final dur = _formatDuration(activity.durationSeconds);
    final pace = avgPace != null && avgPace > 0 ? '${avgPace.toStringAsFixed(1)} мин/км' : '-';
    final speed = avgSpeed != null ? '${avgSpeed.toStringAsFixed(1)} км/ч' : '-';

    // Профиль пользователя
    final s = _settings;
    final ageStr = s.userAge?.toString() ?? '-';
    final weightStr = s.userWeight.toStringAsFixed(1);
    final heightStr = s.userHeight.toStringAsFixed(0);
    final genderStr = s.userGender;
    final cityStr = s.userCity.isNotEmpty ? s.userCity : '-';
    final ftpStr = s.userFtp > 0 ? s.userFtp.toStringAsFixed(0) : '-';
    final vo2maxStr = s.userVo2max > 0 ? s.userVo2max.toStringAsFixed(1) : '-';
    final restingHrStr = s.userRestingHeartRate.toString();
    final maxHrProfileStr = s.userMaxHeartRate.toString();
    final hrvStr = s.userHrvRmssd > 0 ? s.userHrvRmssd.toStringAsFixed(0) : '-';
    final waistStr = s.userWaistCm > 0 ? s.userWaistCm.toStringAsFixed(1) : '-';
    final hipStr = s.userHipCm > 0 ? s.userHipCm.toStringAsFixed(1) : '-';
    final neckStr = s.userNeckCm > 0 ? s.userNeckCm.toStringAsFixed(1) : '-';
    final systolicStr = s.userSystolic > 0 ? s.userSystolic.toString() : '-';
    final diastolicStr = s.userDiastolic > 0 ? s.userDiastolic.toString() : '-';

    // Здоровье за сегодня: сон, вода, шаги, вес
    String sleepStr = '-';
    String sleepScoreStr = '-';
    String sleepHoursStr = '-';
    String waterStr = '-';
    String stepsStr = '-';
    String latestWeightStr = weightStr;
    String bmiStr = '-';
    try {
      final repo = LocalActivityRepository.instance;
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      List<SleepRecord> sleepRecords = [];
      List<WaterRecord> waterRecords = [];
      List<StepsRecord> stepsRecords = [];
      List<WeightRecord> weightRecords = [];
      try { sleepRecords = await repo.getSleepRecords().timeout(const Duration(seconds: 2)); } catch (_) {}
      try { waterRecords = await repo.getWaterRecords().timeout(const Duration(seconds: 2)); } catch (_) {}
      try { stepsRecords = await repo.getStepsRecords().timeout(const Duration(seconds: 2)); } catch (_) {}
      try { weightRecords = await repo.getWeightRecords().timeout(const Duration(seconds: 2)); } catch (_) {}
      if (sleepRecords.isNotEmpty) {
        final todaySleep = sleepRecords.firstWhere(
          (r) => r.date.toIso8601String().startsWith(todayStr),
          orElse: () => sleepRecords.first,
        );
        final hrs = todaySleep.totalSleepSeconds / 3600.0;
        sleepHoursStr = hrs > 0 ? hrs.toStringAsFixed(1) : '-';
        sleepStr = hrs > 0 ? '${hrs.toStringAsFixed(1)} ч' : '-';
        sleepScoreStr = todaySleep.sleepScoreOverall?.toString() ?? '-';
      }
      double waterMl = 0;
      for (final r in waterRecords) {
        if (r.date.toIso8601String().startsWith(todayStr)) waterMl += r.amountMl;
      }
      if (waterMl > 0) waterStr = '${(waterMl / 1000).toStringAsFixed(2)} л (${waterMl.toStringAsFixed(0)} мл)';

      int stepsToday = 0;
      for (final r in stepsRecords) {
        if (r.date.toIso8601String().startsWith(todayStr)) stepsToday += r.steps;
      }
      if (stepsToday > 0) stepsStr = stepsToday.toString();

      if (weightRecords.isNotEmpty) {
        final w = weightRecords.first.weight;
        latestWeightStr = w.toStringAsFixed(1);
        // BMI
        final hM = s.userHeight / 100;
        if (hM > 0) {
          final bmi = w / (hM * hM);
          bmiStr = bmi.toStringAsFixed(1);
        }
      } else {
        final hM = s.userHeight / 100;
        if (hM > 0) bmiStr = (s.userWeight / (hM * hM)).toStringAsFixed(1);
      }
    } catch (e) {
      debugPrint('Ollama health context error: $e');
    }

    return {
      'kind': activity.kind.labelRu,
      'distance': distKm,
      'duration': dur,
      'pace': pace,
      'speed': speed,
      'avgHr': (avgHr ?? activity.avgHeartRate ?? 0).toString(),
      'maxHr': (maxHr ?? activity.maxHeartRate ?? 0).toString(),
      'ascent': (totalAscent ?? 0).toStringAsFixed(0),
      'descent': (totalDescent ?? 0).toStringAsFixed(0),
      'tss': tss != null ? tss.toStringAsFixed(0) : '-',
      'title': activity.title ?? activity.kind.labelRu,
      // профиль
      'weight': latestWeightStr,
      'height': heightStr,
      'age': ageStr,
      'gender': genderStr,
      'city': cityStr,
      'ftp': ftpStr,
      'vo2max': vo2maxStr,
      'restingHr': restingHrStr,
      'maxHrProfile': maxHrProfileStr,
      'hrv': hrvStr,
      'waist': waistStr,
      'hip': hipStr,
      'neck': neckStr,
      'systolic': systolicStr,
      'diastolic': diastolicStr,
      'bmi': bmiStr,
      // здоровье сегодня
      'sleep': sleepStr,
      'sleepHours': sleepHoursStr,
      'sleepScore': sleepScoreStr,
      'water': waterStr,
      'steps': stepsStr,
      // алиасы для удобства шаблона
      'sleepToday': sleepStr,
      'waterToday': waterStr,
      'stepsToday': stepsStr,
    };
  }

  // legacy sync wrapper (не используется, оставлен для совместимости)
  Map<String, String> _buildMetricsContext({
    required ActivityRecord activity,
    double? totalAscent,
    double? totalDescent,
    int? avgHr,
    int? maxHr,
    double? tss,
    double? avgSpeed,
    double? avgPace,
  }) {
    final distKm = (activity.distanceMeters / 1000).toStringAsFixed(2);
    final dur = _formatDuration(activity.durationSeconds);
    final pace = avgPace != null && avgPace > 0 ? '${avgPace.toStringAsFixed(1)} мин/км' : '-';
    final speed = avgSpeed != null ? '${avgSpeed.toStringAsFixed(1)} км/ч' : '-';
    return {
      'kind': activity.kind.labelRu,
      'distance': distKm,
      'duration': dur,
      'pace': pace,
      'speed': speed,
      'avgHr': (avgHr ?? activity.avgHeartRate ?? 0).toString(),
      'maxHr': (maxHr ?? activity.maxHeartRate ?? 0).toString(),
      'ascent': (totalAscent ?? 0).toStringAsFixed(0),
      'descent': (totalDescent ?? 0).toStringAsFixed(0),
      'tss': tss != null ? tss.toStringAsFixed(0) : '-',
      'title': activity.title ?? activity.kind.labelRu,
    };
  }

  String _interpolate(String template, Map<String, String> vars) {
    var out = template;
    vars.forEach((k, v) {
      out = out.replaceAll('{$k}', v);
    });
    // Если шаблон старый и не содержит новые ключи здоровья — дописываем их отдельным блоком
    final hasHealthPlaceholders = template.contains('{sleep') || template.contains('{water') || template.contains('{weight') || template.contains('{steps');
    if (!hasHealthPlaceholders) {
      final extra = <String>[];
      if (vars['sleep'] != null && vars['sleep'] != '-') extra.add('сон сегодня ${vars['sleep']} (оценка ${vars['sleepScore']})');
      if (vars['water'] != null && vars['water'] != '-') extra.add('вода сегодня ${vars['water']}');
      if (vars['steps'] != null && vars['steps'] != '-') extra.add('шаги сегодня ${vars['steps']}');
      if (vars['weight'] != null && vars['weight'] != '-') extra.add('вес ${vars['weight']} кг (BMI ${vars['bmi']})');
      if (vars['hrv'] != null && vars['hrv'] != '-') extra.add('HRV ${vars['hrv']}');
      if (extra.isNotEmpty) {
        out += '\n\nКонтекст здоровья: ${extra.join(', ')}.';
      }
    }
    // если в шаблоне вообще нет плейсхолдеров — добавляем все метрики
    if (!template.contains('{')) {
      out += '\nДанные: ${vars.entries.map((e) => '${e.key}=${e.value}').join(', ')}';
    }
    return out;
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 мин';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}ч ${m}м ${s}с';
    if (m > 0) return '${m}м ${s}с';
    return '${s}с';
  }

  String _sanitize(String s) {
    // убираем эмодзи суррогаты
    return s.replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true), '').trim();
  }

  // Fallback curated list 2026
  static const List<String> _fallbackModels = [
    'kimi-k2.6:cloud',
    'kimi-k2.7-code:cloud',
    'glm-5.1:cloud',
    'glm-5.2:cloud',
    'glm-5.3:cloud',
    'qwen3.5:397b',
    'qwen3.5:cloud',
    'deepseek-v4-pro',
    'deepseek-v4-flash',
    'minimax-m3',
    'minimax-m2.7:cloud',
    'gemma4:31b',
    'nemotron-3-ultra',
    'nemotron-3-super',
    'gpt-oss:20b',
    'gpt-oss:120b',
    'mistral-large-3:675b',
  ];
}
