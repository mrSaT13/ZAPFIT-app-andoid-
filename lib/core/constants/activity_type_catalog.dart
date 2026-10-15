import 'package:flutter/material.dart';
import 'package:endurain/core/models/activity.dart';

class ActivityTypeCatalogItem {
  const ActivityTypeCatalogItem({
    required this.id,
    required this.fallbackLabel,
    required this.icon,
    required this.trackingMode,
  });

  final int id;
  final String fallbackLabel;
  final IconData icon;
  final ActivityType trackingMode;
}

class ActivityTypeCatalog {
  static const List<ActivityTypeCatalogItem> items = [
    ActivityTypeCatalogItem(
      id: 1,
      fallbackLabel: 'Run',
      icon: Icons.directions_run,
      trackingMode: ActivityType.run,
    ),
    ActivityTypeCatalogItem(
      id: 2,
      fallbackLabel: 'Trail run',
      icon: Icons.terrain,
      trackingMode: ActivityType.run,
    ),
    ActivityTypeCatalogItem(
      id: 34,
      fallbackLabel: 'Track run',
      icon: Icons.track_changes,
      trackingMode: ActivityType.run,
    ),
    ActivityTypeCatalogItem(
      id: 40,
      fallbackLabel: 'Treadmill run',
      icon: Icons.directions_run,
      trackingMode: ActivityType.run,
    ),
    ActivityTypeCatalogItem(
      id: 3,
      fallbackLabel: 'Virtual run',
      icon: Icons.directions_run,
      trackingMode: ActivityType.run,
    ),
    ActivityTypeCatalogItem(
      id: 4,
      fallbackLabel: 'Road cycling',
      icon: Icons.directions_bike,
      trackingMode: ActivityType.ride,
    ),
    ActivityTypeCatalogItem(
      id: 5,
      fallbackLabel: 'Gravel cycling',
      icon: Icons.directions_bike,
      trackingMode: ActivityType.ride,
    ),
    ActivityTypeCatalogItem(
      id: 6,
      fallbackLabel: 'MTB cycling',
      icon: Icons.directions_bike,
      trackingMode: ActivityType.ride,
    ),
    ActivityTypeCatalogItem(
      id: 27,
      fallbackLabel: 'Commuting cycling',
      icon: Icons.directions_bike,
      trackingMode: ActivityType.ride,
    ),
    ActivityTypeCatalogItem(
      id: 29,
      fallbackLabel: 'Mixed surface cycling',
      icon: Icons.directions_bike,
      trackingMode: ActivityType.ride,
    ),
    ActivityTypeCatalogItem(
      id: 7,
      fallbackLabel: 'Virtual cycling',
      icon: Icons.directions_bike,
      trackingMode: ActivityType.ride,
    ),
    ActivityTypeCatalogItem(
      id: 28,
      fallbackLabel: 'Indoor cycling',
      icon: Icons.directions_bike,
      trackingMode: ActivityType.ride,
    ),
    ActivityTypeCatalogItem(
      id: 35,
      fallbackLabel: 'E-Bike cycling',
      icon: Icons.electric_bike,
      trackingMode: ActivityType.ride,
    ),
    ActivityTypeCatalogItem(
      id: 36,
      fallbackLabel: 'E-Bike mountain cycling',
      icon: Icons.electric_bike,
      trackingMode: ActivityType.ride,
    ),
    ActivityTypeCatalogItem(
      id: 8,
      fallbackLabel: 'Indoor swimming',
      icon: Icons.pool,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 9,
      fallbackLabel: 'Open water swimming',
      icon: Icons.pool,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 10,
      fallbackLabel: 'General workout',
      icon: Icons.fitness_center,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 11,
      fallbackLabel: 'Walk',
      icon: Icons.directions_walk,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 31,
      fallbackLabel: 'Indoor walk',
      icon: Icons.directions_walk,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 12,
      fallbackLabel: 'Hike',
      icon: Icons.hiking,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 13,
      fallbackLabel: 'Rowing',
      icon: Icons.sailing,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 14,
      fallbackLabel: 'Yoga',
      icon: Icons.self_improvement,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 15,
      fallbackLabel: 'Alpine ski',
      icon: Icons.downhill_skiing,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 16,
      fallbackLabel: 'Nordic ski',
      icon: Icons.downhill_skiing,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 17,
      fallbackLabel: 'Snowboard',
      icon: Icons.snowboarding,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 37,
      fallbackLabel: 'Ice skate',
      icon: Icons.ice_skating,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 18,
      fallbackLabel: 'Transition',
      icon: Icons.swap_horiz,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 19,
      fallbackLabel: 'Strength Training',
      icon: Icons.fitness_center,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 20,
      fallbackLabel: 'Crossfit',
      icon: Icons.fitness_center,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 21,
      fallbackLabel: 'Tennis',
      icon: Icons.sports_tennis,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 22,
      fallbackLabel: 'Table Tennis',
      icon: Icons.sports_tennis,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 23,
      fallbackLabel: 'Badminton',
      icon: Icons.sports_tennis,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 24,
      fallbackLabel: 'Squash',
      icon: Icons.sports_tennis,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 25,
      fallbackLabel: 'Racquetball',
      icon: Icons.sports_tennis,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 26,
      fallbackLabel: 'Pickleball',
      icon: Icons.sports_tennis,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 39,
      fallbackLabel: 'Padel',
      icon: Icons.sports_tennis,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 30,
      fallbackLabel: 'Windsurf',
      icon: Icons.air,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 32,
      fallbackLabel: 'Stand up paddling',
      icon: Icons.snowboarding,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 33,
      fallbackLabel: 'Surf',
      icon: Icons.snowboarding,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 38,
      fallbackLabel: 'Soccer',
      icon: Icons.sports_soccer,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 41,
      fallbackLabel: 'Cardio training',
      icon: Icons.monitor_heart,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 42,
      fallbackLabel: 'Kayaking',
      icon: Icons.sailing,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 43,
      fallbackLabel: 'Sailing',
      icon: Icons.air,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 44,
      fallbackLabel: 'Snow shoeing',
      icon: Icons.hiking,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 45,
      fallbackLabel: 'Inline skating',
      icon: Icons.roller_skating,
      trackingMode: ActivityType.walk,
    ),
    ActivityTypeCatalogItem(
      id: 46,
      fallbackLabel: 'HIIT',
      icon: Icons.monitor_heart,
      trackingMode: ActivityType.walk,
    ),
  ];

  static const ActivityTypeCatalogItem defaultItem = ActivityTypeCatalogItem(
    id: 1,
    fallbackLabel: 'Run',
    icon: Icons.directions_run,
    trackingMode: ActivityType.run,
  );

  static ActivityTypeCatalogItem fromSuggestedMode(ActivityType? mode) {
    if (mode == ActivityType.ride) {
      return items.firstWhere(
        (item) => item.id == 4,
        orElse: () => defaultItem,
      );
    }
    if (mode == ActivityType.walk) {
      return items.firstWhere(
        (item) => item.id == 11,
        orElse: () => defaultItem,
      );
    }
    return items.firstWhere((item) => item.id == 1, orElse: () => defaultItem);
  }

  static ActivityTypeCatalogItem byId(int id) {
    return items.firstWhere((item) => item.id == id, orElse: () => defaultItem);
  }
}
