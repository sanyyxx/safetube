import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/home/home_shell.dart';
import 'features/splash/splash_screen.dart';
import 'l10n/app_localizations.dart';

class UTubeFlutterApp extends StatefulWidget {
  const UTubeFlutterApp({super.key, this.initialThemeSliderValue = 1.0});

  final double initialThemeSliderValue;

  @override
  State<UTubeFlutterApp> createState() => _UTubeFlutterAppState();
}

class _UTubeFlutterAppState extends State<UTubeFlutterApp> {
  static const _keyThemeSlider = 'theme_slider_value';

  late ThemeMode _themeMode;
  late double _themeSliderValue;
  Locale _locale = const Locale('ru');

  static ThemeMode _themeModeFromSlider(double value) {
    if (value < 0.5) return ThemeMode.light;
    if (value < 1.5) return ThemeMode.system;
    return ThemeMode.dark;
  }

  @override
  void initState() {
    super.initState();
    _themeSliderValue = widget.initialThemeSliderValue;
    _themeMode = _themeModeFromSlider(_themeSliderValue);
  }

  Future<void> _updateTheme(double value) async {
    setState(() {
      _themeSliderValue = value;
      _themeMode = _themeModeFromSlider(value);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyThemeSlider, value);
  }

  void _updateLocale(Locale locale) {
    setState(() {
      _locale = locale;
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
      locale: _locale,
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
        Locale('kk'),
      ],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SplashScreen(
        onDone: (context) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => HomeShell(
                onThemeChanged: _updateTheme,
                themeSliderValue: _themeSliderValue,
                locale: _locale,
                onLocaleChanged: _updateLocale,
              ),
            ),
          );
        },
      ),
    );
  }
}
