import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var themeValue = 1.0;
  try {
    final prefs = await SharedPreferences.getInstance();
    themeValue = prefs.getDouble('theme_slider_value') ?? 1.0;
  } catch (e, st) {
    // Web: localStorage может быть недоступен; не блокируем запуск приложения.
    debugPrint('SharedPreferences unavailable: $e\n$st');
  }
  runApp(UTubeFlutterApp(initialThemeSliderValue: themeValue));
}

