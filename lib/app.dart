import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

class NovelReaderApp extends StatefulWidget {
  const NovelReaderApp({super.key});

  @override
  State<NovelReaderApp> createState() => _NovelReaderAppState();
}

class _NovelReaderAppState extends State<NovelReaderApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EchoRead',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
