import 'package:flutter/material.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsController.instance;
    
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        if (!settings.gradientEnabled) {
          return Container(
            color: settings.dynamicColorEnabled ? null : settings.backgroundColor,
            child: child,
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final baseColor = settings.gradientAccent ?? settings.accentColor;
        final bgColor = settings.backgroundColor;
        
        // Improve contrast by using the selected background color as the base
        final colors = isDark 
          ? [
              baseColor.withOpacity(0.3),
              bgColor,
            ]
          : [
              baseColor.withOpacity(0.2),
              bgColor,
            ];

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            gradient: settings.gradientDirection == 'radial'
                ? RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.2,
                    colors: colors,
                    stops: const [0.0, 0.7],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                    stops: const [0.0, 0.7],
                  ),
          ),
          child: child,
        );
      },
    );
  }
}
