import 'package:flutter/material.dart';
import 'package:zapfit/app.dart';
import 'package:zapfit/core/di/injection.dart' as di;
import 'package:health/health.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Health Connect early to register app with the system
  try {
    final health = Health();
    final available = await health.isHealthConnectAvailable();
    debugPrint('HealthConnect: available on startup = $available');
  } catch (e) {
    debugPrint('HealthConnect: startup check error: $e');
  }

  await di.initServiceLocator();

  runApp(const App());
}
