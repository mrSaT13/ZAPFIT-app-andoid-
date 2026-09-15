import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zapfit/core/models/activity_models.dart';
import 'package:zapfit/core/services/local_activity_repository.dart';

class TrainingAnalysis {
  final String verdict;
  final String details;
  final IconData icon;
  final String? emoji; // deprecated: оставляем для совместимости, не используется
  final double? speedDelta; // % faster/slower than average
  final double? hrDelta; // BPM difference from average
  final int similarCount;
  final double avgSpeedSimilar;

  const TrainingAnalysis({
    required this.verdict,
    required this.details,
    required this.icon,
    this.emoji,
    this.speedDelta,
    this.hrDelta,
    required this.similarCount,
    required this.avgSpeedSimilar,
  });
}


class ScoredSimilar {
  final ActivityRecord activity;
  final double similarity; // 0..100
  final double distDeltaPct; // % diff distance
  final double durationDeltaPct;
  final double speedDeltaPct;
  final double targetSpeed; // km/h
  final double targetDistanceKm;
  final int targetDurationSec;

  const ScoredSimilar({
    required this.activity,
    required this.similarity,
    required this.distDeltaPct,
    required this.durationDeltaPct,
    required this.speedDeltaPct,
    required this.targetSpeed,
    required this.targetDistanceKm,
    required this.targetDurationSec,
  });
}

class TrainingAnalysisService {
  TrainingAnalysisService._();
  static final TrainingAnalysisService instance = TrainingAnalysisService._();

  final LocalActivityRepository _repository = LocalActivityRepository.instance;
  static final Map<int, _CachedAnalysis> _memCache = {};
  static const _cacheTtl = Duration(minutes: 5);

  Future<TrainingAnalysis?> analyze(ActivityRecord current) async {
    // mem cache
    if (current.id != null && _memCache.containsKey(current.id)) {
      final c = _memCache[current.id]!;
      if (DateTime.now().difference(c.ts).inMinutes < 5) return c.analysis;
    }
    try {
      final allActivities = await _repository.getActivities();
      if (allActivities.isEmpty) return null;

      // Находим похожие тренировки (тот же тип активности)
      final similar = allActivities.where((a) =>
          a.id != current.id &&
          a.kind == current.kind &&
          a.distanceMeters > 0 &&
          a.durationSeconds > 0 &&
          a.endedAt != null,
      ).toList();

      if (similar.isEmpty) {
        return TrainingAnalysis(
          verdict: 'Первая тренировка этого типа',
          details: 'Сравнение будет доступно после следующей тренировки.',
          icon: Icons.directions_run,
          emoji: '🏃',
          similarCount: 0,
          avgSpeedSimilar: 0,
        );
      }

      // Средняя скорость текущей тренировки
      final currentDurationH = current.durationSeconds / 3600.0;
      if (currentDurationH <= 0) return null;
      final currentSpeed = (current.distanceMeters / 1000) / currentDurationH;

      // Средние показатели похожих тренировок
      final avgSpeeds = similar.map((a) {
        final durH = a.durationSeconds / 3600.0;
        return durH > 0 ? (a.distanceMeters / 1000) / durH : 0.0;
      }).where((s) => s > 0).toList();

      final avgDistances = similar.map((a) => a.distanceMeters / 1000).where((d) => d > 0).toList();
      final avgDurations = similar.map((a) => a.durationSeconds / 60.0).where((d) => d > 0).toList();

      final avgSpeed = avgSpeeds.isNotEmpty
          ? avgSpeeds.reduce((a, b) => a + b) / avgSpeeds.length
          : 0.0;
      final avgDistance = avgDistances.isNotEmpty
          ? avgDistances.reduce((a, b) => a + b) / avgDistances.length
          : 0.0;
      final avgDuration = avgDurations.isNotEmpty
          ? avgDurations.reduce((a, b) => a + b) / avgDurations.length
          : 0.0;

      // Сравнение скорости
      String verdict;
      String details;
      IconData icon;
      double? speedDelta;

      if (avgSpeed > 0) {
        speedDelta = ((currentSpeed - avgSpeed) / avgSpeed) * 100;

        if (speedDelta > 10) {
          verdict = 'Отличная тренировка!';
          icon = Icons.local_fire_department;
          details = 'Вы быстрее обычного на ${speedDelta.abs().toStringAsFixed(1)}%. '
              'Средняя скорость: ${currentSpeed.toStringAsFixed(1)} км/ч vs ${avgSpeed.toStringAsFixed(1)} км/ч.';
        } else if (speedDelta > 0) {
          verdict = 'Хорошая тренировка';
          icon = Icons.thumb_up;
          details = 'Чуть быстрее обычного (+${speedDelta.abs().toStringAsFixed(1)}%). '
              'Продолжайте в том же темпе.';
        } else if (speedDelta > -10) {
          verdict = 'Нормальный темп';
          icon = Icons.check_circle;
          details = 'Чуть медленнее обычного (${speedDelta.toStringAsFixed(1)}%). '
              'Возможно, восстановление или жара.';
        } else {
          verdict = 'Медленная тренировка';
          icon = Icons.warning_amber_rounded;
          details = 'Медленнее обычного на ${speedDelta.abs().toStringAsFixed(1)}%. '
              'Проверьте восстановление и питание.';
        }
      } else {
        verdict = 'Тренировка записана';
        icon = Icons.description;
        details = 'Недостаточно данных для сравнения.';
        speedDelta = null;
      }

      // Добавляем info о дистанции/времени
      final currentDistKm = current.distanceMeters / 1000;
      final currentDurMin = current.durationSeconds / 60;

      if (similar.isNotEmpty) {
        details += '\n\nСреднее по ${similar.length} тренировкам: '
            '${avgDistance.toStringAsFixed(1)} км за ${avgDurMinStr(avgDuration)}';
      }

      final result = TrainingAnalysis(
        verdict: verdict,
        details: details,
        icon: icon,
        speedDelta: speedDelta,
        similarCount: similar.length,
        avgSpeedSimilar: avgSpeed,
      );
      if (current.id != null) _memCache[current.id!] = _CachedAnalysis(result, DateTime.now());
      // limit cache size
      if (_memCache.length > 100) _memCache.remove(_memCache.keys.first);
      return result;
    } catch (e) {
      return null;
    }
  }


