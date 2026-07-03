import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

class TayiWhisperApp extends StatefulWidget {
  const TayiWhisperApp({super.key});

  @override
  State<TayiWhisperApp> createState() => _TayiWhisperAppState();
}

class _TayiWhisperAppState extends State<TayiWhisperApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tayi Whisper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
