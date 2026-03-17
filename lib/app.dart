import 'package:flutter/material.dart';

import 'features/home/home_shell.dart';
import 'features/splash/splash_screen.dart';

class UTubeFlutterApp extends StatefulWidget {
  const UTubeFlutterApp({super.key});

  @override
  State<UTubeFlutterApp> createState() => _UTubeFlutterAppState();
}

class _UTubeFlutterAppState extends State<UTubeFlutterApp> {
  ThemeMode _themeMode = ThemeMode.system;
  double _themeSliderValue = 1; // 0=Light, 1=System, 2=Dark

  void _updateTheme(double value) {
    setState(() {
      _themeSliderValue = value;
      if (value < 0.5) {
        _themeMode = ThemeMode.light;
      } else if (value < 1.5) {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.dark;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final light = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white),
    );

    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.red,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YouTube',
      theme: light,
      darkTheme: dark,
      themeMode: _themeMode,
      home: SplashScreen(
        onDone: (context) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => HomeShell(
                onThemeChanged: _updateTheme,
                themeSliderValue: _themeSliderValue,
              ),
            ),
          );
        },
      ),
    );
  }
}