  /// Returns list of similar activities with similarity score 0..100 sorted descending.
  /// Similarity is weighted: distance 35%, duration 35%, speed 30%.
  Future<List<ScoredSimilar>> getSimilarWithScores(ActivityRecord current, {int limit = 100}) async {
    try {
      final all = await _repository.getActivities();
      if (all.isEmpty) return [];
      final similar = all.where((a) =>
          a.id != current.id &&
          a.kind == current.kind &&
          a.distanceMeters > 0 &&
          a.durationSeconds > 0 &&
          a.endedAt != null).toList();
      if (similar.isEmpty) return [];
      final curDistKm = current.distanceMeters / 1000.0;
      final curDurSec = current.durationSeconds;
      final curDurH = curDurSec / 3600.0;
      final curSpeed = curDurH > 0 ? curDistKm / curDurH : 0.0;

      List<ScoredSimilar> scored = [];
      for (final a in similar) {
        final tDistKm = a.distanceMeters / 1000.0;
        final tDurSec = a.durationSeconds;
        final tDurH = tDurSec / 3600.0;
        final tSpeed = tDurH > 0 ? tDistKm / tDurH : 0.0;
        double distScore = 0, durScore = 0, speedScore = 0;
        if (curDistKm > 0 && tDistKm > 0) {
          final mx = curDistKm > tDistKm ? curDistKm : tDistKm;
          distScore = 1.0 - ((curDistKm - tDistKm).abs() / mx);
        }
        if (curDurSec > 0 && tDurSec > 0) {
          final mx = curDurSec > tDurSec ? curDurSec.toDouble() : tDurSec.toDouble();
          durScore = 1.0 - ((curDurSec - tDurSec).abs() / mx);
        }
        if (curSpeed > 0 && tSpeed > 0) {
          final mx = curSpeed > tSpeed ? curSpeed : tSpeed;
          speedScore = 1.0 - ((curSpeed - tSpeed).abs() / mx);
        }
        distScore = distScore.clamp(0.0, 1.0);
        durScore = durScore.clamp(0.0, 1.0);
        speedScore = speedScore.clamp(0.0, 1.0);
        final similarity = (distScore * 0.35 + durScore * 0.35 + speedScore * 0.30) * 100.0;
        // filter out very dissimilar (<30%) to keep list meaningful
        if (similarity < 25) continue;
        double distDeltaPct = curDistKm > 0 ? ((tDistKm - curDistKm) / curDistKm * 100) : 0;
        double durDeltaPct = curDurSec > 0 ? ((tDurSec - curDurSec) / curDurSec * 100) : 0;
        double speedDeltaPct = curSpeed > 0 ? ((tSpeed - curSpeed) / curSpeed * 100) : 0;
        scored.add(ScoredSimilar(
          activity: a,
          similarity: similarity,
          distDeltaPct: distDeltaPct,
          durationDeltaPct: durDeltaPct,
          speedDeltaPct: speedDeltaPct,
          targetSpeed: tSpeed,
          targetDistanceKm: tDistKm,
          targetDurationSec: tDurSec,
        ));
      }
      scored.sort((a,b) => b.similarity.compareTo(a.similarity));
      if (scored.length > limit) scored = scored.sublist(0, limit);
      return scored;
    } catch (e) {
      return [];
    }
  }


  String avgDurMinStr(double min) {
    final h = min ~/ 60;
    final m = (min % 60).round();
    if (h > 0) return '$h ч $m мин';
    return '$m мин';
  }
}

class _CachedAnalysis {
  final TrainingAnalysis analysis;
  final DateTime ts;
  const _CachedAnalysis(this.analysis, this.ts);
}
