import 'package:flutter/material.dart';

class SleepScoreResult {
  final int score;
  final String quality;
  final String qualityLabel;
  final int durationPoints;
  final int deepPoints;
  final int remPoints;
  final int awakePoints;
  final int efficiencyPoints;

  const SleepScoreResult({
    required this.score,
    required this.quality,
    required this.qualityLabel,
    this.durationPoints = 0,
    this.deepPoints = 0,
    this.remPoints = 0,
    this.awakePoints = 0,
    this.efficiencyPoints = 0,
  });
}

class SleepScoreCalculator {
  SleepScoreCalculator._();

  static SleepScoreResult calculate({
    required int totalSleepSeconds,
    required int deepSleepSeconds,
    required int lightSleepSeconds,
    required int remSleepSeconds,
    required int awakeSleepSeconds,
    double? restHr,
    int? age,
  }) {
    if (totalSleepSeconds <= 0) {
      return const SleepScoreResult(score: 0, quality: 'Нет данных', qualityLabel: 'Нет данных');
    }

    int score = 0;
    final totalH = totalSleepSeconds / 3600.0;
    final deepRatio = deepSleepSeconds / totalSleepSeconds;
    final remRatio = remSleepSeconds / totalSleepSeconds;
    final awakeRatio = awakeSleepSeconds / totalSleepSeconds;
    final efficiency = (totalSleepSeconds - awakeSleepSeconds) / totalSleepSeconds;

    int durationPoints;
    if (totalH >= 8) { durationPoints = 30; }
    else if (totalH >= 7) { durationPoints = 25; }
    else if (totalH >= 6) { durationPoints = 18; }
    else if (totalH >= 5) { durationPoints = 10; }
    else { durationPoints = 5; }
    score += durationPoints;

    int deepPoints;
    if (deepRatio >= 0.20) { deepPoints = 20; }
    else if (deepRatio >= 0.15) { deepPoints = 15; }
    else if (deepRatio >= 0.10) { deepPoints = 10; }
    else { deepPoints = 5; }
    score += deepPoints;

    int remPoints;
    if (remRatio >= 0.22) { remPoints = 15; }
    else if (remRatio >= 0.18) { remPoints = 12; }
    else if (remRatio >= 0.12) { remPoints = 8; }
    else { remPoints = 3; }
    score += remPoints;

    int awakePoints;
    if (awakeRatio <= 0.05) { awakePoints = 15; }
    else if (awakeRatio <= 0.10) { awakePoints = 12; }
    else if (awakeRatio <= 0.15) { awakePoints = 8; }
    else if (awakeRatio <= 0.25) { awakePoints = 4; }
    else { awakePoints = 0; }
    score += awakePoints;

    int efficiencyPoints;
    if (efficiency >= 0.95) { efficiencyPoints = 10; }
    else if (efficiency >= 0.90) { efficiencyPoints = 8; }
    else if (efficiency >= 0.85) { efficiencyPoints = 5; }
    else { efficiencyPoints = 2; }
    score += efficiencyPoints;

    int hrPoints;
    if (restHr != null && restHr > 0) {
      if (restHr < 55) { hrPoints = 10; }
      else if (restHr < 65) { hrPoints = 8; }
      else if (restHr < 75) { hrPoints = 5; }
      else { hrPoints = 2; }
    } else {
      hrPoints = 5;
    }
    score += hrPoints;

    score = score.clamp(0, 100);

    String quality;
    String qualityLabel;
    if (score >= 90) { quality = 'Отлично'; qualityLabel = 'Отлично'; }
    else if (score >= 75) { quality = 'Хорошо'; qualityLabel = 'Хорошо'; }
    else if (score >= 60) { quality = 'Удовл.'; qualityLabel = 'Удовлетворительно'; }
    else if (score >= 40) { quality = 'Плохо'; qualityLabel = 'Плохо'; }
    else { quality = 'Критично'; qualityLabel = 'Критично'; }

    return SleepScoreResult(
      score: score,
      quality: quality,
      qualityLabel: qualityLabel,
      durationPoints: durationPoints,
      deepPoints: deepPoints,
      remPoints: remPoints,
      awakePoints: awakePoints,
      efficiencyPoints: efficiencyPoints,
    );
  }

  static Color qualityColor(String quality) {
    switch (quality) {
      case 'Отлично': return Colors.green;
      case 'Хорошо': return Colors.lightGreen;
      case 'Удовл.': return Colors.orange;
      case 'Плохо': return Colors.deepOrange;
      case 'Критично': return Colors.red;
      default: return Colors.grey;
    }
  }

  static String classify(int score) {
    if (score >= 90) return 'Отлично';
    if (score >= 75) return 'Хорошо';
    if (score >= 60) return 'Удовл.';
    if (score >= 40) return 'Плохо';
    return 'Критично';
  }
}
