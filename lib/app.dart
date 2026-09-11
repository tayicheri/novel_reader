import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/settings_repository.dart';
import 'features/home/home_screen.dart';

class TayiWhisperApp extends StatefulWidget {
  const TayiWhisperApp({super.key});

  @override
  State<TayiWhisperApp> createState() => _TayiWhisperAppState();
}

class _TayiWhisperAppState extends State<TayiWhisperApp> {
  final _settingsRepository = SettingsRepository.instance;

  @override
  void initState() {
    super.initState();
    _settingsRepository.themePreference.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _settingsRepository.themePreference.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final preference = _settingsRepository.themePreference.value;
    final themeMode = switch (preference) {
      ThemePreference.system => ThemeMode.system,
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
    };

    return MaterialApp(
      title: 'Tayi Whisper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
