import 'dart:async';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/models/health_models.dart';
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
      version: 3, 
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE activities(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            kind TEXT NOT NULL,
            started_at_ms INTEGER NOT NULL,
            ended_at_ms INTEGER,
            distance_meters REAL NOT NULL,
            duration_seconds INTEGER NOT NULL,
            notes TEXT NOT NULL,
            photo_path TEXT,
            upload_status TEXT NOT NULL
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
            FOREIGN KEY(activity_id) REFERENCES activities(id) ON DELETE CASCADE
          )
        ''');
        await _createWeightTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE activities ADD COLUMN photo_path TEXT');
        }
        if (oldVersion < 3) {
          await _createWeightTable(db);
        }
      },
    );
    return _db!;
  }

  Future<void> _createWeightTable(Database db) async {
    await db.execute('''
      CREATE TABLE weight_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weight REAL NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  void _notifyChanges() {
    _activityChangeController.add(null);
  }

  // Activity methods
  Future<int> createActivity(ActivityRecord activity) async {
    final db = await _database();
    final id = await db.insert('activities', activity.toMap());
    _notifyChanges();
    return id;
  }

  Future<void> updateActivity(ActivityRecord activity) async {
    final db = await _database();
    await db.update('activities', activity.toMap(), where: 'id = ?', whereArgs: [activity.id]);
    _notifyChanges();
  }

  Future<List<ActivityRecord>> getActivities() async {
    final db = await _database();
    final rows = await db.query('activities', orderBy: 'started_at_ms DESC');
    return rows.map(ActivityRecord.fromMap).toList();
  }

  Future<ActivityRecord?> getActivity(int activityId) async {
    final db = await _database();
    final rows = await db.query('activities', where: 'id = ?', whereArgs: [activityId]);
    return rows.isEmpty ? null : ActivityRecord.fromMap(rows.first);
  }

  Future<void> addPoint(ActivityPoint point) async {
    final db = await _database();
    await db.insert('activity_points', point.toMap());
  }

  Future<List<ActivityPoint>> getPoints(int activityId) async {
    final db = await _database();
    final rows = await db.query('activity_points', where: 'activity_id = ?', whereArgs: [activityId], orderBy: 'timestamp_ms ASC');
    return rows.map(ActivityPoint.fromMap).toList();
  }

  Future<void> deleteActivity(int activityId) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.delete('activity_points', where: 'activity_id = ?', whereArgs: [activityId]);
      await txn.delete('activities', where: 'id = ?', whereArgs: [activityId]);
    });
    _notifyChanges();
  }

  // Weight methods
  Future<int> addWeightRecord(WeightRecord record) async {
    final db = await _database();
    return db.insert('weight_records', {
      'weight': record.weight,
      'created_at': record.createdAt.toIso8601String(),
      'is_synced': record.isSynced ? 1 : 0,
    });
  }

  Future<List<WeightRecord>> getWeightRecords() async {
    final db = await _database();
    final rows = await db.query('weight_records', orderBy: 'created_at DESC');
    return rows.map((row) => WeightRecord(
      id: row['id'] as int,
      weight: row['weight'] as double,
      createdAt: DateTime.parse(row['created_at'] as String),
      isSynced: (row['is_synced'] as int) == 1,
    )).toList();
  }

  Future<void> updateWeightRecordSyncStatus(int id, bool isSynced) async {
    final db = await _database();
    await db.update('weight_records', {'is_synced': isSynced ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }
}
