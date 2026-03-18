import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lightweight JSON-based localization.
///
/// Loads `assets/i18n/{languageCode}.json` and provides `t(key)` lookup.
class AppLocalizations {
  AppLocalizations(this.locale, this._strings);

  final Locale locale;
  final Map<String, String> _strings;

  String t(String key) => _strings[key] ?? key;

  static AppLocalizations of(BuildContext context) {
    final result = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(result != null, 'No AppLocalizations found in context');
    return result!;
  }
}

class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  static const _supportedLanguageCodes = <String>['en', 'ru', 'kk'];

  @override
  bool isSupported(Locale locale) =>
      _supportedLanguageCodes.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final lang = locale.languageCode;
    final fallback = 'en';
    final assetLang = _supportedLanguageCodes.contains(lang) ? lang : fallback;
    final jsonStr = await rootBundle
        .loadString('assets/i18n/$assetLang.json');
    final Map<String, dynamic> decoded = json.decode(jsonStr) as Map<String, dynamic>;
    final map = decoded.map((k, v) => MapEntry(k, v.toString()));
    return AppLocalizations(locale, map);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

