import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:endurain/core/models/catalog_models.dart';

/// The bundled offline exercise catalog (baked into the APK).
///
/// Same data source as the server's `/workouts/exercises` snapshot, so
/// wger ids stay meaningful for plans and sessions. Loads once and serves
/// search entirely from memory — 914 entries are small.
class CatalogService {
  CatalogService._();

  static final CatalogService instance = CatalogService._();

  static const String _assetPath = 'assets/catalog/exercise_catalog.json';

  List<CatalogExercise>? _exercises;
  List<CatalogDictionary>? _categories;
  List<CatalogDictionary>? _equipment;
  List<CatalogDictionary>? _muscles;
  Future<void>? _loading;

  bool get isReady => _exercises != null;
  int get exerciseCount => _exercises?.length ?? 0;

  List<CatalogDictionary>? get categories => _categories;
  List<CatalogDictionary>? get equipment => _equipment;
  List<CatalogDictionary>? get muscles => _muscles;

  /// Warm-up at app start (or right before first picker use).
  Future<void> ensureLoaded() {
    if (_exercises != null) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = await Isolate.run(() {
        final snapshot = json.decode(raw) as Map<String, dynamic>;
        return snapshot;
      });
      final categories = <CatalogDictionary>[];
      final equipment = <CatalogDictionary>[];
      final muscles = <CatalogDictionary>[];
      for (final c in (decoded['categories'] as List<dynamic>? ?? [])) {
        if (c is Map<String, dynamic>) {
          categories.add(CatalogDictionary(id: c['id'] as int, name: c['name']?.toString() ?? ''));
        }
      }
      for (final e in (decoded['equipment'] as List<dynamic>? ?? [])) {
        if (e is Map<String, dynamic>) {
          equipment.add(CatalogDictionary(id: e['id'] as int, name: e['name']?.toString() ?? ''));
        }
      }
      for (final m in (decoded['muscles'] as List<dynamic>? ?? [])) {
        if (m is Map<String, dynamic>) {
          muscles.add(CatalogDictionary(id: m['id'] as int, name: m['name']?.toString() ?? ''));
        }
      }
      final exercises = <CatalogExercise>[];
      for (final ex in (decoded['exercises'] as List<dynamic>? ?? [])) {
        if (ex is Map<String, dynamic>) {
          try {
            exercises.add(CatalogExercise.fromJson(ex));
          } catch (e) {
            debugPrint('CatalogService: skip malformed exercise: $e');
          }
        }
      }
      _exercises = exercises;
      _categories = categories;
      _equipment = equipment;
      _muscles = muscles;
    } catch (e) {
      debugPrint('CatalogService: load failed: $e');
      _exercises = [];
      _categories = [];
      _equipment = [];
      _muscles = [];
    }
  }

  CatalogDictionary? categoryById(int id) => _lookup(_categories, id);

  CatalogDictionary? equipmentById(int id) => _lookup(_equipment, id);

  /// Russian display names for the bundled dictionaries (the JSON carries
  /// English canonical names; the server translates them via workouts.json —
  /// mirror that here so the picker isn't half-English).
  static const Map<int, String> _categoryNamesRu = {
    8: 'Руки',
    9: 'Ноги',
    10: 'Пресс',
    11: 'Грудь',
    12: 'Спина',
    13: 'Плечи',
    14: 'Икры',
    15: 'Кардио',
  };

  static const Map<int, String> _equipmentNamesRu = {
    1: 'Штанга',
    2: 'Штанга SZ',
    3: 'Гантели',
    4: 'Коврик',
    5: 'Фитбол',
    6: 'Турник',
    7: 'Собственный вес',
    8: 'Скамья',
    9: 'Наклонная скамья',
    10: 'Гиря',
    11: 'Резиновый жгут',
    12: 'Блочная рама',
    13: 'Тренажёр',
    14: 'Мяч',
    15: 'Фоам-ролл',
    16: 'Другое',
  };

  static const Map<int, String> _muscleNamesRu = {
    1: 'Бицепс',
    2: 'Передняя дельта',
    3: 'Передняя зубчатая мышца',
    4: 'Грудные',
    5: 'Трицепс',
    6: 'Прямая мышца живота',
    7: 'Икроножная мышца',
    8: 'Большая ягодичная',
    9: 'Трапеция',
    10: 'Квадрицепс',
    11: 'Бицепс бедра',
    12: 'Широчайшие',
    13: 'Плечевая мышца',
    14: 'Косые мышцы живота',
    15: 'Камбаловидная мышца',
    16: 'Разгибатель позвоночника',
    17: 'Приводящие мышцы',
    18: 'Отводящие мышцы',
    19: 'Предплечья',
  };

  String categoryName(int id, {RussianOrEnglish lang = RussianOrEnglish.ru}) {
    if (lang == RussianOrEnglish.ru) return _categoryNamesRu[id] ?? categoryById(id)?.name ?? '';
    return categoryById(id)?.name ?? '';
  }

  String equipmentName(int id, {RussianOrEnglish lang = RussianOrEnglish.ru}) {
    if (lang == RussianOrEnglish.ru) return _equipmentNamesRu[id] ?? equipmentById(id)?.name ?? '';
    return equipmentById(id)?.name ?? '';
  }

  String muscleName(int id, {RussianOrEnglish lang = RussianOrEnglish.ru}) {
    if (lang == RussianOrEnglish.ru) {
      final ru = _muscleNamesRu[id];
      if (ru != null) return ru;
    }
    final all = _muscles;
    if (all == null) return '';
    for (final m in all) {
      if (m.id == id) return m.name;
    }
    return '';
  }

  CatalogExercise? byId(int id) {
    final list = _exercises;
    if (list == null) return null;
    for (final e in list) {
      if (e.id == id) return e;
    }
    return null;
  }

  CatalogDictionary? _lookup(List<CatalogDictionary>? dict, int id) {
    if (dict == null || id <= 0) return null;
    for (final d in dict) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Search semantics mirror the server: query matches the UI language's
  /// names/aliases (canonical EN always counts); category/equipment/muscle
  /// filters are exact dictionary ids.
  List<CatalogExercise> search({
    String query = '',
    RussianOrEnglish lang = RussianOrEnglish.ru,
    int? categoryId,
    int? equipmentId,
    int? muscleId,
    int limit = 50,
  }) {
    final list = _exercises;
    if (list == null) return const [];
    final q = query.trim().toLowerCase();
    final result = <CatalogExercise>[];
    for (final e in list) {
      if (q.isNotEmpty && !e.matches(q, lang)) {
        // The server also keeps rows whose localized name for `lang` is
        // absent by falling back to the shown (EN) name — bundled data has
        // ru for every row, so nothing extra needed.
        continue;
      }
      if (categoryId != null && e.categoryId != categoryId) continue;
      if (equipmentId != null && !e.equipmentIds.contains(equipmentId)) continue;
      if (muscleId != null && !e.muscleIds.contains(muscleId)) continue;
      result.add(e);
    }
    result.sort((a, b) => a.name(lang).toLowerCase().compareTo(b.name(lang).toLowerCase()));
    if (result.length > limit) result.removeRange(limit, result.length);
    return result;
  }
}
