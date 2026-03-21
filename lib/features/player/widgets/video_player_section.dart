import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../../l10n/app_localizations.dart';
import 'player_progress_bar.dart';

/// Видео: скругление, тень, оверлей контролов.
class VideoPlayerSection extends StatefulWidget {
  const VideoPlayerSection({
    super.key,
    required this.isFullscreen,
    required this.initialized,
    required this.controller,
    required this.showControls,
    required this.onTap,
    required this.onBack,
    required this.onPlayPause,
    required this.onSeekRelative,
    required this.onScrubTo,
    required this.onFullscreen,
    required this.onSpeedPressed,
    required this.onSettingsPressed,
    required this.onMiniToggle,
    this.onPrevious,
    this.onNext,
  });

  final bool isFullscreen;
  final bool initialized;
  final VideoPlayerController? controller;
  final bool showControls;
  final VoidCallback onTap;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final Future<void> Function(Duration delta) onSeekRelative;
  final Future<void> Function(Duration position) onScrubTo;
  final VoidCallback onFullscreen;
  final VoidCallback onSpeedPressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onMiniToggle;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  static const double kVideoBorderRadius = 14;

  @override
  State<VideoPlayerSection> createState() => _VideoPlayerSectionState();
}

class _VideoPlayerSectionState extends State<VideoPlayerSection> {
  bool _showLeftHint = false;
  bool _showRightHint = false;
  Timer? _leftTimer;
  Timer? _rightTimer;

  @override
  void dispose() {
    _leftTimer?.cancel();
    _rightTimer?.cancel();
    super.dispose();
  }

