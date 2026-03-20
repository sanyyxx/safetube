import 'dart:math' as math;

import 'package:flutter/material.dart';

class PlayerProgressBar extends StatelessWidget {
  const PlayerProgressBar({
    super.key,
    required this.value,
    required this.bufferedValue,
    required this.onChange,
  });

  final double value;
  final double bufferedValue;
  final ValueChanged<double> onChange;

  @override
  Widget build(BuildContext context) {
    final v = value.isFinite ? value : 0.0;
    final b = bufferedValue.isFinite ? bufferedValue : 0.0;
    final buffered = math.max(b, v);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // Constrain slider vertical footprint to fit inside fixed AspectRatio
      // (prevents RenderFlex overflow on narrow screens/web).
      child: SizedBox(
        height: 24,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            LinearProgressIndicator(
              value: buffered.clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white38),
              minHeight: 2,
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: Colors.red,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.red,
                overlayColor: Colors.red.withValues(alpha: 0.2),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 5,
                  disabledThumbRadius: 5,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 8,
                ),
              ),
              child: Slider(
                value: v.clamp(0.0, 1.0),
                onChanged: onChange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

