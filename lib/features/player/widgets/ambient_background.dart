import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:palette_generator/palette_generator.dart';

/// Ambient background behind the playing video.
///
/// This widget:
/// - Samples the current video frame (throttled) via `RepaintBoundary.toImage`.
/// - Extracts 2-4 dominant colors using `palette_generator`.
/// - Animates a multi-layer gradient with blur + glow + subtle grain.
/// - Blurs ONLY the outside-of-video area (video itself stays sharp).
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({
    super.key,
    required this.enabled,
    required this.videoAspectRatio,
    required this.videoRepaintBoundaryKey,
    this.updateInterval = const Duration(milliseconds: 420),
    this.transitionDuration = const Duration(milliseconds: 620),
    this.blurSigma = 58.0,
    this.samplingPixelRatio = 0.28,
    this.minPaletteDiff = 0.055,
    this.maxColors = 4,
    this.videoHoleInset = 14.0,
  });

  final bool enabled;
  final double videoAspectRatio;
  final GlobalKey videoRepaintBoundaryKey;

  final Duration updateInterval;
  final Duration transitionDuration;
  final double blurSigma;
  final double samplingPixelRatio;
  final double minPaletteDiff;
  final int maxColors;
  final double videoHoleInset;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  static List<Color> _fallbackPalette(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF000000) : Colors.white;
    final a = isDark ? const Color(0xFF101010) : const Color(0xFFF2F2F2);
    final b = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEAEAEA);
    final c = isDark ? const Color(0xFF6A6A6A) : const Color(0xFFBDBDBD);
    return [base, a, b, c];
  }

  Timer? _timer;
  bool _extracting = false;
  DateTime _lastExtractAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFailureAt = DateTime.fromMillisecondsSinceEpoch(0);

  // For smooth transitions.
  late List<Color> _fromColors;
  late List<Color> _toColors;
  late List<Color> _currentColors;
  int _animId = 0;

  // Grain/noise.
  ui.Image? _noise;

  bool _paletteInitialized = false;

  // Gentle "breathing" for the gradient.
  late final AnimationController _breathController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _fromColors = [const Color(0xFF000000), const Color(0xFF111111), const Color(0xFF333333), const Color(0xFF666666)];
    _toColors = _fromColors;
    _currentColors = _fromColors;
    _buildNoiseOnce();
    if (widget.enabled) {
      _startTimer();
    }
  }

  Future<void> _buildNoiseOnce() async {
    // 128x128 noise is usually enough for a subtle grain look.
    const w = 128;
    const h = 128;
    final rng = Random(1);
    final pixels = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      final v = rng.nextInt(256);
      pixels[i * 4 + 0] = v;
      pixels[i * 4 + 1] = v;
      pixels[i * 4 + 2] = v;
      pixels[i * 4 + 3] = 255;
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    _noise = await completer.future;
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If we haven't initialized palette yet, match theme brightness.
    // We keep this lightweight by only updating initial colors once.
    if (!widget.enabled) return;
    if (_paletteInitialized) return;
    _fromColors = _toColors = _currentColors = _fallbackPalette(context);
    _paletteInitialized = true;
  }

  @override
  void didUpdateWidget(covariant AmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _startTimer();
      } else {
        _timer?.cancel();
        _timer = null;
      }
    }
    if (oldWidget.videoAspectRatio != widget.videoAspectRatio) {
      // Visual-only: no palette extraction restart needed.
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.updateInterval, (_) {
      if (!mounted || !widget.enabled) return;
      _tryExtractPaletteThrottled();
    });
  }

  Future<void> _tryExtractPaletteThrottled() async {
    if (!widget.enabled) return;
    // If the frame sampling fails (e.g. controller disposed mid-transition),
    // cool down to avoid spamming assertions.
    final sinceFailure = DateTime.now().difference(_lastFailureAt);
    if (sinceFailure < const Duration(seconds: 2)) return;

    final now = DateTime.now();
    if (now.difference(_lastExtractAt) < widget.updateInterval) return;
    if (_extracting) return;

    _lastExtractAt = now;
    _extracting = true;
    try {
      final palette = await _extractPaletteFromFrame();
      if (palette == null || palette.isEmpty) return;

      final next = _normalizeColors(palette, fallback: _currentColors);
      final diff = _paletteDiff(_currentColors, next);
      if (diff < widget.minPaletteDiff) return;

      if (!mounted) return;
      setState(() {
        _fromColors = _currentColors;
        _toColors = next;
        _currentColors = next;
        _animId++;
      });
    } catch (e) {
      _lastFailureAt = DateTime.now();
      // Sampling can fail on some devices/browsers; we silently ignore.
      // (Often due to video controller disposed while we were awaiting toImage.)
    } finally {
      _extracting = false;
    }
  }

  Future<List<Color>?> _extractPaletteFromFrame() async {
    final ctx = widget.videoRepaintBoundaryKey.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;

    // Downsample aggressively: much faster + avoids huge GPU/CPU work.
    ui.Image image;
    try {
      image = await ro.toImage(pixelRatio: widget.samplingPixelRatio);
    } catch (_) {
      return null;
    }

    try {
      final generator = await PaletteGenerator.fromImage(
        image,
        maximumColorCount: 6, // keep it lighter; we only need 2–4 colors
      );
      final colors = <Color>[];

      // palette_generator gives ordered colors (most prominent first).
      for (final c in generator.colors) {
        colors.add(c);
        if (colors.length >= widget.maxColors) break;
      }

      // Fallback to dominantColor if palette is empty.
      if (colors.isEmpty && generator.dominantColor?.color != null) {
        colors.add(generator.dominantColor!.color);
      }
      return colors;
    } catch (_) {
      return null;
    } finally {
      image.dispose();
    }
  }

  List<Color> _normalizeColors(List<Color> input, {required List<Color> fallback}) {
    final max = widget.maxColors;
    final out = <Color>[];
    for (var i = 0; i < min(input.length, max); i++) {
      out.add(input[i]);
    }
    while (out.length < 4) {
      // Keep exactly 4 colors so lerp indexes are stable.
      out.add(out.isEmpty ? fallback.first : out.last);
    }
    return out;
  }

  double _paletteDiff(List<Color> a, List<Color> b) {
    final n = min(a.length, b.length);
    if (n == 0) return 0;

    double sum = 0;
    for (var i = 0; i < n; i++) {
      final c1 = a[i];
      final c2 = b[i];
      final dr = (c1.red - c2.red).toDouble();
      final dg = (c1.green - c2.green).toDouble();
      final db = (c1.blue - c2.blue).toDouble();
      // Normalize to [0..~1] range.
      sum += sqrt(dr * dr + dg * dg + db * db) / 255.0;
    }
    return sum / n;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _breathController.dispose();
    super.dispose();
  }

  Rect _videoRect(Size size, double aspectRatio) {
    final parentW = size.width;
    final parentH = size.height;
    final ar = aspectRatio <= 0 ? 16 / 9 : aspectRatio;
    double w;
    double h;

    if ((parentW / parentH) > ar) {
      // Width is "too large" -> clamp by height.
      h = parentH;
      w = h * ar;
    } else {
      // Clamp by width.
      w = parentW;
      h = w / ar;
    }

    final left = (parentW - w) / 2;
    final top = (parentH - h) / 2;
    return Rect.fromLTWH(left, top, w, h);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opacity = widget.enabled ? 1.0 : 0.0;

    // Ensure initial palette uses correct theme brightness.
    if (widget.enabled && _currentColors == _toColors) {
      // No-op: keeps lint quiet.
    }

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 220),
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              if (size.isEmpty) return const SizedBox.shrink();

              final videoRect = _videoRect(size, widget.videoAspectRatio);
              final videoCenterAlignment = Alignment(
                (videoRect.center.dx / size.width) * 2 - 1,
                (videoRect.center.dy / size.height) * 2 - 1,
              );

              final blurSigma = widget.blurSigma * (isDark ? 1.05 : 0.95);

              return AnimatedBuilder(
                animation: _breathController,
                builder: (context, _) {
                  // "Breathing": very subtle scale.
                  final breath = 0.985 + (_breathController.value * 0.03);

                  return Transform.scale(
                    scale: breath,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey<int>(_animId),
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: widget.transitionDuration,
                      curve: Curves.easeInOutCubic,
                      builder: (context, t, child) {
                        final c0 = Color.lerp(_fromColors[0], _toColors[0], t)!;
                        final c1 = Color.lerp(_fromColors[1], _toColors[1], t)!;
                        final c2 = Color.lerp(_fromColors[2], _toColors[2], t)!;
                        final c3 = Color.lerp(_fromColors[3], _toColors[3], t)!;

                        final linear = LinearGradient(
                          colors: [c0, c1, c2, c3],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        );

                        final radialFade = RadialGradient(
                          center: videoCenterAlignment,
                          radius: 0.95,
                          colors: [
                            c1.withOpacity(0.00),
                            c2.withOpacity(isDark ? 0.35 : 0.22),
                            c3.withOpacity(isDark ? 0.55 : 0.35),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        );

                        final glow = RadialGradient(
                          center: videoCenterAlignment,
                          radius: 0.65,
                          colors: [
                            c1.withOpacity(isDark ? 0.48 : 0.32),
                            c2.withOpacity(isDark ? 0.22 : 0.14),
                            c3.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.35, 1.0],
                        );

                        return AnimatedContainer(
                          duration: widget.transitionDuration,
                          child: ClipPath(
                            clipper: _OutsideVideoClipper(
                              videoRect: videoRect,
                              holeInset: widget.videoHoleInset,
                            ),
                            child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Sharp gradients (they will be blurred by BackdropFilter).
                              Container(
                                decoration: BoxDecoration(
                                  gradient: linear,
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: radialFade,
                                ),
                              ),
                              // Glow bubble around the video center.
                              Positioned(
                                left: videoRect.center.dx - videoRect.width * 0.55,
                                top: videoRect.center.dy - videoRect.height * 0.55,
                                width: videoRect.width * 1.1,
                                height: videoRect.height * 1.1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: glow,
                                    boxShadow: [
                                      BoxShadow(
                                        color: c2.withOpacity(isDark ? 0.28 : 0.18),
                                        blurRadius: blurSigma * 1.2,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Strong Gaussian blur: blur what is behind this widget,
                              // but clip the blur to "outside-of-video" region.
                              Positioned.fill(
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: blurSigma,
                                    sigmaY: blurSigma,
                                  ),
                                  child: Container(
                                    color: Colors.transparent,
                                  ),
                                ),
                              ),

                              // Subtle grain/noise on top of everything.
                              if (_noise != null)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: isDark ? 0.10 : 0.07,
                                      child: Transform.translate(
                                        offset: Offset(
                                          (_breathController.value - 0.5) *
                                              10.0,
                                          (0.5 - _breathController.value) *
                                              6.0,
                                        ),
                                        child: RawImage(
                                          image: _noise,
                                          fit: BoxFit.cover,
                                          color: isDark
                                              ? const Color(0xFFFFFFFF)
                                              : const Color(0xFF000000),
                                          colorBlendMode: BlendMode
                                              .overlay,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OutsideVideoClipper extends CustomClipper<Path> {
  _OutsideVideoClipper({required this.videoRect, required this.holeInset});
  final Rect videoRect;
  final double holeInset;

  @override
  Path getClip(Size size) {
    final full = Path()..fillType = PathFillType.evenOdd;
    full.addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Shrink the "hole" so ambient stays visible even when the aspect ratio
    // matches the player container (YouTube-like edge glow).
    final w = max(0.0, videoRect.width - 2 * holeInset);
    final h = max(0.0, videoRect.height - 2 * holeInset);
    final hole = Rect.fromLTWH(videoRect.left + holeInset, videoRect.top + holeInset, w, h);
    full.addRect(hole);
    return full;
  }

  @override
  bool shouldReclip(covariant _OutsideVideoClipper oldClipper) {
    return oldClipper.videoRect != videoRect;
  }
}