  void _triggerLeftHint() {
    _leftTimer?.cancel();
    setState(() => _showLeftHint = true);
    _leftTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _showLeftHint = false);
    });
  }

  void _triggerRightHint() {
    _rightTimer?.cancel();
    setState(() => _showRightHint = true);
    _rightTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _showRightHint = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final initialized = widget.initialized;
    final c = widget.controller;
    final showControls = widget.showControls;
    final onTap = widget.onTap;
    final onBack = widget.onBack;
    final onPlayPause = widget.onPlayPause;
    final onSeekRelative = widget.onSeekRelative;
    final onScrubTo = widget.onScrubTo;
    final onFullscreen = widget.onFullscreen;

    final playing = c?.value.isPlaying ?? false;
    final videoAspect =
        (c == null || c.value.aspectRatio == 0) ? 16 / 9 : c.value.aspectRatio;

    Widget videoLayer = const ColoredBox(color: Colors.black);
    if (initialized && c != null) {
      videoLayer = AspectRatio(
        aspectRatio: videoAspect,
        child: VideoPlayer(c),
      );
    } else {
      videoLayer = const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Semantics(
      button: true,
      label: 'Toggle player controls',
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              widget.isFullscreen ? VideoPlayerSection.kVideoBorderRadius : 0,
            ),
            boxShadow: widget.isFullscreen ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 36,
                offset: const Offset(0, 18),
                spreadRadius: -6,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.06),
                blurRadius: 24,
                spreadRadius: -8,
              ),
            ] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              widget.isFullscreen ? VideoPlayerSection.kVideoBorderRadius : 0,
            ),
            child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Colors.black, child: videoLayer),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: () {
                            onSeekRelative(const Duration(seconds: -10));
                            _triggerLeftHint();
                          },
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: () {
                            onSeekRelative(const Duration(seconds: 10));
                            _triggerRightHint();
                          },
                        ),
                      ),
                    ],
                  ),
                  // GUI3: improved seek ripple hints
                  IgnorePointer(
                    ignoring: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: AnimatedOpacity(
                            opacity: _showLeftHint ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Symbols.replay_10_rounded, color: Colors.white, size: 36),
                                      SizedBox(height: 4),
                                      Text('-10 сек', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: AnimatedOpacity(
                            opacity: _showRightHint ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Symbols.forward_10_rounded, color: Colors.white, size: 36),
                                      SizedBox(height: 4),
                                      Text('+10 сек', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: showControls ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: IgnorePointer(
                      ignoring: !showControls,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xAA000000),
                              Color(0x00000000),
                              Color(0xAA000000),
                            ],
                            stops: [0.0, 0.55, 1.0],
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: l.t('player.tooltip.back'),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    onPressed: onBack,
                                    icon: const Icon(
                                      Symbols.arrow_back_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: l.t('player.tooltip.playbackSpeedQuality'),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    onPressed: widget.onSpeedPressed,
                                    icon: const Icon(
                                      Symbols.more_vert_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l.t('player.tooltip.settings'),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    onPressed: widget.onSettingsPressed,
                                    icon: const Icon(
                                      Symbols.settings_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // GUI8: prev | rewind | play | forward | next
                            // Always render all 5 buttons so play stays centred;
                            // prev/next are invisible (not just hidden) when unavailable.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: widget.onPrevious != null ? 1.0 : 0.0,
                                  child: IconButton(
                                    tooltip: l.t('player.tooltip.previousVideo'),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                    onPressed: widget.onPrevious,
                                    icon: const Icon(Symbols.skip_previous_rounded, color: Colors.white, size: 32),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: l.t('player.tooltip.rewind10Seconds'),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  onPressed: () => onSeekRelative(const Duration(seconds: -10)),
                                  icon: const Icon(Symbols.replay_10_rounded, color: Colors.white, size: 34),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  tooltip: playing ? l.t('player.tooltip.pause') : l.t('player.tooltip.play'),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  onPressed: onPlayPause,
                                  icon: Icon(
                                    playing ? Symbols.pause_circle_rounded : Symbols.play_circle_rounded,
                                    fill: 1,
                                    color: Colors.white,
                                    size: 54,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  tooltip: l.t('player.tooltip.forward10Seconds'),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  onPressed: () => onSeekRelative(const Duration(seconds: 10)),
                                  icon: const Icon(Symbols.forward_10_rounded, color: Colors.white, size: 34),
                                ),
                                const SizedBox(width: 4),
                                Opacity(
                                  opacity: widget.onNext != null ? 1.0 : 0.0,
                                  child: IconButton(
                                    tooltip: l.t('player.tooltip.nextVideo'),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                    onPressed: widget.onNext,
                                    icon: const Icon(Symbols.skip_next_rounded, color: Colors.white, size: 32),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // OPT1: AnimatedBuilder scopes progress redraws to bottom bar only.
                            if (c != null)
                              AnimatedBuilder(
                                animation: c,
                                builder: (_, __) {
                                  final val = c.value;
                                  final pos = val.position;
                                  final dur = val.duration;
                                  final bufEnd = val.buffered.isEmpty ? Duration.zero : val.buffered.last.end;
                                  final prog = dur.inMilliseconds == 0 ? 0.0 : pos.inMilliseconds / dur.inMilliseconds;
                                  final bufProg = dur.inMilliseconds == 0 ? 0.0 : bufEnd.inMilliseconds / dur.inMilliseconds;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 12, right: 6, bottom: 4),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${_fmtDuration(pos)} / ${_fmtDuration(dur)}',
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              tooltip: l.t('player.tooltip.miniPlayer'),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                              onPressed: widget.onMiniToggle,
                                              icon: const Icon(Symbols.picture_in_picture_rounded, color: Colors.white),
                                            ),
                                            IconButton(
                                              tooltip: widget.isFullscreen
                                                  ? l.t('player.tooltip.exitFullscreen')
                                                  : l.t('player.tooltip.fullscreen'),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                              onPressed: onFullscreen,
                                              icon: Icon(
                                                widget.isFullscreen ? Symbols.fullscreen_exit_rounded : Symbols.fullscreen_rounded,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PlayerProgressBar(
                                        value: prog,
                                        bufferedValue: bufProg,
                                        onChange: (v) async {
                                          final clamped = v.clamp(0.0, 1.0);
                                          final targetMs = (dur.inMilliseconds * clamped).round();
                                          await onScrubTo(Duration(milliseconds: targetMs));
                                        },
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                  );
                                },
                              )
                            else
                              const SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}

String _fmtDuration(Duration d) {
  final totalSeconds = d.inSeconds;
  final s = totalSeconds % 60;
  final m = (totalSeconds ~/ 60) % 60;
  final h = totalSeconds ~/ 3600;
  if (h > 0) {
    return '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString()}:${s.toString().padLeft(2, '0')}';
}
