import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';

class VoiceCoachService {
  VoiceCoachService._();
  static final VoiceCoachService instance = VoiceCoachService._();

  final FlutterTts _tts = FlutterTts();
  final AppSettingsController _settings = AppSettingsController.instance;
  static const _audioFocusChannel = MethodChannel('com.zapfit/audio_focus');

  bool _initialized = false;
  bool _isSpeaking = false;
  final List<String> _queue = [];
  bool _isProcessingQueue = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('ru-RU');
      await _tts.setVolume(_settings.voiceCoachVolume);
      await _tts.setSpeechRate(_settings.voiceCoachSpeechRate);
      // Fix ducking: proper audio category + queue mode
      try {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.duckOthers, IosTextToSpeechAudioCategoryOptions.mixWithOthers],
          IosTextToSpeechAudioMode.defaultMode,
        );
      } catch (_) {}
      try {
        await _tts.setQueueMode(1); // queue, don't interrupt
      } catch (_) {}
      await _applyVoice();
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _abandonAudioFocus();
        _processNextInQueue();
      });
      // iOS/Android: также обрабатываем прерывания
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _abandonAudioFocus();
        _processNextInQueue();
      });
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _abandonAudioFocus();
        _processNextInQueue();
      });
      _initialized = true;
    } catch (e) {
      debugPrint('VoiceCoach init error: $e');
      _initialized = false;
    }
  }

  Future<List<MapEntry<String, String>>> getAvailableVoices() async {
    try {
      final dynamic rawVoices = await _tts.getVoices;
      if (rawVoices == null) return [];
      final List<dynamic> voicesList = rawVoices is List ? rawVoices : [];
      final ruVoices = voicesList
          .where((v) => v is Map && v['locale'] != null && (v['locale'] as String).startsWith('ru'))
          .map((v) => MapEntry(
                (v['name'] as String?) ?? 'Unknown',
                (v['locale'] as String?) ?? 'ru-RU',
              ))
          .toList();
      return ruVoices;
    } catch (e) {
      debugPrint('VoiceCoach getVoices error: $e');
      return [];
    }
  }

  Future<void> _applyVoice() async {
    try {
      final gender = _settings.voiceCoachGender;
      final modelName = _settings.voiceCoachModel;

      if (modelName != null && modelName.isNotEmpty) {
        await _tts.setVoice({'name': modelName, 'locale': 'ru-RU'});
        return;
      }

      final voices = await getAvailableVoices();
      if (voices.isEmpty) {
        await _tts.setPitch(gender == 'male' ? 0.8 : 1.1);
        return;
      }

      String selectedName;
      if (gender == 'male') {
        selectedName = voices
            .map((e) => e.key)
            .firstWhere(
              (name) => name.toLowerCase().contains('male') || name.toLowerCase().contains('man') || name.toLowerCase().contains('m1'),
              orElse: () => voices.first.key,
            );
      } else {
        selectedName = voices
            .map((e) => e.key)
            .firstWhere(
              (name) => name.toLowerCase().contains('female') || name.toLowerCase().contains('woman') || name.toLowerCase().contains('f1'),
              orElse: () => voices.last.key,
            );
      }

      await _tts.setVoice({'name': selectedName, 'locale': 'ru-RU'});
    } catch (e) {
      debugPrint('VoiceCoach _applyVoice error: $e');
    }
  }

  Future<void> _requestAudioFocus() async {
    try {
      await _audioFocusChannel.invokeMethod('requestFocus');
    } catch (e) {
      debugPrint('VoiceCoach audio focus request error: $e');
    }
  }

  Future<void> _abandonAudioFocus() async {
    try {
      await _audioFocusChannel.invokeMethod('abandonFocus');
    } catch (e) {
      debugPrint('VoiceCoach audio focus abandon error: $e');
    }
  }

  /// Очередь: фразы не перебивают друг друга, каждая в отдельной очереди
  Future<void> speak(String text) async {
    if (!_settings.voiceCoachEnabled) return;
    if (text.isEmpty) return;
    _queue.add(text);
    if (!_isSpeaking && !_isProcessingQueue) {
      _processNextInQueue();
    }
  }

  Future<void> _processNextInQueue() async {
    if (_queue.isEmpty) {
      _isProcessingQueue = false;
      return;
    }
    _isProcessingQueue = true;
    final text = _queue.removeAt(0);
    try {
      if (!_initialized) await init();
      await _requestAudioFocus();
      // даём системе время приглушить музыку перед TTS
      await Future.delayed(const Duration(milliseconds: 250));
      await _tts.setVolume(_settings.voiceCoachVolume);
      await _tts.setSpeechRate(_settings.voiceCoachSpeechRate);
      await _applyVoice();
      _isSpeaking = true;
      await _tts.speak(text);
      // completionHandler вызовет следующий элемент
    } catch (e) {
      _isSpeaking = false;
      _abandonAudioFocus();
      debugPrint('VoiceCoach speak error: $e');
      _isProcessingQueue = false;
      // пробуем след фразу
      if (_queue.isNotEmpty) _processNextInQueue();
    }
  }

  Future<void> speakImmediate(String text) async {
    // Для срочных предупреждений (пульс) — прерываем текущую фразу и ставим в голову
    if (!_settings.voiceCoachEnabled || text.isEmpty) return;
    if (_isSpeaking) {
      try {
        await _tts.stop();
      } catch (_) {}
      _isSpeaking = false;
      await _abandonAudioFocus();
      // небольшая задержка чтобы фокус успел сброситься
      await Future.delayed(const Duration(milliseconds: 150));
    }
    _queue.insert(0, text);
    if (!_isProcessingQueue) _processNextInQueue();
  }

  Future<void> stop() async {
    try {
      _queue.clear();
      _isProcessingQueue = false;
      _isSpeaking = false;
      await _tts.stop();
      _abandonAudioFocus();
    } catch (e) {
      debugPrint('VoiceCoach stop error: $e');
    }
  }
}
