import 'dart:math';

/// HR Estimation utilities for Zapfit
///
/// Provides methods to estimate resting heart rate and maximum heart rate
/// based on training history, age, and other factors.

class HrEstimator {

  /// Estimate resting heart rate based on training data and age
  ///
  /// Uses multiple approaches:
  /// 1. Average HR during sleep window (most accurate)
  /// 2. Minimum HR during sleep window (resting HR)
  /// 3. Age-based formula (220 - age) as fallback
  /// 4. Average HR from training sessions (if available)
  static int estimateRestingHr({
    int? age,
    int? sleepAvgHr,
    int? sleepMinHr,
    List<int>? trainingHrValues,
    int? userRestingHr,
  }) {
    
    // Priority 1: Use user-provided resting HR
    if (userRestingHr != null && userRestingHr > 30 && userRestingHr < 120) {
      return userRestingHr;
    }
    
    // Priority 2: Use sleep minimum HR (most accurate)
    if (sleepMinHr != null && sleepMinHr > 30 && sleepMinHr < 100) {
      return sleepMinHr;
    }
    
    // Priority 3: Use sleep average HR
    if (sleepAvgHr != null && sleepAvgHr > 30 && sleepAvgHr < 120) {
      return sleepAvgHr;
    }
    
    // Priority 4: Use training average HR
    if (trainingHrValues != null && trainingHrValues.isNotEmpty) {
      final avgTrainingHr = (trainingHrValues.reduce((a, b) => a + b) / trainingHrValues.length).round();
      if (avgTrainingHr > 30 && avgTrainingHr < 120) {
        return avgTrainingHr;
      }
    }
    
    // Priority 5: Age-based formula (220 - age)
    if (age != null && age > 10 && age < 120) {
      final ageBased = 220 - age;
      if (ageBased > 30 && ageBased < 120) {
        return ageBased;
      }
    }
    
    // Default fallback
    return 60;
  }

  /// Estimate maximum heart rate based on age
  ///
  /// Uses standard formula: 220 - age
  /// Can be adjusted by fitness level (athlete vs sedentary)
  static int estimateMaxHr({required int age, String fitnessLevel = 'average'}) {
    if (age <= 10 || age >= 120) {
      return 190; // Default for invalid age
    }
    
    final baseMax = 220 - age;
    
    // Adjust based on fitness level
    switch (fitnessLevel.toLowerCase()) {
      case 'athlete':
        return (baseMax * 0.95).round(); // Slightly lower for trained athletes
      case 'active':
        return (baseMax * 0.98).round();
      case 'sedentary':
        return baseMax;
      default:
        return baseMax;
    }
  }

  /// Estimate recovery days based on training intensity and resting HR
  ///
  /// Formula: (maxHR - restingHR) / 10 + ageFactor
  /// Higher resting HR = more recovery needed
  /// Higher intensity = more recovery needed
  static int estimateRecoveryDays({
    required int restingHr,
    required int maxHr,
    required double trainingLoad,
    required int age,
    int? currentHr,
  }) {
    
    if (restingHr <= 0 || maxHr <= restingHr) {
      return 1;
    }
    
    // Base recovery from HR reserve
    final hrReserve = maxHr - restingHr;
    final baseRecovery = (hrReserve / 15).round();
    
    // Add age factor (older = more recovery)
    final ageFactor = (age / 20).round();
    
    // Add training load factor
    final loadFactor = (trainingLoad / 5).round();
    
    // Add current HR factor (higher current HR = more fatigue)
    final currentHrFactor = currentHr != null && currentHr > restingHr
        ? ((currentHr - restingHr) / 5).round()
        : 0;
    
    final total = baseRecovery + ageFactor + loadFactor + currentHrFactor;
    
    // Cap between 1 and 14 days
    return total.clamp(1, 14);
  }

  /// Calculate HR zones based on resting HR and max HR
  static Map<String, int> calculateHrZones({
    required int restingHr,
    required int maxHr,
    int? age,
  }) {
    final zones = <String, int>{};
    
    if (maxHr <= restingHr) {
      zones['fat_burn'] = 0;
      zones['cardio'] = 0;
      zones['peak'] = 0;
      return zones;
    }
    
    final fatBurnMax = (restingHr + (maxHr - restingHr) * 0.6).round();
    final cardioMax = (restingHr + (maxHr - restingHr) * 0.8).round();
    final peakMax = maxHr;
    
    zones['fat_burn'] = fatBurnMax;
    zones['cardio'] = cardioMax;
    zones['peak'] = peakMax;
    
    return zones;
  }

  /// Calculate training effect (aerobic vs anaerobic) based on HR data
  static Map<String, double> calculateTrainingEffect({
    required List<int> hrValues,
    required int restingHr,
    required int maxHr,
  }) {
    if (hrValues.isEmpty || maxHr <= restingHr) {
      return {'aerobic': 0.0, 'anaerobic': 0.0};
    }
    
    final avgHr = hrValues.reduce((a, b) => a + b) / hrValues.length;
    final hrReserve = maxHr - restingHr;
    final relativeHr = avgHr - restingHr;
    
    // Calculate percentage in each zone
    final aerobic = min(1.0, max(0.0, relativeHr / (hrReserve * 0.6)));
    final anaerobic = min(1.0, max(0.0, (relativeHr - hrReserve * 0.6) / (hrReserve * 0.4)));
    
    return {
      'aerobic': (aerobic * 100).roundToDouble() / 100,
      'anaerobic': (anaerobic * 100).roundToDouble() / 100,
    };
  }

  /// Simple formula to estimate resting HR from sleep data
  /// Takes the 10th percentile of HR values during sleep window
  static int estimateRestingHrFromSleepData(List<int> hrValues) {
    if (hrValues.isEmpty) return 60;
    
    // Sort and take 10th percentile (lowest 10% values)
    final sorted = List<int>.from(hrValues)..sort();
    final percentileIndex = (sorted.length * 0.1).floor();
    
    return sorted[percentileIndex.clamp(0, sorted.length - 1)];
  }

  /// Calculate average HR from training sessions
  static int calculateAvgTrainingHr(List<int> hrValues) {
    if (hrValues.isEmpty) return 0;
    return (hrValues.reduce((a, b) => a + b) / hrValues.length).round();
  }

  /// Calculate HR variability (simple version)
  /// Returns percentage difference between max and min HR
  static double calculateHrVariability(List<int> hrValues) {
    if (hrValues.isEmpty) return 0.0;
    
    final minHr = hrValues.reduce((a, b) => a < b ? a : b);
    final maxHr = hrValues.reduce((a, b) => a > b ? a : b);
    
    if (minHr <= 0) return 0.0;
    
    return ((maxHr - minHr) / minHr * 100).roundToDouble() / 100;
  }
}