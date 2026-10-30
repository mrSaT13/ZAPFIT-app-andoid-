import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:endurain/core/models/nutrition_models.dart';

/// Local storage for the nutrition diary: the offline cache of meal logs and
/// the product cache (barcode → nutrition per 100 g).
///
/// Meal rows follow the workouts session queue pattern:
/// - `is_synced = 1` — the row matches the server copy;
/// - `is_synced = 0` — created/changed locally and waiting to be pushed
///   (deletions of synced rows become tombstones via `pending_delete`,
///   pushed by `NutritionService.syncPending`).
///
/// Own small database (`nutrition.db`) — separate from activities/workouts.
class NutritionLocalRepository {
  NutritionLocalRepository._();

  static final NutritionLocalRepository instance = NutritionLocalRepository._();

  static const String _dbName = 'nutrition.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get _database async {
    if (_db != null && _db!.isOpen) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      join(dir, _dbName),
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE meal_logs (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER,
            date TEXT NOT NULL,
            meal_type TEXT NOT NULL,
            product_name TEXT NOT NULL,
            calories REAL,
            protein REAL,
            carbs REAL,
            fat REAL,
            portion_g REAL,
            off_barcode TEXT,
            pending_delete INTEGER NOT NULL DEFAULT 0,
            is_synced INTEGER NOT NULL DEFAULT 0,
            created_at TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_meal_logs_synced ON meal_logs (is_synced)',);
        await db.execute('CREATE INDEX idx_meal_logs_date ON meal_logs (date)');
        await db.execute('''
          CREATE TABLE products (
            barcode TEXT PRIMARY KEY,
            product_name TEXT NOT NULL,
            brands TEXT,
            calories_100g REAL,
            protein_100g REAL,
            carbs_100g REAL,
            fat_100g REAL,
            image_url TEXT,
            fetched_at TEXT
          )
        ''');
      },
    );
    return _db!;
  }

  // ---- meal logs ----

  /// Replaces cached rows with the server list, keeping every row that still
  /// has local work attached (unsynced creates/updates, pending deletions).
  Future<void> replaceLogs(List<MealLog> logs) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        await txn.delete('meal_logs',
            where: 'is_synced = 1 AND pending_delete = 0',);
        final batch = txn.batch();
        for (final log in logs) {
          if (log.id == null) continue;
          batch.insert(
            'meal_logs',
            _rowFromLog(log, serverId: log.id, synced: true),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit();
      });
    } catch (e) {
      debugPrint('NutritionLocal: replaceLogs error: $e');
    }
  }

  /// Inserts the offline copy; returns the serverless local row.
  Future<MealLog> queueLog(MealLog log) async {
    final db = await _database;
    final row = _rowFromLog(log, synced: false);
    final localId = await db.insert('meal_logs', row);
    return _logFromRow({...row, 'local_id': localId});
  }

  /// Marks an existing row as locally edited; offline the PUT goes out on the
  /// next `syncPending` (server rows) or stays queued (pure local rows).
  Future<MealLog?> updateLog(MealLog log) async {
    if (log.localId == null) return null;
    try {
      final db = await _database;
      final row =
          _rowFromLog(log, serverId: log.id, synced: log.synced == true);
      // Any local edit must be pushed (PUT for server rows, kept queued for
      // pure local ones) — the row is always left unsynced here.
      row['is_synced'] = 0;
      row['local_id'] = log.localId;
      await db.update(
        'meal_logs',
        row,
        where: 'local_id = ?',
        whereArgs: [log.localId],
      );
      return log;
    } catch (e) {
      debugPrint('NutritionLocal: updateLog error: $e');
      return null;
    }
  }

  Future<MealLog?> confirmLog(MealLog localRow, MealLog created) async {
    if (localRow.localId == null) return null;
    try {
      final db = await _database;
      final row = _rowFromLog(created, serverId: created.id, synced: true);
      row.remove('local_id');
      await db.update(
        'meal_logs',
        row,
        where: 'local_id = ?',
        whereArgs: [localRow.localId],
      );
      return _logFromRow(
        {
          ...row,
          'local_id': localRow.localId,
        },
        keepSynced: true,
      );
    } catch (e) {
      debugPrint('NutritionLocal: confirmLog error: $e');
      return null;
    }
  }

  /// Deletes a row. Unsynced local rows vanish outright; synced rows become
  /// tombstones (`pending_delete=1`) so `syncPending` can push the deletion.
  Future<void> deleteLog(MealLog log) async {
    if (log.localId == null) return;
    try {
      final db = await _database;
      if (log.id == null) {
        await db.delete('meal_logs',
            where: 'local_id = ?', whereArgs: [log.localId],);
      } else {
        await db.update(
          'meal_logs',
          {'pending_delete': 1, 'is_synced': 0},
          where: 'local_id = ?',
          whereArgs: [log.localId],
        );
      }
    } catch (e) {
      debugPrint('NutritionLocal: deleteLog error: $e');
    }
  }

  /// Rows waiting for a push: creates (no server id), updates (server id) and
  /// tombstones (pending_delete = 1), oldest first.
  Future<List<MealLog>> pendingLogs() async {
    try {
      final db = await _database;
      final rows = await db.query(
        'meal_logs',
        where: 'is_synced = 0',
        orderBy: 'local_id',
      );
      return [
        for (final r in rows.cast<Map<String, dynamic>>()) _logFromRow(r),
      ];
    } catch (e) {
      debugPrint('NutritionLocal: pendingLogs error: $e');
      return [];
    }
  }

  /// Removes a tombstone after the server confirmed the deletion.
  Future<void> purgeLog(MealLog log) async {
    if (log.localId == null) return;
    try {
      final db = await _database;
      await db
          .delete('meal_logs', where: 'local_id = ?', whereArgs: [log.localId]);
    } catch (e) {
      debugPrint('NutritionLocal: purgeLog error: $e');
    }
  }

  Future<int> pendingCount() async {
    final pending = await pendingLogs();
    return pending.length;
  }

  Future<List<MealLog>> listLogs({String? dateFrom, String? dateTo}) async {
    try {
      final db = await _database;
      final where = <String>['pending_delete = 0'];
      final whereArgs = <String>[];
      if (dateFrom != null) {
        where.add('date >= ?');
        whereArgs.add(dateFrom);
      }
      if (dateTo != null) {
        where.add('date <= ?');
        whereArgs.add(dateTo);
      }
      final rows = await db.query(
        'meal_logs',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'date DESC, local_id DESC',
      );
      return [
        for (final r in rows.cast<Map<String, dynamic>>()) _logFromRow(r),
      ];
    } catch (e) {
      debugPrint('NutritionLocal: listLogs error: $e');
      return [];
    }
  }

  MealLog _logFromRow(Map<String, dynamic> r, {bool keepSynced = false}) {
    final pendingDelete = (r['pending_delete'] as num?)?.toInt() ?? 0;
    final isSynced = (r['is_synced'] as num?)?.toInt() ?? 0;
    return MealLog(
      localId: (r['local_id'] as num?)?.toInt(),
      id: (r['server_id'] as num?)?.toInt(),
      date: r['date'] as String? ?? '',
      mealType: r['meal_type'] as String? ?? 'snack',
      productName: r['product_name'] as String? ?? '',
      calories: (r['calories'] as num?)?.toDouble(),
      protein: (r['protein'] as num?)?.toDouble(),
      carbs: (r['carbs'] as num?)?.toDouble(),
      fat: (r['fat'] as num?)?.toDouble(),
      portionG: (r['portion_g'] as num?)?.toDouble(),
      offBarcode: r['off_barcode'] as String?,
      synced: keepSynced || (isSynced == 1 && pendingDelete == 0),
      pendingDelete: pendingDelete == 1,
    );
  }

  Map<String, dynamic> _rowFromLog(MealLog log,
      {int? serverId, bool synced = false,}) {
    return {
      if (serverId != null) 'server_id': serverId,
      'date': log.date,
      'meal_type': log.mealType,
      'product_name': log.productName,
      'calories': log.calories,
      'protein': log.protein,
      'carbs': log.carbs,
      'fat': log.fat,
      'portion_g': log.portionG,
      'off_barcode': (log.offBarcode != null && log.offBarcode!.isNotEmpty)
          ? log.offBarcode
          : null,
      'pending_delete': 0,
      'is_synced': synced ? 1 : 0,
    };
  }

  // ---- products cache ----

  Future<void> saveProduct(OffProduct product) async {
    if (product.barcode.isEmpty) return;
    try {
      final db = await _database;
      await db.insert(
        'products',
        {
          'barcode': product.barcode,
          'product_name': product.productName,
          'brands': product.brands,
          'calories_100g': product.calories100g,
          'protein_100g': product.protein100g,
          'carbs_100g': product.carbs100g,
          'fat_100g': product.fat100g,
          'image_url': product.imageUrl,
          'fetched_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('NutritionLocal: saveProduct error: $e');
    }
  }

  Future<OffProduct?> cachedProduct(String barcode) async {
    try {
      final db = await _database;
      final rows = await db.query('products',
          where: 'barcode = ?', whereArgs: [barcode], limit: 1,);
      if (rows.isEmpty) return null;
      return _productFromRow(rows.cast<Map<String, dynamic>>().first);
    } catch (e) {
      debugPrint('NutritionLocal: cachedProduct error: $e');
      return null;
    }
  }

  /// Name/barcode search over the cached products (offline fallback for the
  /// Open Food Facts search).
  Future<List<OffProduct>> searchCachedProducts(String query) async {
    try {
      final db = await _database;
      final q = query.trim();
      if (q.isEmpty) return [];
      final rows = await db.query(
        'products',
        where: '(product_name LIKE ? OR barcode LIKE ?)',
        whereArgs: ['%$q%', '%$q%'],
        orderBy: 'product_name COLLATE NOCASE',
        limit: 25,
      );
      return [
        for (final r in rows.cast<Map<String, dynamic>>()) _productFromRow(r),
      ];
    } catch (e) {
      debugPrint('NutritionLocal: searchCachedProducts error: $e');
      return [];
    }
  }

  OffProduct _productFromRow(Map<String, dynamic> r) {
    return OffProduct(
      barcode: r['barcode'] as String? ?? '',
      productName: r['product_name'] as String? ?? '',
      brands: r['brands'] as String?,
      calories100g: (r['calories_100g'] as num?)?.toDouble(),
      protein100g: (r['protein_100g'] as num?)?.toDouble(),
      carbs100g: (r['carbs_100g'] as num?)?.toDouble(),
      fat100g: (r['fat_100g'] as num?)?.toDouble(),
      imageUrl: r['image_url'] as String?,
    );
  }

  /// "My foods": latest log row per product name matching the query
  /// (case-insensitive), most recently logged first.
  ///
  /// History-first autocomplete for repeat meals: the dialog offers these
  /// instantly (no network) and a tap fills the whole form, so recurring
  /// foods/drinks never need retyping.
  Future<List<MealLog>> recentFoods(String query, {int limit = 6}) async {
    try {
      final db = await _database;
      final q = query.trim();
      if (q.length < 2) return [];
      final rows = await db.query(
        'meal_logs',
        where: 'pending_delete = 0 AND product_name LIKE ?',
        whereArgs: ['%$q%'],
        orderBy: 'local_id DESC',
        limit: limit * 4,
      );
      final seen = <String>{};
      final out = <MealLog>[];
      for (final r in rows.cast<Map<String, dynamic>>()) {
        final key = (r['product_name'] as String? ?? '').toLowerCase();
        if (key.isEmpty || !seen.add(key)) continue;
        out.add(_logFromRow(r));
        if (out.length >= limit) break;
      }
      return out;
    } catch (e) {
      debugPrint('NutritionLocal: recentFoods error: $e');
      return [];
    }
  }
}
