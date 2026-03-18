import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.value,
    required this.onThemeChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  final double value;
  final void Function(double) onThemeChanged;
  final Locale locale;
  final void Function(Locale) onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final langCode = locale.languageCode;
    String label;
    if (value < 0.5) {
      label = l.t('theme.light');
    } else if (value < 1.5) {
      label = l.t('theme.system');
    } else {
      label = l.t('theme.dark');
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.t('settings.title'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('settings.theme'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 2,
                    divisions: 2,
                    value: value,
                    label: label,
                    onChanged: onThemeChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              l.t('settings.language'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'ru',
                  label: Text('Русский'),
                ),
                ButtonSegment<String>(
                  value: 'en',
                  label: Text('English'),
                ),
                ButtonSegment<String>(
                  value: 'kk',
                  label: Text('Қазақша'),
                ),
              ],
              selected: <String>{langCode},
              onSelectionChanged: (set) {
                if (set.isEmpty) return;
                onLocaleChanged(Locale(set.first));
              },
            ),
          ],
        ),
      ),
    );
  }
}

