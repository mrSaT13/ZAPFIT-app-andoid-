import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:endurain/core/models/workouts_models.dart';

/// Pending (offline) session reference so `confirmSession` can find the row.
class PendingWorkoutSession {
  final int localId;
  final WorkoutSession session;

  const PendingWorkoutSession({required this.localId, required this.session});
}

/// Local storage for strength workouts: the offline cache of plans and the
/// session queue (sessions recorded offline are pushed later, see
/// `WorkoutsService.syncPending`).
///
/// Own small database (`workouts.db`) — deliberately separate from the
/// activities repository, which has its own long migration history.
class WorkoutsLocalRepository {
  WorkoutsLocalRepository._();

  static final WorkoutsLocalRepository instance = WorkoutsLocalRepository._();

  static const String _dbName = 'workouts.db';
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
          CREATE TABLE plans (
            server_id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            source TEXT NOT NULL DEFAULT 'manual',
            exercises_json TEXT NOT NULL DEFAULT '[]',
            updated_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id INTEGER,
            plan_id INTEGER,
            date TEXT NOT NULL,
            duration_min REAL,
            calories REAL,
            comment TEXT,
            sets_json TEXT NOT NULL DEFAULT '[]',
            is_synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_sessions_synced ON sessions (is_synced)');
      },
    );
    return _db!;
  }

  // ---- plans cache ----

  Future<void> replacePlans(List<WorkoutPlan> plans) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        await txn.delete('plans');
        final batch = txn.batch();
        for (final p in plans) {
          if (p.id == null) continue;
          batch.insert('plans', {
            'server_id': p.id,
            'name': p.name,
            'description': p.description,
            'source': p.source,
            'exercises_json': json.encode(p.exercises.map((e) => e.toPayload()).toList()),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit();
      });
    } catch (e) {
      debugPrint('WorkoutsLocal: replacePlans error: $e');
    }
  }

  Future<void> upsertPlan(WorkoutPlan plan) async {
    if (plan.id == null) return;
    try {
      final db = await _database;
      await db.insert('plans', {
        'server_id': plan.id,
        'name': plan.name,
        'description': plan.description,
        'source': plan.source,
        'exercises_json': json.encode(plan.exercises.map((e) => e.toPayload()).toList()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('WorkoutsLocal: upsertPlan error: $e');
    }
  }

  Future<void> deletePlan(int serverId) async {
    try {
      final db = await _database;
      await db.delete('plans', where: 'server_id = ?', whereArgs: [serverId]);
    } catch (e) {
      debugPrint('WorkoutsLocal: deletePlan error: $e');
    }
  }

  Future<List<WorkoutPlan>> listPlans() async {
    try {
      final db = await _database;
      final rows = await db.query('plans', orderBy: 'name COLLATE NOCASE');
      return [
        for (final r in rows.cast<Map<String, dynamic>>())
          WorkoutPlan(
            id: (r['server_id'] as num?)?.toInt(),
            name: r['name'] as String? ?? '',
            description: r['description'] as String?,
            source: r['source'] as String? ?? 'manual',
            exercises: _exercisesFromJson(r['exercises_json'] as String? ?? '[]'),
          ),
      ];
    } catch (e) {
      debugPrint('WorkoutsLocal: listPlans error: $e');
      return [];
    }
  }

  // ---- sessions ----

  Future<void> replaceSessions(List<WorkoutSession> sessions) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        // Server rows replace everything except not-yet-pushed local ones.
        await txn.delete('sessions', where: 'is_synced = 1');
        final batch = txn.batch();
        for (final s in sessions) {
          if (s.id == null) continue;
          batch.insert('sessions', {
            'server_id': s.id,
            'plan_id': s.planId,
            'date': s.date,
            'duration_min': s.durationMin,
            'calories': s.calories,
            'comment': s.comment,
            'sets_json': json.encode(s.sets.map((e) => e.toPayload()).toList()),
            'is_synced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit();
      });
    } catch (e) {
      debugPrint('WorkoutsLocal: replaceSessions error: $e');
    }
  }

  /// Inserts the offline copy; returns the pending reference for later confirm.
  Future<PendingWorkoutSession> queueSession(WorkoutSession session) async {
    final db = await _database;
    final localId = await db.insert('sessions', {
      'server_id': null,
      'plan_id': session.planId,
      'date': session.date,
      'duration_min': session.durationMin,
      'calories': session.calories,
      'comment': session.comment,
      'sets_json': json.encode(session.sets.map((e) => e.toPayload()).toList()),
      'is_synced': 0,
    });
    return PendingWorkoutSession(localId: localId, session: session);
  }

  /// Replaces the pending local row with the server's (server_id + synced).
  Future<void> confirmSession(PendingWorkoutSession pending, WorkoutSession created) async {
    try {
      final db = await _database;
      await db.update(
        'sessions',
        {
          'server_id': created.id,
          'is_synced': 1,
        },
        where: 'local_id = ?',
        whereArgs: [pending.localId],
      );
    } catch (e) {
      debugPrint('WorkoutsLocal: confirmSession error: $e');
    }
  }

  Future<List<PendingWorkoutSession>> pendingSessions() async {
    try {
      final db = await _database;
      final rows = await db.query('sessions', where: 'is_synced = 0', orderBy: 'local_id');
      return [
        for (final r in rows.cast<Map<String, dynamic>>())
          PendingWorkoutSession(
            localId: (r['local_id'] as num).toInt(),
            session: _sessionFromRow(r),
          ),
      ];
    } catch (e) {
      debugPrint('WorkoutsLocal: pendingSessions error: $e');
      return [];
    }
  }

  Future<List<WorkoutSession>> listSessions() async {
    try {
      final db = await _database;
      final rows = await db.query('sessions', orderBy: 'date DESC, local_id DESC');
      return [for (final r in rows.cast<Map<String, dynamic>>()) _sessionFromRow(r)];
    } catch (e) {
      debugPrint('WorkoutsLocal: listSessions error: $e');
      return [];
    }
  }

  List<WorkoutPlanExercise> _exercisesFromJson(String raw) {
    try {
      final data = json.decode(raw) as List<dynamic>;
      return data.map((e) => WorkoutPlanExercise.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  WorkoutSession _sessionFromRow(Map<String, dynamic> r) {
    final rawSets = json.decode(r['sets_json'] as String? ?? '[]') as List<dynamic>;
    return WorkoutSession(
      id: (r['server_id'] as num?)?.toInt(),
      planId: (r['plan_id'] as num?)?.toInt(),
      date: r['date'] as String? ?? '',
      durationMin: (r['duration_min'] as num?)?.toDouble(),
      calories: (r['calories'] as num?)?.toDouble(),
      comment: r['comment'] as String?,
      sets: rawSets.map((e) => WorkoutSetLog.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
