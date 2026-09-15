import 'package:flutter/material.dart';

/// Design system spacing tokens (in logical pixels).
class ZapfitSpacing {
  ZapfitSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Design system semantic color tokens.
class ZapfitColors {
  ZapfitColors._();

  // Dark theme
  static const Color darkPrimary = Color(0xFF5EADEB);
  static const Color darkSecondary = Color(0xFF7EC8E3);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkError = Color(0xFFCF6679);
  static const Color darkOnPrimary = Colors.white;
  static const Color darkOnSurface = Colors.white;

  // Light theme
  static const Color lightPrimary = Color(0xFF1976D2);
  static const Color lightSecondary = Color(0xFF0288D1);
  static const Color lightBackground = Colors.white;
  static const Color lightSurface = Color(0xFFF5F5F5);
  static const Color lightError = Color(0xFFB00020);
  static const Color lightOnPrimary = Colors.white;
  static const Color lightOnSurface = Color(0xFF212121);
}
