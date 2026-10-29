/// Exercise catalog models — the bundled offline copy of the server's
/// wger-based snapshot (`assets/catalog/exercise_catalog.json`, 914 entries
/// with Russian names, categories/equipment/muscles dictionaries).
class CatalogDictionary {
  final int id;
  final String name;

  const CatalogDictionary({required this.id, required this.name});
}

class CatalogExercise {
  final int id; // wger_id — the stable identifier used by plans and sessions.
  final String nameRu;
  final String nameEn;
  final String? descriptionRu;
  final String? descriptionEn;
  final int categoryId;
  final List<int> equipmentIds;
  final List<int> muscleIds;
  final List<int> muscleIdsSecondary;
  final String? tipRu;
  final String? tipEn;
  final List<String> aliasesRu;
  final List<String> aliasesEn;

  const CatalogExercise({
    required this.id,
    required this.nameRu,
    required this.nameEn,
    this.descriptionRu,
    this.descriptionEn,
    required this.categoryId,
    required this.equipmentIds,
    required this.muscleIds,
    required this.muscleIdsSecondary,
    this.tipRu,
    this.tipEn,
    this.aliasesRu = const [],
    this.aliasesEn = const [],
  });

  /// Localized name — Russian when available, English always exists.
  String name(RussianOrEnglish lang) => lang == RussianOrEnglish.ru ? nameRu : (nameEn.isNotEmpty ? nameEn : nameRu);

  String? description(RussianOrEnglish lang) =>
      lang == RussianOrEnglish.ru ? (descriptionRu ?? descriptionEn) : descriptionEn;

  String? firstTip(RussianOrEnglish lang) {
    if (lang == RussianOrEnglish.ru) return tipRu ?? tipEn;
    return tipEn;
  }

  bool matches(String queryLower, RussianOrEnglish lang) {
    final en = nameEn.toLowerCase();
    final ru = nameRu.toLowerCase();
    if (queryLower.isEmpty) return true;
    if (lang == RussianOrEnglish.ru) {
      // Same rule as the server: query language names only + canonical EN
      // ("bench press" keeps working in a Russian UI).
      if (ru.contains(queryLower)) return true;
      if (aliasesRu.any((a) => a.toLowerCase().contains(queryLower))) return true;
      return en.contains(queryLower);
    }
    return en.contains(queryLower) || aliasesEn.any((a) => a.toLowerCase().contains(queryLower));
  }

  factory CatalogExercise.fromJson(Map<String, dynamic> j) {
    final translations = <String, Map<String, String>>{};
    final trList = j['translations'];
    if (trList is List) {
      for (final tr in trList) {
        if (tr is Map<String, dynamic>) {
          final lang = tr['language']?.toString() ?? '';
          if (lang.isEmpty) continue;
          translations[lang] = {
            'name': tr['name']?.toString() ?? '',
            'description': tr['description']?.toString() ?? '',
          };
        }
      }
    }
    String? clean(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      final withoutTags = raw
          .replaceAll(RegExp(r'<br\s*/?>'), '\n')
          .replaceAll(RegExp(r'</p>'), '\n\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceFirst(RegExp(r'^[\s\n]+'), '')
          .replaceFirst(RegExp(r'[\s\n]+$'), '')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
      return withoutTags.isEmpty ? null : withoutTags;
    }

    final ru = translations['ru'];
    final en = translations['en'];
    final tipsMap = j['tips'];
    final aliasesMap = j['aliases'];
    List<int> idList(dynamic raw) => raw is List
        ? raw.map((e) => e is num ? e.toInt() : int.tryParse('$e') ?? 0).where((e) => e > 0).toList()
        : <int>[];
    List<String> strList(dynamic raw) => raw is List
        ? raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return CatalogExercise(
      id: j['id'] is num ? (j['id'] as num).toInt() : int.tryParse('${j['id']}') ?? 0,
      nameRu: ru?['name'] ?? en?['name'] ?? '',
      nameEn: en?['name'] ?? '',
      descriptionRu: clean(ru?['description']),
      descriptionEn: clean(en?['description']),
      categoryId: j['category'] is num ? (j['category'] as num).toInt() : int.tryParse('${j['category']}') ?? 0,
      equipmentIds: idList(j['equipment']),
      muscleIds: idList(j['muscles']),
      muscleIdsSecondary: idList(j['muscles_secondary']),
      tipRu: clean(tipsMap is Map ? tipsMap['ru']?.toString() : null),
      tipEn: clean(tipsMap is Map ? tipsMap['en']?.toString() : null),
      aliasesRu: strList(aliasesMap is Map ? aliasesMap['ru'] : null),
      aliasesEn: strList(aliasesMap is Map ? aliasesMap['en'] : null),
    );
  }
}

enum RussianOrEnglish { ru, en }
