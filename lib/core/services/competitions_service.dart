import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:endurain/core/services/api_client.dart';
import 'package:endurain/core/di/service_locator.dart';
import 'package:endurain/features/onboarding/mode_selection_screen.dart';

/// REST access to the server's competitions API (`/api/v1/competitions`),
/// the sync counterpart of the local Preparation tab.
///
/// Payload keys mirror the FastAPI schemas exactly (`extra="forbid"` on the
/// server rejects unknown fields), statuses map `finished` ↔ `completed`.
class ServerCompetition {
  final int id;
  final String name;
  final DateTime date; // Midnight of the race day.
  final double distanceKm;
  final String? note;
  final String status; // 'upcoming' | 'completed'
  final int? place;
  final int? totalParticipants;
  final int? resultTimeSec;

  const ServerCompetition({
    required this.id,
    required this.name,
    required this.date,
    required this.distanceKm,
    this.note,
    required this.status,
    this.place,
    this.totalParticipants,
    this.resultTimeSec,
  });

  factory ServerCompetition.fromJson(Map<String, dynamic> json) {
    // The API returns a plain `YYYY-MM-DD`; parse date-only so the countdown
    // stays on the calendar-day level regardless of time zone.
    return ServerCompetition(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      date: DateTime.tryParse(json['competition_date'] as String? ?? '') ?? DateTime.now(),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String?,
      status: json['status'] as String? ?? 'upcoming',
      place: (json['place'] as num?)?.toInt(),
      totalParticipants: (json['total_participants'] as num?)?.toInt(),
      resultTimeSec: (json['result_time_s'] as num?)?.toInt(),
    );
  }
}

class CompetitionsService {
  CompetitionsService._();
  static final CompetitionsService instance = CompetitionsService._();

  final ApiClient _apiClient = serviceLocator<ApiClient>();

  static const String _basePath = '/api/v1/competitions';
  static const String _dateKey = 'competition_date';
  static const String _upcomingKey = 'upcoming';
  static const String _completedKey = 'completed';

  /// Whether the app runs with a server configured (local mode skips sync).
  Future<bool> get isServerMode async =>
      await ModeSelectionScreen.getMode() == AppMode.server;

  Future<List<ServerCompetition>> fetchCompetitions() async {
    try {
      final response = await _apiClient.get(_basePath);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data
            .map((e) => ServerCompetition.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('CompetitionsService: fetchCompetitions error: $e');
    }
    return [];
  }

  /// Creates the server record; returns its id, or null on failure (the tab
  /// keeps `synced=false` and resends on the next sync).
  Future<int?> createCompetition({
    required String name,
    required DateTime date,
    required double distanceKm,
    String? note,
    required bool finished,
    int? place,
    int? totalParticipants,
    int? resultTimeSec,
  }) async {
    try {
      final response = await _apiClient.post(
        _basePath,
        body: _payload(
          name: name,
          date: date,
          distanceKm: distanceKm,
          note: note,
          finished: finished,
          place: place,
          totalParticipants: totalParticipants,
          resultTimeSec: resultTimeSec,
        ),
      );
      if (response.statusCode == 201) {
        return (json.decode(response.body)['id'] as num).toInt();
      }
      debugPrint('CompetitionsService: createCompetition status ${response.statusCode}');
    } catch (e) {
      debugPrint('CompetitionsService: createCompetition error: $e');
    }
    return null;
  }

  /// Updates an existing server record; true when the server accepted it.
  Future<bool> updateCompetition(
    int serverId, {
    required String name,
    required DateTime date,
    required double distanceKm,
    String? note,
    required bool finished,
    int? place,
    int? totalParticipants,
    int? resultTimeSec,
  }) async {
    try {
      final response = await _apiClient.put(
        '$_basePath/$serverId',
        body: _payload(
          name: name,
          date: date,
          distanceKm: distanceKm,
          note: note,
          finished: finished,
          place: place,
          totalParticipants: totalParticipants,
          resultTimeSec: resultTimeSec,
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('CompetitionsService: updateCompetition error: $e');
      return false;
    }
  }

  /// Removes a server record; true when the row is gone (204) or was never
  /// there (404) — both mean "no longer on the server".
  Future<bool> deleteCompetition(int serverId) async {
    try {
      final response = await _apiClient.delete('$_basePath/$serverId');
      return response.statusCode == 204 || response.statusCode == 404;
    } catch (e) {
      debugPrint('CompetitionsService: deleteCompetition error: $e');
      return false;
    }
  }

  Map<String, dynamic> _payload({
    required String name,
    required DateTime date,
    required double distanceKm,
    String? note,
    required bool finished,
    int? place,
    int? totalParticipants,
    int? resultTimeSec,
  }) {
    final result = <String, dynamic>{
      'name': name.length > 100 ? name.substring(0, 100) : name,
      _dateKey: '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'distance_km': distanceKm,
      'note': (note != null && note.isNotEmpty) ? (note.length > 500 ? note.substring(0, 500) : note) : null,
      'status': finished ? _completedKey : _upcomingKey,
    };
    if (place != null) result['place'] = place;
    if (totalParticipants != null) result['total_participants'] = totalParticipants;
    if (resultTimeSec != null) result['result_time_s'] = resultTimeSec;
    return result;
  }
}
