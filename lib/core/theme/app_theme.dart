import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:zapfit/core/constants/ui_constants.dart';

class AppTheme {
  // Material themes for Android
  static ThemeData lightTheme(Color seedColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: UIConstants.elevationNone,
      ),
    );
  }

  static ThemeData darkTheme(Color seedColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: UIConstants.elevationNone,
      ),
    );
  }

  // Cupertino themes for iOS/macOS
  static CupertinoThemeData cupertinoLightTheme(Color seedColor) {
    return CupertinoThemeData(
      primaryColor: CupertinoDynamicColor.withBrightness(
        color: seedColor,
        darkColor: seedColor,
      ),
      brightness: Brightness.light,
    );
  }

  static CupertinoThemeData cupertinoDarkTheme(Color seedColor) {
    return CupertinoThemeData(
      primaryColor: CupertinoDynamicColor.withBrightness(
        color: seedColor,
        darkColor: seedColor,
      ),
      brightness: Brightness.dark,
    );
  }
}
