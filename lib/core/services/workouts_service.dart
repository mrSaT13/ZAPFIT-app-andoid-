import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:endurain/core/di/service_locator.dart';
import 'package:endurain/core/models/workouts_models.dart';
import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/services/workouts_local_repository.dart';

/// Server access to strength workouts (`/api/v1/workouts`).
///
/// Reads pass through the local sqflite cache (offline-first: last known
/// content is always available). Writes go straight to the server when it is
/// reachable; an offline log-session lands in the local queue and is pushed
/// by {@link syncPending}.
class WorkoutsService {
  WorkoutsService._();
  static final WorkoutsService instance = WorkoutsService._();

  final ApiClient _apiClient = serviceLocator<ApiClient>();
  final WorkoutsLocalRepository _local = WorkoutsLocalRepository.instance;

  static const String _basePath = '/api/v1/workouts';

  // ---- plans ----

  /// Server plans merged over the cached copies (cached list is a fallback,
  /// not a merge source — server list wins when reachable).
  Future<List<WorkoutPlan>> fetchPlans({bool cacheFallback = true}) async {
    List<WorkoutPlan>? server;
    try {
      final response = await _apiClient.get(_basePath);
      if (response.statusCode == 200) {
        server = (json.decode(response.body) as List<dynamic>)
            .map((e) => WorkoutPlan.fromJson(e as Map<String, dynamic>))
            .toList();
        await _local.replacePlans(server);
      } else {
        debugPrint('WorkoutsService: fetchPlans status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('WorkoutsService: fetchPlans error: $e');
    }
    return server ?? (cacheFallback ? await _local.listPlans() : <WorkoutPlan>[]);
  }

  /// Creates the plan; returns the created row or null on failure.
  Future<WorkoutPlan?> createPlan({
    required String name,
    String? description,
    required List<WorkoutPlanExercise> exercises,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'description': description,
        'exercises': [for (final e in exercises) e.toPayload()],
      };
      final response = await _apiClient.post(_basePath, body: body);
      if (response.statusCode == 201) {
        final plan = WorkoutPlan.fromJson(json.decode(response.body) as Map<String, dynamic>);
        await _local.upsertPlan(plan);
        return plan;
      }
      debugPrint('WorkoutsService: createPlan status ${response.statusCode}');
    } catch (e) {
      debugPrint('WorkoutsService: createPlan error: $e');
    }
    return null;
  }

  /// Full update (exercises are replaced wholesale server-side); null on failure.
  Future<WorkoutPlan?> updatePlan(
    int planId, {
    required String name,
    String? description,
    required List<WorkoutPlanExercise> exercises,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'description': description,
        'exercises': [for (final e in exercises) e.toPayload()],
      };
      final response = await _apiClient.put('$_basePath/$planId', body: body);
      if (response.statusCode == 200) {
        final plan = WorkoutPlan.fromJson(json.decode(response.body) as Map<String, dynamic>);
        await _local.upsertPlan(plan);
        return plan;
      }
      debugPrint('WorkoutsService: updatePlan status ${response.statusCode}');
    } catch (e) {
      debugPrint('WorkoutsService: updatePlan error: $e');
    }
    return null;
  }

  /// Deletes a plan; true when gone (204) or already absent (404).
  Future<bool> deletePlan(int planId) async {
    try {
      final response = await _apiClient.delete('$_basePath/$planId');
      final ok = response.statusCode == 204 || response.statusCode == 404;
      if (ok) await _local.deletePlan(planId);
      return ok;
    } catch (e) {
      debugPrint('WorkoutsService: deletePlan error: $e');
      return false;
    }
  }

  // ---- sessions ----

