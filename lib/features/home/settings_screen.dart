import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.value,
    required this.onThemeChanged,
  });

  final double value;
  final void Function(double) onThemeChanged;

  @override
  Widget build(BuildContext context) {
    String label;
    if (value < 0.5) {
      label = 'Light';
    } else if (value < 1.5) {
      label = 'System';
    } else {
      label = 'Dark';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Theme',
              style: TextStyle(fontWeight: FontWeight.bold),
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
          ],
        ),
      ),
    );
  }
}

