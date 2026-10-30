import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:endurain/core/di/service_locator.dart';
import 'package:endurain/core/models/nutrition_models.dart';
import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/services/nutrition_local_repository.dart';

/// Server access to the nutrition diary (`/api/v1/nutrition`).
///
/// Offline-first like `WorkoutsService`: reads fall back to the local sqflite
/// cache, writes land in the local queue when the server is unreachable and
/// are pushed later by `syncPending`.
///
/// Food lookup is proxied by the server (`/nutrition/off/*`, Open Food
/// Facts); barcode → product results are cached locally for offline reuse.
class NutritionService {
  NutritionService._();
  static final NutritionService instance = NutritionService._();

  final ApiClient _apiClient = serviceLocator<ApiClient>();
  final NutritionLocalRepository _local = NutritionLocalRepository.instance;

  static const String _basePath = '/api/v1/nutrition';

  /// Validates `mealType` against the server pattern
  /// (`^(breakfast|lunch|dinner|snack)$`).
  static bool isKnownMealType(String mealType) =>
      RegExp('^(?:breakfast|lunch|dinner|snack)\$').hasMatch(mealType);

  // ---- meal logs ----

  /// Fetches a date range (inclusive) and refreshes the local cache.
  /// `null` fields mean "no filter".
  Future<List<MealLog>> fetchLogs(
      {String? dateFrom, String? dateTo, bool cacheFallback = true,}) async {
    List<MealLog>? server;
    try {
      final params = <String, String>{};
      if (dateFrom != null) params['date_from'] = dateFrom;
      if (dateTo != null) params['date_to'] = dateTo;
      final query =
          params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
      final response = await _apiClient.get('$_basePath$query');
      if (response.statusCode == 200) {
        server = (json.decode(response.body) as List<dynamic>)
            .map((e) => MealLog.fromJson(e as Map<String, dynamic>))
            .toList();
        await _local.replaceLogs(server);
      } else {
        debugPrint('NutritionService: fetchLogs status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('NutritionService: fetchLogs error: $e');
    }
    return server ??
        (cacheFallback
            ? await _local.listLogs(dateFrom: dateFrom, dateTo: dateTo)
            : <MealLog>[]);
  }

  /// Logs a meal. Offline, the entry is queued locally (is_synced=0) and the
  /// `pending` row is returned so the UI can mark it as not yet uploaded.
  /// A synchronous rejection (the server answered 4xx/5xx) drops the local
  /// row and returns `null`; only network failures keep it queued.
  Future<MealLog?> addLog(MealLog draft) async {
    final pending = await _local.queueLog(draft);
    try {
      final response =
          await _apiClient.post(_basePath, body: draft.toPayload());
      if (response.statusCode == 201) {
        final created = MealLog.fromJson(
            json.decode(response.body) as Map<String, dynamic>,);
        final confirmed = await _local.confirmLog(pending, created);
        return confirmed ?? created.copyWith(synced: true);
      }
      debugPrint(
          'NutritionService: addLog rejected, status ${response.statusCode} — dropping',);
      await _local.purgeLog(pending);
      return null;
    } catch (e) {
      debugPrint('NutritionService: addLog queued offline: $e');
      return pending;
    }
  }

  /// Updates an existing entry (local or server row). Offline the edit is
  /// stored locally and pushed on the next `syncPending`.
  Future<MealLog?> updateLog(MealLog log) async {
    final stored = await _local.updateLog(log);
    if (stored == null) return null;
    if (log.id == null) return stored;
    try {
      final response =
          await _apiClient.put('$_basePath/${log.id}', body: log.toPayload());
      if (response.statusCode == 200) {
        final updated = MealLog.fromJson(
            json.decode(response.body) as Map<String, dynamic>,);
        return _local.confirmLog(stored, updated);
      }
      debugPrint('NutritionService: updateLog status ${response.statusCode}');
    } catch (e) {
      debugPrint('NutritionService: updateLog queued offline: $e');
    }
    return _local.listLogs().then((logs) {
      for (final l in logs) {
        if (l.localId == log.localId) return l;
      }
      return stored;
    });
  }

  /// Removes an entry; tombstones server rows offline, purges local ones.
  Future<bool> removeLog(MealLog log) async {
    try {
      if (log.id != null) {
        try {
          final response = await _apiClient.delete('$_basePath/${log.id}');
          if (response.statusCode != 204 && response.statusCode != 404) {
            debugPrint(
                'NutritionService: removeLog status ${response.statusCode}',);
            // Remember the deletion locally; pushed on the next syncPending.
            await _local.deleteLog(log);
            return false;
          }
        } catch (_) {
          await _local.deleteLog(log);
          return false;
        }
      }
      await _local.deleteLog(log);
      return true;
    } catch (e) {
      debugPrint('NutritionService: removeLog error: $e');
      return false;
    }
  }

  // ---- sync ----

  /// Number of local rows waiting for the server.
  Future<int> pendingCount() => _local.pendingCount();

  /// Pushes unsynced rows: creates → POST, updates → PUT, tombstones →
  /// DELETE (+purge). Returns the number of rows the server accepted.
  Future<int> syncPending() async {
    final pending = await _local.pendingLogs();
    var pushed = 0;
    for (final entry in pending) {
      try {
        if (entry.pendingDelete && entry.id != null) {
          final response = await _apiClient.delete('$_basePath/${entry.id}');
          if (response.statusCode == 204 || response.statusCode == 404) {
            await _local.purgeLog(entry);
            pushed++;
          }
        } else if (entry.id == null) {
          final response =
              await _apiClient.post(_basePath, body: entry.toPayload());
          if (response.statusCode == 201) {
            final created = MealLog.fromJson(
                json.decode(response.body) as Map<String, dynamic>,);
            await _local.confirmLog(entry, created);
            pushed++;
          }
        } else {
          final response = await _apiClient.put('$_basePath/${entry.id}',
              body: entry.toPayload(),);
          if (response.statusCode == 200) {
            final updated = MealLog.fromJson(
                json.decode(response.body) as Map<String, dynamic>,);
            await _local.confirmLog(entry, updated);
            pushed++;
          }
        }
      } catch (e) {
        debugPrint('NutritionService: syncPending retry later: $e');
      }
    }
    return pushed;
  }

  // ---- summary ----

  /// Server-side daily totals (intake + burned from activities). `null` when
  /// unreachable — the UI then aggregates the cached logs locally.
  Future<NutritionSummary?> fetchSummary(String date) async {
    try {
      final response = await _apiClient.get('$_basePath/summary?date=$date');
      if (response.statusCode == 200) {
        return NutritionSummary.fromJson(
            json.decode(response.body) as Map<String, dynamic>,);
      }
      debugPrint(
          'NutritionService: fetchSummary status ${response.statusCode}',);
    } catch (e) {
      debugPrint('NutritionService: fetchSummary error: $e');
    }
    return null;
  }

  /// Local aggregation fallback (intake only, no burned calories).
  Future<NutritionSummary> localSummary(String date) async {
    final logs = await _local.listLogs(dateFrom: date, dateTo: date);
    double kcal = 0, protein = 0, carbs = 0, fat = 0;
    for (final log in logs) {
      kcal += log.calories ?? 0;
      protein += log.protein ?? 0;
      carbs += log.carbs ?? 0;
      fat += log.fat ?? 0;
    }
    return NutritionSummary(
      date: date,
      intakeCalories: kcal,
      intakeProtein: protein,
      intakeCarbs: carbs,
      intakeFat: fat,
    );
  }

  /// "My foods" history for autocomplete (local only, instant).
  Future<List<MealLog>> recentFoods(String query) =>
      _local.recentFoods(query);

  // ---- Open Food Facts (server proxy) ----

  Future<List<OffProduct>> searchOff(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final response = await _apiClient
          .get('$_basePath/off/search?q=${Uri.encodeQueryComponent(q)}');
      if (response.statusCode == 200) {
        final products = (json.decode(response.body) as List<dynamic>)
            .map((e) => OffProduct.fromJson(e as Map<String, dynamic>))
            .where((p) => p.productName.isNotEmpty)
            .toList();
        for (final p in products) {
          await _local.saveProduct(p);
        }
        return products;
      }
      debugPrint('NutritionService: searchOff status ${response.statusCode}');
    } catch (e) {
      debugPrint('NutritionService: searchOff error: $e');
    }
    return _local.searchCachedProducts(q);
  }

  /// Barcode → product (scanner path). Falls back to the local cache offline.
  Future<OffProduct?> fetchOffProduct(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    try {
      final response = await _apiClient
          .get('$_basePath/off/product/${Uri.encodeComponent(code)}');
      if (response.statusCode == 200) {
        final product = OffProduct.fromJson(
            json.decode(response.body) as Map<String, dynamic>,);
        await _local.saveProduct(product);
        return product;
      }
      debugPrint(
          'NutritionService: fetchOffProduct status ${response.statusCode}',);
    } catch (e) {
      debugPrint('NutritionService: fetchOffProduct error: $e');
    }
    return _local.cachedProduct(code);
  }
}