  Future<List<WorkoutSession>> fetchSessions({bool cacheFallback = true}) async {
    List<WorkoutSession>? server;
    try {
      final response = await _apiClient.get('$_basePath/sessions');
      if (response.statusCode == 200) {
        server = (json.decode(response.body) as List<dynamic>)
            .map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
            .toList();
        await _local.replaceSessions(server);
      } else {
        debugPrint('WorkoutsService: fetchSessions status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('WorkoutsService: fetchSessions error: $e');
    }
    return server ?? (cacheFallback ? await _local.listSessions() : <WorkoutSession>[]);
  }

  /// Logs a session. Offline, the session is queued locally (is_synced=0) and
  /// returns `null` so the UI can say "saved locally, sync pending".
  Future<WorkoutSession?> logSession(WorkoutSession session) async {
    final pending = await _local.queueSession(session);
    try {
      final response = await _apiClient.post('$_basePath/sessions', body: session.toCreatePayload());
      if (response.statusCode == 201) {
        final created = WorkoutSession.fromJson(json.decode(response.body) as Map<String, dynamic>);
        await _local.confirmSession(pending, created);
        return created;
      }
      debugPrint('WorkoutsService: logSession status ${response.statusCode}');
    } catch (e) {
      debugPrint('WorkoutsService: logSession queued offline: $e');
    }
    return null;
  }

  /// Number of sessions recorded offline that are not yet on the server.
  Future<int> pendingCount() async {
    final pending = await _local.pendingSessions();
    return pending.length;
  }

  /// On-demand RU translation of one catalog exercise
  /// (`POST /workouts/exercises/{id}/translate`). Stateless: nothing is
  /// stored server-side. Returns (description, tip) or null when the AI
  /// provider is not configured / unreachable.
  Future<({String description, String? tip})?> translateExercise(int wgerId) async {
    try {
      final response = await _apiClient.post(
        '$_basePath/exercises/$wgerId/translate',
        body: {'language': 'ru'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return (
          description: data['description'] as String? ?? '',
          tip: (data['tip'] as String?)?.isNotEmpty == true
              ? data['tip'] as String
              : null,
        );
      }
      debugPrint('WorkoutsService: translate status ${response.statusCode}');
    } catch (e) {
      debugPrint('WorkoutsService: translate error: $e');
    }
    return null;
  }

  /// AI plan generator status (same provider as the nutrition assistant).
  /// Returns null on network errors.
  Future<({bool available, String? model})?> aiStatus() async {
    try {
      final response = await _apiClient.get('$_basePath/ai/status');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return (
          available:
              (data['enabled'] as bool? ?? false) && (data['configured'] as bool? ?? false),
          model: data['model'] as String?,
        );
      }
    } catch (e) {
      debugPrint('WorkoutsService: aiStatus error: $e');
    }
    return null;
  }

  /// Generates a multi-day plan draft from a free-text goal
  /// (`POST /workouts/ai/plan`). The draft is NOT saved — the caller shows it
  /// for review and then creates the plan via [createPlan].
  Future<AiPlanDraft?> generateAiPlan(String prompt, {String language = 'ru'}) async {
    try {
      final response = await _apiClient.post(
        '$_basePath/ai/plan',
        body: {'prompt': prompt, 'language': language},
      );
      if (response.statusCode == 200) {
        return AiPlanDraft.fromJson(
            json.decode(response.body) as Map<String, dynamic>);
      }
      debugPrint('WorkoutsService: generateAiPlan status ${response.statusCode}');
      if (response.statusCode == 503) {
        debugPrint('WorkoutsService: AI provider not configured on server');
      }
    } catch (e) {
      debugPrint('WorkoutsService: generateAiPlan error: $e');
    }
    return null;
  }

  /// Pushes unsynced local sessions; returns how many were confirmed.
  Future<int> syncPending() async {
    final pending = await _local.pendingSessions();
    var confirmed = 0;
    for (final entry in pending) {
      try {
        final response = await _apiClient.post('$_basePath/sessions', body: entry.session.toCreatePayload());
        if (response.statusCode == 201) {
          final created = WorkoutSession.fromJson(json.decode(response.body) as Map<String, dynamic>);
          await _local.confirmSession(entry, created);
          confirmed++;
        }
      } catch (e) {
        debugPrint('WorkoutsService: syncPending retry later: $e');
      }
    }
    return confirmed;
  }
}
