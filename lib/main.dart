import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final themeValue = prefs.getDouble('theme_slider_value') ?? 1.0;
  runApp(UTubeFlutterApp(initialThemeSliderValue: themeValue));
}

