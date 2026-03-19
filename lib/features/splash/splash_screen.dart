import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onDone,
  });

  final void Function(BuildContext context) onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _progressController;
  late AnimationController _iconController;
  late Animation<double> _progressAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconOpacityAnimation;

  static const _splashDuration = Duration(milliseconds: 2800);

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: _splashDuration,
    );
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _iconScaleAnimation = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: Curves.easeOutCubic,
      ),
    );
    _iconOpacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: Curves.easeOut,
      ),
    );

    _iconController.forward();
    _progressController.forward();

    _timer = Timer(_splashDuration, () {
      if (!mounted) return;
      widget.onDone(context);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Светлая тема: белый фон, аккуратная серая полоска прогресса
    final bgColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFFFFFF);
    final progressBgColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE0E0E0); // светло-серый для белой темы
    const progressColor = Color(0xFFFF0000);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            AnimatedBuilder(
              animation: Listenable.merge([_iconController]),
              builder: (context, child) {
                return Opacity(
                  opacity: _iconOpacityAnimation.value,
                  child: Transform.scale(
                    scale: _iconScaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Semantics(
                label: 'YouTube',
                image: true,
                child: const Icon(
                  Symbols.smart_display_rounded,
                  size: 96,
                  color: Colors.red,
                ),
              ),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 56, 64),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 4,
                          width: constraints.maxWidth,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Container(
                                width: constraints.maxWidth,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: progressBgColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              SizedBox(
                                width: constraints.maxWidth * _progressAnimation.value,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: progressColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
