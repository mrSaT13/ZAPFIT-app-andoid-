import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zapfit/core/services/app_settings_controller.dart';

class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key});

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  final _settings = AppSettingsController.instance;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // keep for at least 700ms so user sees splash
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() {});
    });
    // Listen for settings changes so gradient toggles update UI immediately
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _anim.dispose();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final useGradient = _settings.gradientEnabled;
    final accent = _settings.gradientAccent ?? _settings.accentColor;
    final bg = useGradient
        ? LinearGradient(
            colors: [Theme.of(context).colorScheme.primary, accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    return Scaffold(
      body: Container(
        decoration: bg == null ? null : BoxDecoration(gradient: bg),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.05).animate(
                  CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
                ),
                child: Image.asset(
                  'assets/logo/logo.png',
                  width: 140,
                  height: 140,
                ),
              ),
              const SizedBox(height: 12),
              Builder(builder: (ctx) {
                final useGradient = _settings.gradientEnabled;
                final textColor = useGradient
                    ? Theme.of(ctx).colorScheme.onPrimary
                    : Theme.of(ctx).colorScheme.onBackground;
                return Column(
                  children: [
                    Text(
                      'ZAPFIT',
                      style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: 1.5,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'tracking • health • fitness',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: textColor.withOpacity(0.85),
                          ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 20),
              CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation(Theme.of(context).colorScheme.onPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
