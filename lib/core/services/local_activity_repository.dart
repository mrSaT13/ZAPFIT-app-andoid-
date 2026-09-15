import 'dart:async';
import 'dart:io';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/models/activity_media_model.dart';
import 'package:zapfit/core/models/gear_photo.dart';
import 'package:zapfit/core/models/health_models.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalActivityRepository {
  LocalActivityRepository._();
  static final LocalActivityRepository instance = LocalActivityRepository._();
  Database? _db;

  final _activityChangeController = StreamController<void>.broadcast();
  Stream<void> get activityChanges => _activityChangeController.stream;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'endurain_activities.db');

    _db = await openDatabase(
      path,
      version: 33,
      onCreate: (db, version) async {
        await _createActivityTables(db);
        await _createMediaTable(db);
        await _createHealthTables(db);
        await _createGearPhotosTable(db);
        await _createIndices(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('DB Upgrade: $oldVersion -> $newVersion');
        if (oldVersion < 15) await _createIndices(db);
        if (oldVersion < 16) {
          try {
            await db.execute('ALTER TABLE activities ADD COLUMN gear_id INTEGER');
            await db.execute('ALTER TABLE activities ADD COLUMN visibility INTEGER DEFAULT 1');
          } catch (e) {
            debugPrint('DB Upgrade v16 warning: $e');
          }
        }
        if (oldVersion < 17) {
          try {
            await db.execute('ALTER TABLE activities ADD COLUMN user_name TEXT');
            await db.execute('ALTER TABLE activities ADD COLUMN user_photo_url TEXT');
          } catch (e) {
            debugPrint('DB Upgrade v17 warning: $e');
          }
        }
        if (oldVersion < 18) {
          try {
            await db.execute('ALTER TABLE activities ADD COLUMN user_id INTEGER');
          } catch (e) {
            debugPrint('DB Upgrade v18 warning: $e');
          }
        }
        if (oldVersion < 19) {
          await _createMediaTable(db);
        }
        if (oldVersion < 20) {
          // Add heart rate records table
          await db.execute('CREATE TABLE IF NOT EXISTS heart_rate_records(id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp_ms INTEGER NOT NULL, bpm INTEGER NOT NULL, source TEXT NOT NULL DEFAULT \'health_connect\', is_synced INTEGER NOT NULL DEFAULT 0)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_hr_timestamp ON heart_rate_records(timestamp_ms)');
          // Add sleep phase columns to existing sleep_records
          try {
            await db.execute('ALTER TABLE sleep_records ADD COLUMN deep_sleep_seconds INTEGER DEFAULT 0');
            await db.execute('ALTER TABLE sleep_records ADD COLUMN light_sleep_seconds INTEGER DEFAULT 0');
            await db.execute('ALTER TABLE sleep_records ADD COLUMN rem_sleep_seconds INTEGER DEFAULT 0');
            await db.execute('ALTER TABLE sleep_records ADD COLUMN awake_sleep_seconds INTEGER DEFAULT 0');
          } catch (e) {
            debugPrint('DB Upgrade v20 sleep columns warning: $e');
          }
        }
        if (oldVersion < 21) {
          // Add body composition columns to weight_records
          try {
            await db.execute('ALTER TABLE weight_records ADD COLUMN body_fat_percentage REAL');
            await db.execute('ALTER TABLE weight_records ADD COLUMN muscle_mass_kg REAL');
            await db.execute('ALTER TABLE weight_records ADD COLUMN bone_mass_kg REAL');
            await db.execute('ALTER TABLE weight_records ADD COLUMN body_water_percentage REAL');
            await db.execute('ALTER TABLE weight_records ADD COLUMN visceral_fat_level INTEGER');
            await db.execute('ALTER TABLE weight_records ADD COLUMN bmr INTEGER');
            await db.execute('ALTER TABLE weight_records ADD COLUMN body_score INTEGER');
            await db.execute('ALTER TABLE weight_records ADD COLUMN bmi REAL');
          } catch (e) {
            debugPrint('DB Upgrade v21 body composition warning: $e');
          }
        }
        if (oldVersion < 22) {
          // Add sleep detail columns
          try {
            await db.execute('ALTER TABLE sleep_records ADD COLUMN rest_heart_rate INTEGER');
            await db.execute('ALTER TABLE sleep_records ADD COLUMN turn_over_count INTEGER');
            await db.execute('ALTER TABLE sleep_records ADD COLUMN into_sleep_count INTEGER');
            await db.execute('ALTER TABLE sleep_records ADD COLUMN lazy_bed_count INTEGER');
            await db.execute('ALTER TABLE sleep_records ADD COLUMN dream_time INTEGER');
            await db.execute('ALTER TABLE sleep_records ADD COLUMN sleep_feeling INTEGER');
          } catch (e) {
            debugPrint('DB Upgrade v22 sleep detail columns warning: $e');
          }
        }
        if (oldVersion < 23) {
          // Add steps detail columns
          try {
            await db.execute('ALTER TABLE steps_records ADD COLUMN distance_meters REAL');
            await db.execute('ALTER TABLE steps_records ADD COLUMN calories REAL');
            await db.execute('ALTER TABLE steps_records ADD COLUMN run_distance_meters INTEGER');
            await db.execute('ALTER TABLE steps_records ADD COLUMN walk_distance_meters INTEGER');
            await db.execute('ALTER TABLE steps_records ADD COLUMN run_calories REAL');
            await db.execute('ALTER TABLE steps_records ADD COLUMN walk_calories REAL');
            await db.execute('ALTER TABLE steps_records ADD COLUMN active_minutes INTEGER');
          } catch (e) {
            debugPrint('DB Upgrade v23 steps detail columns warning: $e');
          }
        }
        if (oldVersion < 24) {
          // Add source column to activities
          try {
            await db.execute("ALTER TABLE activities ADD COLUMN source TEXT DEFAULT 'local'");
          } catch (e) {
            debugPrint('DB Upgrade v24 source column warning: $e');
          }
        }
        if (oldVersion < 25) {
          // Add bmi column to weight_records
          try {
            await db.execute('ALTER TABLE weight_records ADD COLUMN bmi REAL');
          } catch (e) {
            debugPrint('DB Upgrade v25 bmi column warning: $e');
          }
        }
        if (oldVersion < 26) {
          // Ensure source column on activities (may be missing from fresh installs)
          try {
            await db.execute("ALTER TABLE activities ADD COLUMN source TEXT DEFAULT 'local'");
          } catch (_) {}
          // Ensure all body composition columns on weight_records
          for (final col in [
            'ALTER TABLE weight_records ADD COLUMN body_fat_percentage REAL',
            'ALTER TABLE weight_records ADD COLUMN muscle_mass_kg REAL',
            'ALTER TABLE weight_records ADD COLUMN bone_mass_kg REAL',
            'ALTER TABLE weight_records ADD COLUMN body_water_percentage REAL',
            'ALTER TABLE weight_records ADD COLUMN visceral_fat_level INTEGER',
            'ALTER TABLE weight_records ADD COLUMN bmr INTEGER',
            'ALTER TABLE weight_records ADD COLUMN body_score INTEGER',
            'ALTER TABLE weight_records ADD COLUMN bmi REAL',
          ]) {
            try { await db.execute(col); } catch (_) {}
          }
        }
        if (oldVersion < 27) {
          await _createGearPhotosTable(db);
        }
        if (oldVersion < 28) {
          try {
            await db.execute('ALTER TABLE sleep_records ADD COLUMN sleep_score_overall INTEGER');
          } catch (e) {
            debugPrint('DB Upgrade v28 sleep_score_overall warning: $e');
          }
        }
        if (oldVersion < 29) {
          try {
            await db.execute('ALTER TABLE sleep_records ADD COLUMN avg_heart_rate INTEGER');
            await db.execute('ALTER TABLE sleep_records ADD COLUMN min_heart_rate INTEGER');
            await db.execute('ALTER TABLE sleep_records ADD COLUMN max_heart_rate INTEGER');
          } catch (e) {
            debugPrint('DB Upgrade v29 sleep HR warning: $e');
          }
        }
        if (oldVersion < 30) {
          try {
            await db.execute('ALTER TABLE sleep_records ADD COLUMN rest_heart_rate INTEGER');
          } catch (e) {
            debugPrint('DB Upgrade v30 rest_heart_rate warning: $e');
          }
        }
        if (oldVersion < 31) {
          try {
            await db.execute('ALTER TABLE sleep_records ADD COLUMN sleep_start_time TEXT');
            await db.execute('ALTER TABLE sleep_records ADD COLUMN sleep_end_time TEXT');
          } catch (e) {
            debugPrint('DB Upgrade v31 sleep start/end time warning: $e');
          }
        }
        if (oldVersion < 32) {
          // ZAPFIT fitness metrics columns
          for (final col in [
            'ALTER TABLE activities ADD COLUMN vo2max REAL',
            'ALTER TABLE activities ADD COLUMN tss INTEGER',
            'ALTER TABLE activities ADD COLUMN hr_tss INTEGER',
            'ALTER TABLE activities ADD COLUMN trimp INTEGER',
            'ALTER TABLE activities ADD COLUMN intensity_factor REAL',
            'ALTER TABLE activities ADD COLUMN aerobic_te REAL',
            'ALTER TABLE activities ADD COLUMN anaerobic_te REAL',
            'ALTER TABLE activities ADD COLUMN epoc REAL',
            'ALTER TABLE activities ADD COLUMN suffer_score INTEGER',
            'ALTER TABLE activities ADD COLUMN efficiency_factor REAL',
          ]) {
            try { await db.execute(col); } catch (_) {}
          }
        }
        if (oldVersion < 33) {
          // Gear photos offline cache for server images
          try { await db.execute('ALTER TABLE gear_photos ADD COLUMN server_id INTEGER'); } catch (_) {}
          try { await db.execute('ALTER TABLE gear_photos ADD COLUMN synced INTEGER DEFAULT 0'); } catch (_) {}
          try { await db.execute('CREATE INDEX IF NOT EXISTS idx_gear_photos_server ON gear_photos(server_id)'); } catch (_) {}
        }
      },
    );
    await _deduplicateSteps(_db!);
    return _db!;
  }

  Future<void> _deduplicateSteps(Database db) async {
    try {
      final rows = await db.rawQuery('''
        SELECT date, COUNT(*) as cnt, MIN(id) as keep_id, MAX(steps) as max_steps
        FROM steps_records
        GROUP BY substr(date, 1, 10)
        HAVING cnt > 1
      ''');
      for (final row in rows) {
        final datePrefix = (row['date'] as String).substring(0, 10);
        final keepId = row['keep_id'] as int;
        final maxSteps = row['max_steps'] as int;
        // Update the kept record with max steps
        await db.update('steps_records', {'steps': maxSteps}, where: 'id = ?', whereArgs: [keepId]);
        // Delete duplicates
        await db.delete('steps_records', where: "id != ? AND date LIKE ?", whereArgs: [keepId, '$datePrefix%']);
      }
      if (rows.isNotEmpty) debugPrint('Dedup steps: cleaned ${rows.length} duplicate days');
    } catch (e) {
      debugPrint('Dedup steps error: $e');
    }
  }

  Future<void> _createIndices(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activities_start ON activities(started_at_ms)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_points_activity ON activity_points(activity_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_weight_date ON weight_records(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_steps_date ON steps_records(date)');
  }

  Future<void> _createActivityTables(Database db) async {
    await db.execute('''
      CREATE TABLE activities(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        user_id INTEGER,
        title TEXT NOT NULL,
        kind TEXT NOT NULL,
        started_at_ms INTEGER NOT NULL,
        ended_at_ms INTEGER,
        distance_meters REAL NOT NULL,
        duration_seconds INTEGER NOT NULL,
        notes TEXT NOT NULL,
        photo_path TEXT,
        thumbnail_url TEXT,
        upload_status TEXT NOT NULL,
        avg_heart_rate INTEGER,
        max_heart_rate INTEGER,
        gear_id INTEGER,
        visibility INTEGER DEFAULT 1,
        user_name TEXT,
        user_photo_url TEXT,
        source TEXT DEFAULT 'local',
        vo2max REAL,
        tss INTEGER,
        hr_tss INTEGER,
        trimp INTEGER,
        intensity_factor REAL,
        aerobic_te REAL,
        anaerobic_te REAL,
        epoc REAL,
        suffer_score INTEGER,
        efficiency_factor REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE activity_points(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_id INTEGER NOT NULL,
        timestamp_ms INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        speed REAL,
        accuracy REAL,
        distance_from_start REAL NOT NULL,
        heart_rate INTEGER,
        cadence INTEGER,
        power REAL,
        FOREIGN KEY(activity_id) REFERENCES activities(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createMediaTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_media(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_id INTEGER NOT NULL,
        media_path TEXT NOT NULL,
        media_type INTEGER NOT NULL DEFAULT 1,
        latitude REAL,
        longitude REAL,
        taken_at_ms INTEGER,
        caption TEXT,
        FOREIGN KEY(activity_id) REFERENCES activities(id) ON DELETE CASCADE
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_media_activity ON activity_media(activity_id)');
    } catch (_) {}
  }

  Future<void> _createGearPhotosTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gear_photos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gear_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        server_id INTEGER,
        synced INTEGER DEFAULT 0
      )
    ''');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_gear_photos_gear ON gear_photos(gear_id)');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_gear_photos_server ON gear_photos(server_id)');
    } catch (_) {}
  }

  Future<void> _createHealthTables(Database db) async {
    await db.execute('''
      CREATE TABLE weight_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weight REAL NOT NULL,
        date TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        bmi REAL,
        body_fat_percentage REAL,
        muscle_mass_kg REAL,
        bone_mass_kg REAL,
        body_water_percentage REAL,
        visceral_fat_level INTEGER,
        bmr INTEGER,
        body_score INTEGER
      )
    ''');
    await db.execute('CREATE TABLE sleep_records(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, total_sleep_seconds INTEGER NOT NULL, deep_sleep_seconds INTEGER DEFAULT 0, light_sleep_seconds INTEGER DEFAULT 0, rem_sleep_seconds INTEGER DEFAULT 0, awake_sleep_seconds INTEGER DEFAULT 0, sleep_score_overall INTEGER, rest_heart_rate INTEGER, avg_heart_rate INTEGER, min_heart_rate INTEGER, max_heart_rate INTEGER, sleep_start_time TEXT, sleep_end_time TEXT, is_synced INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE water_records(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, amount_ml REAL NOT NULL, is_synced INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE steps_records(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, steps INTEGER NOT NULL, is_synced INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE heart_rate_records(id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp_ms INTEGER NOT NULL, bpm INTEGER NOT NULL, source TEXT NOT NULL DEFAULT \'health_connect\', is_synced INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_hr_timestamp ON heart_rate_records(timestamp_ms)');
  }

  void _notifyChanges() {
    if (_suppressChanges) return;
    if (!_activityChangeController.isClosed) _activityChangeController.add(null);
  }

  bool _suppressChanges = false;

  /// Suppress activityChanges events during bulk operations (e.g. feed sync).
  Future<T> withSuppressedChanges<T>(Future<T> Function() fn) async {
    _suppressChanges = true;
    try {
      return await fn();
    } finally {
      _suppressChanges = false;
    }
  }

  Future<int> createActivity(ActivityRecord activity) async {
    try {
      final db = await _database();
      final id = await db.insert('activities', activity.toMap());
      _notifyChanges();
      return id;
    } catch (e) {
      debugPrint('Repository: Error creating activity: $e');
      rethrow;
    }
  }

  /// Deduplicate activity: if same serverId exists, update; if same title+startedAt exists, skip.
  /// Also checks for near-duplicates (same kind + similar distance + same day).
  /// Returns the existing activity ID if duplicate found, or the new ID if created.
  Future<int> upsertActivity(ActivityRecord activity) async {
    try {
      final db = await _database();
      
      // Check by serverId first (most reliable)
      if (activity.serverId != null) {
        final existing = await db.query('activities',
          where: 'server_id = ?', whereArgs: [activity.serverId], limit: 1);
        if (existing.isNotEmpty) {
          final existingId = existing.first['id'] as int;
          await db.update('activities', activity.toMap(),
            where: 'id = ?', whereArgs: [existingId]);
          _notifyChanges();
          return existingId;
        }
      }
      
      // Check by title + startedAt (for GPX imports)
      final startMs = activity.startedAt.millisecondsSinceEpoch;
      final sameMoment = await db.query('activities',
        where: 'title = ? AND started_at_ms = ?',
        whereArgs: [activity.title, startMs],
        limit: 1);
      if (sameMoment.isNotEmpty) {
        final existingId = sameMoment.first['id'] as int;
        await db.update('activities', activity.toMap(),
          where: 'id = ?', whereArgs: [existingId]);
        _notifyChanges();
        return existingId;
      }

      // Check for near-duplicate: same kind + similar distance (±100m) + same day
      final dayStart = DateTime(activity.startedAt.year, activity.startedAt.month, activity.startedAt.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final dayStartMs = dayStart.millisecondsSinceEpoch;
      final dayEndMs = dayEnd.millisecondsSinceEpoch;
      final sameKindNear = await db.query('activities',
        where: 'kind = ? AND started_at_ms >= ? AND started_at_ms < ? AND ABS(distance_meters - ?) < 100',
        whereArgs: [activity.kind.name, dayStartMs, dayEndMs, activity.distanceMeters],
        limit: 1);
      if (sameKindNear.isNotEmpty) {
        final existingId = sameKindNear.first['id'] as int;
        // Update the existing activity with new data (prefer longer duration/higher quality)
        final existingDuration = sameKindNear.first['duration_seconds'] as int? ?? 0;
        if (activity.durationSeconds >= existingDuration) {
          await db.update('activities', activity.toMap(),
            where: 'id = ?', whereArgs: [existingId]);
        }
        _notifyChanges();
        return existingId;
      }
      
      // No duplicate found — create new
      final id = await db.insert('activities', activity.toMap());
      _notifyChanges();
      return id;
    } catch (e) {
      debugPrint('Repository: Error upserting activity: $e');
      rethrow;
    }
  }

  Future<void> updateActivity(ActivityRecord activity) async {
    try {
      final db = await _database();
      await db.update('activities', activity.toMap(), where: 'id = ?', whereArgs: [activity.id]);
      _notifyChanges();
    } catch (e) {
      debugPrint('Repository: Error updating activity: $e');
    }
  }

  Future<List<ActivityRecord>> getActivities() async {
    try {
      final db = await _database();
      final rows = await db.query('activities', orderBy: 'started_at_ms DESC');
      return rows.map(ActivityRecord.fromMap).toList();
    } catch (e) {
      debugPrint('Repository: Error getting activities: $e');
      return [];
    }
  }

  Future<ActivityRecord?> getActivity(int activityId) async {
    final db = await _database();
    final rows = await db.query('activities', where: 'id = ?', whereArgs: [activityId]);
    return rows.isEmpty ? null : ActivityRecord.fromMap(rows.first);
  }

  Future<ActivityRecord?> getActivityByServerId(int serverId) async {
    final db = await _database();
    final rows = await db.query('activities', where: 'server_id = ?', whereArgs: [serverId]);
    return rows.isEmpty ? null : ActivityRecord.fromMap(rows.first);
  }

  Future<List<ActivityRecord>> getActivitiesByGearId(int gearId, {int limit = 10}) async {
    try {
      final db = await _database();
      final rows = await db.query(
        'activities',
        where: 'gear_id = ?',
        whereArgs: [gearId],
        orderBy: 'started_at_ms DESC',
        limit: limit,
      );
      return rows.map(ActivityRecord.fromMap).toList();
    } catch (e) {
      debugPrint('Repository: Error getting activities by gear: $e');
      return [];
    }
  }

  Future<void> deleteActivity(int activityId) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.delete('activity_points', where: 'activity_id = ?', whereArgs: [activityId]);
      await txn.delete('activities', where: 'id = ?', whereArgs: [activityId]);
    });
    _notifyChanges();
  }

  Future<void> addPoint(ActivityPoint point) async {
    final db = await _database();
    await db.insert('activity_points', point.toMap());
  }

  Future<void> updatePoint(ActivityPoint point) async {
    if (point.id == null) return;
    final db = await _database();
    await db.update('activity_points', point.toMap(), where: 'id = ?', whereArgs: [point.id]);
  }

  Future<void> deletePoint(int pointId) async {
    final db = await _database();
    await db.delete('activity_points', where: 'id = ?', whereArgs: [pointId]);
  }

  Future<void> deletePointsForActivity(int activityId) async {
    final db = await _database();
    await db.delete('activity_points', where: 'activity_id = ?', whereArgs: [activityId]);
  }

  Future<void> addPointsBatch(List<ActivityPoint> points) async {
    if (points.isEmpty) return;
    final db = await _database();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var p in points) {
        batch.insert('activity_points', p.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<ActivityPoint>> getPoints(int activityId) async {
    try {
      final db = await _database();
      final rows = await db.query('activity_points', where: 'activity_id = ?', whereArgs: [activityId], orderBy: 'timestamp_ms ASC');
      return rows.map(ActivityPoint.fromMap).toList();
    } catch (e) {
      debugPrint('Repository: Error getting points for activity $activityId: $e');
      return [];
    }
  }

  // --- HEALTH RECORDS CRUD ---
  
  Future<void> addWeightRecord(WeightRecord record) async {
    final db = await _database();
    final dateStr = record.date.toIso8601String().split('T')[0];
    // Check for existing record on the same date
    final existing = await db.query('weight_records', where: 'date LIKE ?', whereArgs: ['$dateStr%'], limit: 1);
    final data = <String, dynamic>{
      'weight': record.weight,
      'date': record.date.toIso8601String(),
      'is_synced': record.isSynced ? 1 : 0,
      if (record.bmi != null) 'bmi': record.bmi,
      if (record.bodyFatPercentage != null) 'body_fat_percentage': record.bodyFatPercentage,
      if (record.muscleMassKg != null) 'muscle_mass_kg': record.muscleMassKg,
      if (record.boneMassKg != null) 'bone_mass_kg': record.boneMassKg,
      if (record.bodyWaterPercentage != null) 'body_water_percentage': record.bodyWaterPercentage,
      if (record.visceralFatLevel != null) 'visceral_fat_level': record.visceralFatLevel,
      if (record.bmr != null) 'bmr': record.bmr,
      if (record.bodyScore != null) 'body_score': record.bodyScore,
    };
    if (existing.isNotEmpty) {
      await db.update('weight_records', data, where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      await db.insert('weight_records', data);
    }
  }

  Future<void> updateWeightRecord(WeightRecord record) async {
    if (record.id == null) return;
    final db = await _database();
    await db.update('weight_records', {
      'weight': record.weight,
      'is_synced': record.isSynced ? 1 : 0,
      if (record.bodyFatPercentage != null) 'body_fat_percentage': record.bodyFatPercentage,
      if (record.muscleMassKg != null) 'muscle_mass_kg': record.muscleMassKg,
      if (record.boneMassKg != null) 'bone_mass_kg': record.boneMassKg,
      if (record.bodyWaterPercentage != null) 'body_water_percentage': record.bodyWaterPercentage,
      if (record.visceralFatLevel != null) 'visceral_fat_level': record.visceralFatLevel,
      if (record.bmr != null) 'bmr': record.bmr,
      if (record.bodyScore != null) 'body_score': record.bodyScore,
    }, where: 'id = ?', whereArgs: [record.id]);
  }

  Future<void> addSleepRecord(SleepRecord record) async {
    final db = await _database();
    await db.insert('sleep_records', {
      'date': record.date.toIso8601String(),
      'total_sleep_seconds': record.totalSleepSeconds,
      'deep_sleep_seconds': record.deepSleepSeconds,
      'light_sleep_seconds': record.lightSleepSeconds,
      'rem_sleep_seconds': record.remSleepSeconds,
      'awake_sleep_seconds': record.awakeSleepSeconds,
      'sleep_score_overall': record.sleepScoreOverall,
      'rest_heart_rate': record.restHeartRate,
      'avg_heart_rate': record.avgHeartRate,
      'min_heart_rate': record.minHeartRate,
      'max_heart_rate': record.maxHeartRate,
      'turn_over_count': record.turnOverCount,
      'into_sleep_count': record.intoSleepCount,
      'lazy_bed_count': record.lazyBedCount,
      'dream_time': record.dreamTime,
      'sleep_feeling': record.sleepFeeling,
      'is_synced': record.isSynced ? 1 : 0,
    });
  }

  Future<void> updateSleepRecord(SleepRecord record) async {
    if (record.id == null) return;
    final db = await _database();
    await db.update('sleep_records', {
      'total_sleep_seconds': record.totalSleepSeconds,
      'deep_sleep_seconds': record.deepSleepSeconds,
      'light_sleep_seconds': record.lightSleepSeconds,
      'rem_sleep_seconds': record.remSleepSeconds,
      'awake_sleep_seconds': record.awakeSleepSeconds,
      'sleep_score_overall': record.sleepScoreOverall,
      'rest_heart_rate': record.restHeartRate,
      'avg_heart_rate': record.avgHeartRate,
      'min_heart_rate': record.minHeartRate,
      'max_heart_rate': record.maxHeartRate,
      'turn_over_count': record.turnOverCount,
      'into_sleep_count': record.intoSleepCount,
      'lazy_bed_count': record.lazyBedCount,
      'dream_time': record.dreamTime,
      'sleep_feeling': record.sleepFeeling,
      'is_synced': record.isSynced ? 1 : 0,
    }, where: 'id = ?', whereArgs: [record.id]);
  }

  Future<void> addWaterRecord(WaterRecord record) async {
    final db = await _database();
    await db.insert('water_records', {'date': record.date.toIso8601String(), 'amount_ml': record.amountMl, 'is_synced': record.isSynced ? 1 : 0});
  }

  Future<void> updateWaterRecord(WaterRecord record) async {
    if (record.id == null) return;
    final db = await _database();
    await db.update('water_records', {'amount_ml': record.amountMl, 'is_synced': record.isSynced ? 1 : 0}, where: 'id = ?', whereArgs: [record.id]);
  }

  Future<void> addStepsRecord(StepsRecord record, {bool forceUpdate = false}) async {
    final db = await _database();
    final dateStr = record.date.toIso8601String().split('T')[0];
    // 1) Try exact date match
    var existing = await db.query('steps_records', where: 'date LIKE ?', whereArgs: ['$dateStr%'], limit: 1);
    // 2) If no match, look for a synced record within ±1 day (HC may shift dates UTC/local)
    if (existing.isEmpty) {
      final prev = record.date.subtract(const Duration(days: 1));
      final next = record.date.add(const Duration(days: 1));
      final prevStr = prev.toIso8601String().split('T')[0];
      final nextStr = next.toIso8601String().split('T')[0];
      final candidates = await db.query(
        'steps_records',
        where: '(date LIKE ? OR date LIKE ? OR date LIKE ?) AND is_synced = 1',
        whereArgs: ['$prevStr%', '$dateStr%', '$nextStr%'],
        limit: 1,
      );
      if (candidates.isNotEmpty) existing = candidates;
    }
    if (existing.isNotEmpty) {
      final existingSteps = existing.first['steps'] as int;
      final existingSynced = (existing.first['is_synced'] as int) == 1;
      // Don't overwrite synced records (from HC/server) with pedometer data
      if (!forceUpdate && existingSynced) return;
      if (forceUpdate || record.steps > existingSteps) {
        await db.update('steps_records', {
          'steps': record.steps,
          'is_synced': record.isSynced ? 1 : 0,
          if (record.distanceMeters != null) 'distance_meters': record.distanceMeters,
          if (record.calories != null) 'calories': record.calories,
          if (record.runDistanceMeters != null) 'run_distance_meters': record.runDistanceMeters,
          if (record.walkDistanceMeters != null) 'walk_distance_meters': record.walkDistanceMeters,
          if (record.runCalories != null) 'run_calories': record.runCalories,
          if (record.walkCalories != null) 'walk_calories': record.walkCalories,
          if (record.activeMinutes != null) 'active_minutes': record.activeMinutes,
        }, where: 'id = ?', whereArgs: [existing.first['id']]);
      }
    } else {
      await db.insert('steps_records', {
        'date': record.date.toIso8601String(),
        'steps': record.steps,
        'is_synced': record.isSynced ? 1 : 0,
        if (record.distanceMeters != null) 'distance_meters': record.distanceMeters,
        if (record.calories != null) 'calories': record.calories,
        if (record.runDistanceMeters != null) 'run_distance_meters': record.runDistanceMeters,
        if (record.walkDistanceMeters != null) 'walk_distance_meters': record.walkDistanceMeters,
        if (record.runCalories != null) 'run_calories': record.runCalories,
        if (record.walkCalories != null) 'walk_calories': record.walkCalories,
        if (record.activeMinutes != null) 'active_minutes': record.activeMinutes,
      });
    }
  }

  Future<void> updateStepsRecord(StepsRecord record) async {
    if (record.id == null) return;
    final db = await _database();
    await db.update('steps_records', {
      'steps': record.steps,
      'is_synced': record.isSynced ? 1 : 0,
      if (record.distanceMeters != null) 'distance_meters': record.distanceMeters,
      if (record.calories != null) 'calories': record.calories,
      if (record.runDistanceMeters != null) 'run_distance_meters': record.runDistanceMeters,
      if (record.walkDistanceMeters != null) 'walk_distance_meters': record.walkDistanceMeters,
      if (record.runCalories != null) 'run_calories': record.runCalories,
      if (record.walkCalories != null) 'walk_calories': record.walkCalories,
      if (record.activeMinutes != null) 'active_minutes': record.activeMinutes,
    }, where: 'id = ?', whereArgs: [record.id]);
  }

  Future<void> upsertStepsRecord(StepsRecord record) async {
    final db = await _database();
    final dateStr = record.date.toIso8601String().split('T')[0];
    await db.transaction((txn) async {
      // 1) Try exact date match
      var existing = await txn.query('steps_records', where: 'date LIKE ?', whereArgs: ['$dateStr%'], limit: 1);

      // 2) If no match, look for a synced record within ±1 day (HC may shift dates UTC/local)
      if (existing.isEmpty) {
        final prev = record.date.subtract(const Duration(days: 1));
        final next = record.date.add(const Duration(days: 1));
        final prevStr = prev.toIso8601String().split('T')[0];
        final nextStr = next.toIso8601String().split('T')[0];
        final candidates = await txn.query(
          'steps_records',
          where: '(date LIKE ? OR date LIKE ? OR date LIKE ?) AND is_synced = 1',
          whereArgs: ['$prevStr%', '$dateStr%', '$nextStr%'],
          limit: 1,
        );
        if (candidates.isNotEmpty) {
          existing = candidates;
        }
      }

      final Map<String, dynamic> data = {
        'steps': record.steps,
        'is_synced': record.isSynced ? 1 : 0,
        if (record.distanceMeters != null) 'distance_meters': record.distanceMeters,
        if (record.calories != null) 'calories': record.calories,
        if (record.runDistanceMeters != null) 'run_distance_meters': record.runDistanceMeters,
        if (record.walkDistanceMeters != null) 'walk_distance_meters': record.walkDistanceMeters,
        if (record.runCalories != null) 'run_calories': record.runCalories,
        if (record.walkCalories != null) 'walk_calories': record.walkCalories,
        if (record.activeMinutes != null) 'active_minutes': record.activeMinutes,
      };
      if (existing.isNotEmpty) {
        await txn.update('steps_records', data, where: 'id = ?', whereArgs: [existing.first['id']]);
      } else {
        data['date'] = record.date.toIso8601String();
        await txn.insert('steps_records', data);
      }
    });
  }

  Future<void> upsertWeightRecord(WeightRecord record) async {
    final db = await _database();
    final dateStr = record.date.toIso8601String().split('T')[0];
    await db.transaction((txn) async {
      final existing = await txn.query('weight_records', where: 'date LIKE ?', whereArgs: ['$dateStr%'], limit: 1);
      final alreadySynced = existing.isNotEmpty && (existing.first['is_synced'] as int) == 1;
      final Map<String, dynamic> data = {
        'weight': record.weight,
        'is_synced': alreadySynced ? 1 : (record.isSynced ? 1 : 0),
        if (record.bmi != null) 'bmi': record.bmi,
        if (record.bodyFatPercentage != null) 'body_fat_percentage': record.bodyFatPercentage,
        if (record.muscleMassKg != null) 'muscle_mass_kg': record.muscleMassKg,
        if (record.boneMassKg != null) 'bone_mass_kg': record.boneMassKg,
        if (record.bodyWaterPercentage != null) 'body_water_percentage': record.bodyWaterPercentage,
        if (record.visceralFatLevel != null) 'visceral_fat_level': record.visceralFatLevel,
        if (record.bmr != null) 'bmr': record.bmr,
        if (record.bodyScore != null) 'body_score': record.bodyScore,
      };
      if (existing.isNotEmpty) {
        await txn.update('weight_records', data, where: 'id = ?', whereArgs: [existing.first['id']]);
      } else {
        data['date'] = record.date.toIso8601String();
        await txn.insert('weight_records', data);
      }
    });
  }

  Future<void> upsertWaterRecord(WaterRecord record) async {
    final db = await _database();
    final dateStr = record.date.toIso8601String().split('T')[0];
    await db.transaction((txn) async {
      // Check if any record already exists for this date (synced or unsynced)
      final existing = await txn.query('water_records',
        where: 'date LIKE ?', whereArgs: ['$dateStr%'], limit: 1);
      if (existing.isNotEmpty) {
        // Keep the existing local time if present, only update amount
        final existingDate = existing.first['date'] as String;
        final hasTime = existingDate.contains('T') && !existingDate.endsWith('T00:00:00');
        final dateToKeep = hasTime ? existingDate : record.date.toIso8601String();
        await txn.update('water_records', {
          'date': dateToKeep,
          'amount_ml': record.amountMl,
          'is_synced': 1,
        }, where: 'id = ?', whereArgs: [existing.first['id']]);
        return;
      }
      // No record exists for this date — insert as new synced record
      await txn.insert('water_records', {
        'date': record.date.toIso8601String(),
        'amount_ml': record.amountMl,
        'is_synced': 1,
      });
    });
  }

  Future<void> upsertSleepRecord(SleepRecord record) async {
    final db = await _database();
    final dateStr = record.date.toIso8601String().split('T')[0];
    await db.transaction((txn) async {
      // 1) Try exact date match
      var existing = await txn.query('sleep_records', where: 'date LIKE ?', whereArgs: ['$dateStr%'], limit: 1);

      // 2) If no match, look for a synced record within ±1 day (HC may shift dates UTC/local)
      if (existing.isEmpty) {
        final prev = record.date.subtract(const Duration(days: 1));
        final next = record.date.add(const Duration(days: 1));
        final prevStr = prev.toIso8601String().split('T')[0];
        final nextStr = next.toIso8601String().split('T')[0];
        final candidates = await txn.query(
          'sleep_records',
          where: '(date LIKE ? OR date LIKE ? OR date LIKE ?) AND is_synced = 1',
          whereArgs: ['$prevStr%', '$dateStr%', '$nextStr%'],
          orderBy: 'ABS(total_sleep_seconds - ${record.totalSleepSeconds}) ASC',
          limit: 1,
        );
        if (candidates.isNotEmpty) {
          existing = candidates;
        }
      }

      final Map<String, dynamic> data = {
        'total_sleep_seconds': record.totalSleepSeconds,
        'deep_sleep_seconds': record.deepSleepSeconds,
        'light_sleep_seconds': record.lightSleepSeconds,
        'rem_sleep_seconds': record.remSleepSeconds,
        'awake_sleep_seconds': record.awakeSleepSeconds,
        'sleep_score_overall': record.sleepScoreOverall,
        'is_synced': record.isSynced ? 1 : 0,
        if (record.restHeartRate != null) 'rest_heart_rate': record.restHeartRate,
        if (record.avgHeartRate != null) 'avg_heart_rate': record.avgHeartRate,
        if (record.minHeartRate != null) 'min_heart_rate': record.minHeartRate,
        if (record.maxHeartRate != null) 'max_heart_rate': record.maxHeartRate,
        if (record.turnOverCount != null) 'turn_over_count': record.turnOverCount,
        if (record.intoSleepCount != null) 'into_sleep_count': record.intoSleepCount,
        if (record.lazyBedCount != null) 'lazy_bed_count': record.lazyBedCount,
        if (record.dreamTime != null) 'dream_time': record.dreamTime,
        if (record.sleepFeeling != null) 'sleep_feeling': record.sleepFeeling,
        'sleep_start_time': record.sleepStartTime?.toIso8601String(),
        'sleep_end_time': record.sleepEndTime?.toIso8601String(),
      };
      if (existing.isNotEmpty) {
        await txn.update('sleep_records', data, where: 'id = ?', whereArgs: [existing.first['id']]);
      } else {
        data['date'] = record.date.toIso8601String();
        await txn.insert('sleep_records', data);
      }
    });
  }

  // --- Heart Rate Records ---

  Future<void> addHeartRateRecord(HeartRateRecord record) async {
    final db = await _database();
    await db.insert('heart_rate_records', record.toMap()..remove('id'));
  }

  Future<void> upsertHeartRateRecord(HeartRateRecord record) async {
    final db = await _database();
    final tsMs = record.timestamp.millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final existing = await txn.query('heart_rate_records',
        where: 'timestamp_ms = ?', whereArgs: [tsMs], limit: 1);
      if (existing.isNotEmpty) {
        await txn.update('heart_rate_records', record.toMap()..remove('id'),
          where: 'id = ?', whereArgs: [existing.first['id']]);
      } else {
        await txn.insert('heart_rate_records', record.toMap()..remove('id'));
      }
    });
  }

  Future<List<HeartRateRecord>> getHeartRateRecords({DateTime? from, DateTime? to}) async {
    final db = await _database();
    String? where;
    List<dynamic>? whereArgs;
    if (from != null && to != null) {
      where = 'timestamp_ms BETWEEN ? AND ?';
      whereArgs = [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch];
    } else if (from != null) {
      where = 'timestamp_ms >= ?';
      whereArgs = [from.millisecondsSinceEpoch];
    }
    final rows = await db.query('heart_rate_records', where: where, whereArgs: whereArgs, orderBy: 'timestamp_ms DESC');
    return rows.map(HeartRateRecord.fromMap).toList();
  }

  Future<void> deleteHeartRateRecord(int id) async {
    final db = await _database();
    await db.delete('heart_rate_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WeightRecord>> getWeightRecords() async {
    final db = await _database();
    final rows = await db.query('weight_records', orderBy: 'date DESC');
    return rows.map((r) => WeightRecord(
      id: r['id'] as int,
      weight: (r['weight'] as num).toDouble(),
      date: DateTime.parse(r['date'] as String),
      isSynced: (r['is_synced'] as int) == 1,
      bmi: (r['bmi'] as num?)?.toDouble(),
      bodyFatPercentage: (r['body_fat_percentage'] as num?)?.toDouble(),
      muscleMassKg: (r['muscle_mass_kg'] as num?)?.toDouble(),
      boneMassKg: (r['bone_mass_kg'] as num?)?.toDouble(),
      bodyWaterPercentage: (r['body_water_percentage'] as num?)?.toDouble(),
      visceralFatLevel: (r['visceral_fat_level'] as num?)?.toInt(),
      bmr: (r['bmr'] as num?)?.toInt(),
      bodyScore: (r['body_score'] as num?)?.toInt(),
    )).toList();
  }

  Future<List<StepsRecord>> getStepsRecords() async {
    final db = await _database();
    final rows = await db.query('steps_records', orderBy: 'date DESC');
    return rows.map((r) => StepsRecord(
      id: r['id'] as int,
      date: DateTime.parse(r['date'] as String),
      steps: r['steps'] as int,
      isSynced: (r['is_synced'] as int) == 1,
      distanceMeters: (r['distance_meters'] as num?)?.toDouble(),
      calories: (r['calories'] as num?)?.toDouble(),
      runDistanceMeters: (r['run_distance_meters'] as num?)?.toInt(),
      walkDistanceMeters: (r['walk_distance_meters'] as num?)?.toInt(),
      runCalories: (r['run_calories'] as num?)?.toDouble(),
      walkCalories: (r['walk_calories'] as num?)?.toDouble(),
      activeMinutes: (r['active_minutes'] as num?)?.toInt(),
    )).toList();
  }

  // --- Activity Media ---

  Future<int> saveMedia(ActivityMedia media) async {
    try {
      final db = await _database();
      return await db.insert('activity_media', media.toMap()..remove('id'));
    } catch (e) {
      debugPrint('Repository: Error saving media: $e');
      return -1;
    }
  }

  Future<List<ActivityMedia>> getMediaForActivity(int activityId) async {
    try {
      final db = await _database();
      final rows = await db.query('activity_media', where: 'activity_id = ?', whereArgs: [activityId], orderBy: 'taken_at_ms ASC');
      return rows.map(ActivityMedia.fromMap).toList();
    } catch (e) {
      debugPrint('Repository: Error getting media: $e');
      return [];
    }
  }

  Future<void> deleteMedia(int mediaId) async {
    try {
      final db = await _database();
      await db.delete('activity_media', where: 'id = ?', whereArgs: [mediaId]);
    } catch (e) {
      debugPrint('Repository: Error deleting media: $e');
    }
  }

  Future<void> deleteMediaForActivity(int activityId) async {
    try {
      final db = await _database();
      await db.delete('activity_media', where: 'activity_id = ?', whereArgs: [activityId]);
    } catch (e) {
      debugPrint('Repository: Error deleting media for activity: $e');
    }
  }

  // --- Personal Records ---

  // --- Health ---

  Future<List<WaterRecord>> getWaterRecords() async {
    final db = await _database();
    final rows = await db.query('water_records', orderBy: 'date DESC');
    return rows.map((r) => WaterRecord(id: r['id'] as int, date: DateTime.parse(r['date'] as String), amountMl: (r['amount_ml'] as num).toDouble(), isSynced: (r['is_synced'] as int) == 1)).toList();
  }

  Future<List<SleepRecord>> getSleepRecords() async {
    final db = await _database();
    final rows = await db.query('sleep_records', orderBy: 'date DESC');
    return rows.map((r) => SleepRecord.fromJson(r).copyWith(
      id: r['id'] as int,
      isSynced: (r['is_synced'] as int) == 1,
      restHeartRate: (r['rest_heart_rate'] as num?)?.toInt(),
      avgHeartRate: (r['avg_heart_rate'] as num?)?.toInt(),
      minHeartRate: (r['min_heart_rate'] as num?)?.toInt(),
      maxHeartRate: (r['max_heart_rate'] as num?)?.toInt(),
      turnOverCount: (r['turn_over_count'] as num?)?.toInt(),
      intoSleepCount: (r['into_sleep_count'] as num?)?.toInt(),
      lazyBedCount: (r['lazy_bed_count'] as num?)?.toInt(),
      dreamTime: (r['dream_time'] as num?)?.toInt(),
      sleepFeeling: (r['sleep_feeling'] as num?)?.toInt(),
      sleepStartTime: _parseDateTime(r['sleep_start_time']),
      sleepEndTime: _parseDateTime(r['sleep_end_time']),
    )).toList();
  }

  DateTime? _parseDateTime(dynamic v) {
    if (v == null || v is! String || v.isEmpty) return null;
    try {
      final dt = DateTime.parse(v);
      return dt.isUtc ? dt.toLocal() : dt;
    } catch (_) { return null; }
  }

  Future<void> updateHealthSyncStatusByDate(String table, String dateStr, bool isSynced) async {
    final db = await _database();
    await db.update(table, {'is_synced': isSynced ? 1 : 0}, where: 'date LIKE ?', whereArgs: ['$dateStr%']);
  }

  Future<void> deleteHealthRecord(String table, int id) async {
    final db = await _database();
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllHealthData() async {
    final db = await _database();
    await db.delete('weight_records');
    await db.delete('sleep_records');
    await db.delete('water_records');
    await db.delete('steps_records');
  }

  void dispose() {
    _activityChangeController.close();
  }

  // --- Gear Photos ---

  Future<List<GearPhoto>> getGearPhotos(int gearId) async {
    final db = await _database();
    final rows = await db.query('gear_photos', where: 'gear_id = ?', whereArgs: [gearId], orderBy: 'created_at DESC');
    return rows.map(GearPhoto.fromDbMap).toList();
  }

  Future<int> addGearPhoto(GearPhoto photo) async {
    final db = await _database();
    return await db.insert('gear_photos', photo.toDbMap());
  }

  Future<void> deleteGearPhoto(int photoId) async {
    final db = await _database();
    await db.delete('gear_photos', where: 'id = ?', whereArgs: [photoId]);
  }

  Future<void> updateGearPhoto(GearPhoto photo) async {
    if (photo.id == null) return;
    final db = await _database();
    await db.update('gear_photos', photo.toDbMap(), where: 'id = ?', whereArgs: [photo.id]);
  }

  Future<GearPhoto?> getGearPhotoByServerId(int serverId) async {
    final db = await _database();
    final rows = await db.query('gear_photos', where: 'server_id = ?', whereArgs: [serverId], limit: 1);
    return rows.isEmpty ? null : GearPhoto.fromDbMap(rows.first);
  }

  Future<List<GearPhoto>> getAllGearPhotos() async {
    final db = await _database();
    final rows = await db.query('gear_photos', orderBy: 'created_at DESC');
    return rows.map(GearPhoto.fromDbMap).toList();
  }

  Future<List<GearPhoto>> getUnsyncedGearPhotos() async {
    final db = await _database();
    final rows = await db.query('gear_photos', where: 'synced = 0 AND server_id IS NULL', orderBy: 'created_at DESC');
    return rows.map(GearPhoto.fromDbMap).toList();
  }
}
