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
    _settingsRepository.isDarkMode.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _settingsRepository.isDarkMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = _settingsRepository.isDarkMode.value;

    return MaterialApp(
      title: 'Tayi Whisper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
