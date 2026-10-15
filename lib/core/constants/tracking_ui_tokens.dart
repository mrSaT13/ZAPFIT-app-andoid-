import 'package:flutter/cupertino.dart';
import 'package:endurain/core/theme/endurain_design_system.dart';

class TrackingSpacing {
  static const double xs = EndurainSpacing.xxs;
  static const double sm = EndurainSpacing.xs;
  static const double md = EndurainSpacing.sm;
  static const double lg = EndurainSpacing.md;
  static const double xl = EndurainSpacing.lg;
}

class TrackingRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

class TrackingSemanticColors {
  static const Color success = EndurainColors.darkPrimary;
  static const Color warning = Color(0xFFD39A47);
  static const Color error = EndurainColors.darkError;
  static const Color info = EndurainColors.darkSecondary;
}

class TrackingTypography {
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );
  static const TextStyle meta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
}

Color cupertinoStatusColor(TrackingStatusTone tone) {
  switch (tone) {
    case TrackingStatusTone.idle:
      return const Color(0xFF5EADEB);
    case TrackingStatusTone.recording:
      return const Color(0xFFE46F7F);
    case TrackingStatusTone.stopped:
      return const Color(0xFF1FC8B6);
  }
}

enum TrackingStatusTone { idle, recording, stopped }
