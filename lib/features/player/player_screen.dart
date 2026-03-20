import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../l10n/app_localizations.dart';

import '../../data/video_item.dart';
import 'widgets/ambient_background.dart';
import 'widgets/player_metadata_panel.dart';
import 'widgets/player_progress_bar.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.video,
    required this.controller,
    required this.onEnterMini,
  });

  final VideoItem video;
  final VideoPlayerController controller;
  final VoidCallback onEnterMini;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _isMini = false;
  String _qualityLabel = 'Auto';
  Timer? _hideTimer;
  Duration _lastPosition = Duration.zero;
  int _lastProgressUiUpdateMs = 0;
  bool _keepWakelockOnDispose = false;
  bool _enterMiniRequested = false;
  final ValueNotifier<PlayerActionsState> _actions = ValueNotifier(
    const PlayerActionsState(
      liked: false,
      disliked: false,
      subscribed: false,
      likesCount: 0,
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _actions.value = _actions.value.copyWith(likesCount: 100 + math.Random().nextInt(900));
    widget.controller.addListener(_onTick);
    WakelockPlus.enable();
    _scheduleHide();
  }

  void _onTick() {
    final c = widget.controller;
    final pos = c.value.position;
    if (pos == _lastPosition) return;
    _lastPosition = pos;

    // Video progress can update frequently; rebuilding the whole screen for
    // every tick causes unnecessary work (especially on web).
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const minUiUpdateIntervalMs = 250; // ~4 FPS UI refresh
    if (!mounted) return;
    if (nowMs - _lastProgressUiUpdateMs >= minUiUpdateIntervalMs) {
      _lastProgressUiUpdateMs = nowMs;
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    widget.controller.removeListener(_onTick);
    _actions.dispose();
    if (!_keepWakelockOnDispose) {
      WakelockPlus.disable();
    }
    _exitFullscreenIfNeeded();
    super.dispose();
  }

  void _requestEnterMini() {
    if (_enterMiniRequested) return;
    _enterMiniRequested = true;

    // Мини-плеер продолжит проигрывание, поэтому wake lock нельзя
    // выключать в dispose().
    _keepWakelockOnDispose = true;
    widget.onEnterMini();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = widget.controller;
    if (state == AppLifecycleState.paused) {
      c.pause();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
  }

  Future<void> _seekRelative(Duration delta) async {
    final c = widget.controller;
    final dur = c.value.duration;
    final next = c.value.position + delta;
    final clamped = next < Duration.zero
        ? Duration.zero
        : (next > dur ? dur : next);
    await c.seekTo(clamped);
    setState(() => _showControls = true);
    _scheduleHide();
  }

  Future<void> _togglePlayPause() async {
    final c = widget.controller;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    setState(() => _showControls = true);
    _scheduleHide();
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      await _exitFullscreen();
    } else {
      await _enterFullscreen();
    }
  }

  Future<void> _enterFullscreen() async {
    setState(() => _isFullscreen = true);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    );
  }

  Future<void> _exitFullscreen() async {
    setState(() => _isFullscreen = false);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
  }

  void _exitFullscreenIfNeeded() {
    if (_isFullscreen) {
      // Fire and forget on dispose.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final isReady = c.value.isInitialized;

    final scaffold = Scaffold(
      body: SafeArea(
        top: !_isFullscreen,
        bottom: !_isFullscreen,
        child: Stack(
          children: [
            // Основной контент (большой плеер + нижняя часть)
            Column(
              children: [
                if (!_isMini)
                  _PlayerSurface(
                    isFullscreen: _isFullscreen,
                    initialized: isReady,
                    controller: c,
                    showControls: _showControls,
                    onTap: _toggleControls,
                    onBack: _requestEnterMini,
                    onPlayPause: _togglePlayPause,
                    onSeekRelative: _seekRelative,
                    onScrubTo: (d) async {
                      await c.seekTo(d);
                      setState(() => _showControls = true);
                      _scheduleHide();
                    },
                    onFullscreen: _toggleFullscreen,
                    onSpeedPressed: () => _showSpeedQualitySheet(context),
                    onSettingsPressed: () => _showPlayerSettingsSheet(context),
                    onMiniToggle: _requestEnterMini,
                  ),
                if (!_isFullscreen)
                  Expanded(
                child: PlayerMetadataPanel(
                  video: widget.video,
                  actions: _actions,
                  qualityLabel: _qualityLabel,
                  onLikeToggle: () {
                    final a = _actions.value;
                    if (a.liked) {
                      _actions.value = a.copyWith(
                        liked: false,
                        likesCount: math.max(0, a.likesCount - 1),
                      );
                      return;
                    }

                    _actions.value = a.copyWith(
                      liked: true,
                      likesCount: a.likesCount + 1,
                      disliked: false,
                    );
                  },
                  onDislikeToggle: () {
                    final a = _actions.value;
                    if (a.disliked) {
                      _actions.value = a.copyWith(disliked: false);
                      return;
                    }

                    _actions.value = a.copyWith(
                      disliked: true,
                      liked: a.liked ? false : a.liked,
                      likesCount: a.liked ? math.max(0, a.likesCount - 1) : a.likesCount,
                    );
                  },
                  onSubscribeToggle: () {
                    final a = _actions.value;
                    _actions.value = a.copyWith(subscribed: !a.subscribed);
                  },
                  onShare: () => _showShareSheet(context),
                  onDownload: () => _showDownloadSheet(context),
                  onSave: () => _showSaveToPlaylistSheet(context),
                ),
                  ),
              ],
            ),
            // Локальный мини-плеер больше не используется, мини-плеер глобальный в HomeShell
          ],
        ),
      ),
    );

    return WillPopScope(
      onWillPop: () async {
        _requestEnterMini();
        return false; // pop выполнит callback через HomeShell
      },
      child: scaffold,
    );
  }

  Future<void> _showSpeedQualitySheet(BuildContext context) async {
    final c = widget.controller;
    final currentSpeed = c.value.playbackSpeed;
    final qualityOptions = <String>['Auto', '1080p', '720p', '480p'];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final l = AppLocalizations.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  l.t('player.sheet.playbackSpeed'),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (final speed in <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                RadioListTile<double>(
                  value: speed,
                  groupValue: currentSpeed,
                  onChanged: (v) async {
                    if (v == null || c == null) return;
                    await c.setPlaybackSpeed(v);
                    if (mounted) setState(() {});
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  title: Text('${speed}x'),
                ),
              const Divider(),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  l.t('player.sheet.quality'),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ...qualityOptions.map(
                (q) => ListTile(
                  title: Text(q),
                  subtitle: q == 'Auto'
                      ? Text(l.t('player.sheet.qualityAuto'))
                      : null,
                  trailing: q == _qualityLabel
                      ? const Icon(Symbols.check_rounded, color: Colors.red)
                      : null,
                  onTap: () {
                    setState(() => _qualityLabel = q);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlayerSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                AppLocalizations.of(ctx).t('player.settings.title'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
            ),
            ListTile(
              leading: const Icon(Symbols.speed_rounded),
              title: Text(AppLocalizations.of(ctx).t('player.settings.playback')),
              subtitle: Text(AppLocalizations.of(ctx).t('player.settings.playbackSubtitle')),
              onTap: () {
                Navigator.pop(ctx);
                _showSpeedQualitySheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.closed_caption_rounded),
              title: Text(AppLocalizations.of(ctx).t('player.settings.captions')),
              subtitle: Text(AppLocalizations.of(ctx).t('player.settings.captionsSubtitle')),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Symbols.play_circle_rounded),
              title: Text(AppLocalizations.of(ctx).t('player.settings.autoplay')),
              subtitle: Text(AppLocalizations.of(ctx).t('player.settings.autoplaySubtitle')),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(ctx).t('player.sheet.share'),
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Symbols.link_rounded),
                title: Text(AppLocalizations.of(ctx).t('player.sheet.copyLink')),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).t('player.sheet.linkCopied'))),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Symbols.chat_rounded),
                title: Text(AppLocalizations.of(ctx).t('player.sheet.shareToMessages')),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Symbols.email_rounded),
                title: Text(AppLocalizations.of(ctx).t('player.sheet.shareToEmail')),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(ctx).t('player.sheet.download'),
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(ctx).t('player.sheet.downloadDescription'),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Symbols.high_quality_rounded),
                title: Text(AppLocalizations.of(ctx).t('player.downloadSheet.quality')),
                subtitle: Text('720p'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).t('player.sheet.downloading'))),
                  );
                },
                child: Text(AppLocalizations.of(context).t('player.sheet.downloadButton')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaveToPlaylistSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    final playlists = <String>[
      l.t('player.playlists.watchLater'),
      l.t('player.playlists.favorites'),
      l.t('player.playlists.music'),
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.t('player.sheet.savePlaylist'),
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              ...playlists.map(
                (name) => ListTile(
                  title: Text(name),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l
                              .t('player.snackbar.savedTo')
                              .replaceAll('%s', name),
                        ),
                      ),
                    );
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Symbols.add_rounded),
                title: Text(l.t('player.sheet.createNewPlaylist')),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerSurface extends StatefulWidget {
  const _PlayerSurface({
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

  @override
  State<_PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends State<_PlayerSurface>
    with SingleTickerProviderStateMixin {
  final GlobalKey _videoRepaintBoundaryKey = GlobalKey();

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
    final isFullscreen = widget.isFullscreen;
    final initialized = widget.initialized;
    final controller = widget.controller;
    final showControls = widget.showControls;
    final onTap = widget.onTap;
    final onBack = widget.onBack;
    final onPlayPause = widget.onPlayPause;
    final onSeekRelative = widget.onSeekRelative;
    final onScrubTo = widget.onScrubTo;
    final onFullscreen = widget.onFullscreen;

    final c = controller;
    final value = c?.value;
    final duration = value?.duration ?? Duration.zero;
    final position = value?.position ?? Duration.zero;
    final playing = value?.isPlaying ?? false;
    final buffered = (value?.buffered ?? const <DurationRange>[]);
    final bufferedEnd = buffered.isEmpty ? Duration.zero : buffered.last.end;

    final progress = duration.inMilliseconds == 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;
    final bufferProgress = duration.inMilliseconds == 0
        ? 0.0
        : bufferedEnd.inMilliseconds / duration.inMilliseconds;

    Widget content = Container(color: Colors.black);
    final bool ambientEnabled = initialized && c != null;
    final double videoAspect =
        (c?.value.aspectRatio == 0 || c == null) ? 16 / 9 : c!.value.aspectRatio;
    if (initialized && c != null) {
      content = Center(
        child: RepaintBoundary(
          key: _videoRepaintBoundaryKey,
          child: AspectRatio(
            aspectRatio: videoAspect,
            child: VideoPlayer(c),
          ),
        ),
      );
    } else {
      content = const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Semantics(
        button: true,
        label: 'Toggle player controls',
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
          fit: StackFit.expand,
          children: [
            content,
              AmbientBackground(
                enabled: ambientEnabled,
                videoAspectRatio: videoAspect,
                videoRepaintBoundaryKey: _videoRepaintBoundaryKey,
              ),
            // Double-tap seek zones (YouTube-like)
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
                 // Анимированные подсказки двойного тапа
                 IgnorePointer(
                   ignoring: true,
                   child: Row(
                     children: [
                       Expanded(
                         child: AnimatedOpacity(
                           opacity: _showLeftHint ? 1 : 0,
                           duration: const Duration(milliseconds: 150),
                           child: Align(
                             alignment: Alignment.centerLeft,
                             child: Padding(
                               padding: const EdgeInsets.only(left: 24),
                               child: Column(
                                 mainAxisSize: MainAxisSize.min,
                                 children: const [
                                   Icon(Symbols.replay_10_rounded,
                                       color: Colors.white, size: 42),
                                   SizedBox(height: 4),
                                   Text(
                                     '-10',
                                     style: TextStyle(
                                       color: Colors.white,
                                       fontWeight: FontWeight.w600,
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                           ),
                         ),
                       ),
                       Expanded(
                         child: AnimatedOpacity(
                           opacity: _showRightHint ? 1 : 0,
                           duration: const Duration(milliseconds: 150),
                           child: Align(
                             alignment: Alignment.centerRight,
                             child: Padding(
                               padding: const EdgeInsets.only(right: 24),
                               child: Column(
                                 mainAxisSize: MainAxisSize.min,
                                 children: const [
                                   Icon(Symbols.forward_10_rounded,
                                       color: Colors.white, size: 42),
                                   SizedBox(height: 4),
                                   Text(
                                     '+10',
                                     style: TextStyle(
                                       color: Colors.white,
                                       fontWeight: FontWeight.w600,
                                     ),
                                   ),
                                 ],
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
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                              icon: const Icon(Symbols.arrow_back_rounded, color: Colors.white),
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
                              icon: const Icon(Symbols.more_vert_rounded, color: Colors.white),
                            ),
                            IconButton(
                              tooltip: l.t('player.tooltip.settings'),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: widget.onSettingsPressed,
                              icon: const Icon(Symbols.settings_rounded, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Center controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: l.t('player.tooltip.rewind10Seconds'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: () => onSeekRelative(const Duration(seconds: -10)),
                            icon: const Icon(Symbols.replay_10_rounded, color: Colors.white, size: 34),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            tooltip: playing ? l.t('player.tooltip.pause') : l.t('player.tooltip.play'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
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
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: () => onSeekRelative(const Duration(seconds: 10)),
                            icon: const Icon(Symbols.forward_10_rounded, color: Colors.white, size: 34),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Bottom progress
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 6, bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              '${_fmt(position)} / ${_fmt(duration)}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: l.t('player.tooltip.miniPlayer'),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: widget.onMiniToggle,
                              icon: const Icon(Symbols.picture_in_picture_rounded, color: Colors.white),
                            ),
                            IconButton(
                              tooltip: isFullscreen
                                  ? l.t('player.tooltip.exitFullscreen')
                                  : l.t('player.tooltip.fullscreen'),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: onFullscreen,
                              icon: Icon(
                                isFullscreen ? Symbols.fullscreen_exit_rounded : Symbols.fullscreen_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PlayerProgressBar(
                        value: progress,
                        bufferedValue: bufferProgress,
                        onChange: (v) async {
                          final clamped = v.clamp(0.0, 1.0);
                          final targetMs = (duration.inMilliseconds * clamped).round();
                          await onScrubTo(Duration(milliseconds: targetMs));
                        },
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _MiniPlayerOverlay extends StatefulWidget {
  const _MiniPlayerOverlay({
    required this.controller,
    required this.onTap,
    required this.onClose,
  });

  final VideoPlayerController? controller;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_MiniPlayerOverlay> createState() => _MiniPlayerOverlayState();
}

class _MiniPlayerOverlayState extends State<_MiniPlayerOverlay> {
  Offset _offset = const Offset(16, 16);
  bool _isDragging = false;

  Duration _snapDuration = const Duration(milliseconds: 380);

  Offset _snapToNearestCorner({
    required Size screenSize,
    required double miniWidth,
    required double miniHeight,
    required Offset current,
  }) {
    const edgeInset = 8.0;
    final minRight = edgeInset;
    final maxRight = screenSize.width - miniWidth - edgeInset;
    final minBottom = edgeInset;
    final maxBottom = screenSize.height - miniHeight - edgeInset;

    final corners = <Offset>[
      Offset(minRight, minBottom), // bottom-right
      Offset(maxRight, minBottom), // bottom-left
      Offset(minRight, maxBottom), // top-right
      Offset(maxRight, maxBottom), // top-left
    ];

    double bestDist = double.infinity;
    Offset best = corners.first;
    for (final c in corners) {
      final dx = current.dx - c.dx;
      final dy = current.dy - c.dy;
      final dist = dx * dx + dy * dy;
      if (dist < bestDist) {
        bestDist = dist;
        best = c;
      }
    }
    return best;
  }

  Offset _clampToSide({
    required Size screenSize,
    required double miniWidth,
    required double miniHeight,
    required Offset candidate,
  }) {
    const edgeInset = 8.0;
    final minRight = edgeInset;
    final maxRight = screenSize.width - miniWidth - edgeInset;
    final minBottom = edgeInset;
    final maxBottom = screenSize.height - miniHeight - edgeInset;

    // Split line: right coordinate vs the center of the screen.
    final midRight = (minRight + maxRight) / 2;
    final midBottom = (minBottom + maxBottom) / 2;

    final isRightSide = candidate.dx <= midRight;
    final isBottomSide = candidate.dy <= midBottom;

    final clampedDx = isRightSide
        ? candidate.dx.clamp(minRight, midRight)
        : candidate.dx.clamp(midRight, maxRight);
    final clampedDy = isBottomSide
        ? candidate.dy.clamp(minBottom, midBottom)
        : candidate.dy.clamp(midBottom, maxBottom);

    return Offset(clampedDx, clampedDy);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final initialized = c?.value.isInitialized ?? false;

    final size = MediaQuery.of(context).size;
    final width = size.width * 0.5;
    final height = width * 9 / 16 + 40;

    final snap = _snapToNearestCorner(
      screenSize: size,
      miniWidth: width,
      miniHeight: height,
      current: _offset,
    );

    final widgetChild = GestureDetector(
      onPanStart: (_) {
        setState(() => _isDragging = true);
      },
      onPanUpdate: (details) {
        final candidate = Offset(
          (_offset.dx - details.delta.dx),
          (_offset.dy - details.delta.dy),
        );

        setState(() {
          _offset = _clampToSide(
            screenSize: size,
            miniWidth: width,
            miniHeight: height,
            candidate: candidate,
          );
        });
      },
      onPanEnd: (_) {
        setState(() {
          _isDragging = false;
          // Snap to nearest corner (YouTube-like).
          _offset = snap;
        });
      },
      onPanCancel: () {
        setState(() {
          _isDragging = false;
          _offset = snap;
        });
      },
      onTap: widget.onTap,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: initialized && c != null
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: c.value.size.width,
                            height: c.value.size.height,
                            child: VideoPlayer(c),
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                ),
              ),
              Container(
                color: Colors.black87,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Mini player',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Symbols.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (_isDragging) {
      return Positioned(
        right: _offset.dx,
        bottom: _offset.dy,
        child: widgetChild,
      );
    }

    return AnimatedPositioned(
      duration: _snapDuration,
      curve: Curves.easeOutCubic,
      right: snap.dx,
      bottom: snap.dy,
      child: widgetChild,
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
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
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          LinearProgressIndicator(
            value: buffered.clamp(0.0, 1.0),
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white38),
            minHeight: 3,
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: Colors.red,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.red,
              overlayColor: Colors.red.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: v.clamp(0.0, 1.0),
              onChanged: onChange,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataPanel extends StatelessWidget {
  const _MetadataPanel({
    required this.video,
    required this.liked,
    required this.disliked,
    required this.subscribed,
    required this.likesCount,
    required this.qualityLabel,
    required this.onLikeToggle,
    required this.onDislikeToggle,
    required this.onSubscribeToggle,
    required this.onShare,
    required this.onDownload,
    required this.onSave,
  });

  final VideoItem video;
  final bool liked;
  final bool disliked;
  final bool subscribed;
  final int likesCount;
  final String qualityLabel;
  final VoidCallback onLikeToggle;
  final VoidCallback onDislikeToggle;
  final VoidCallback onSubscribeToggle;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      children: [
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '${video.viewsText} • ${video.publishedText}'.trim(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quality: $qualityLabel',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFEEEEEE),
              child: Icon(Symbols.person_rounded, color: Colors.black54),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                video.channelName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: subscribed ? Colors.grey[800] : Colors.red,
              ),
              onPressed: onSubscribeToggle,
              child: Text(
                AppLocalizations.of(context).t(
                  subscribed ? 'shorts.subscribed' : 'shorts.subscribe',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _ActionPill(
                icon: liked ? Symbols.thumb_up_rounded : Symbols.thumb_up_rounded,
                label: likesCount.toString(),
                active: liked,
                onTap: onLikeToggle,
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: disliked ? Symbols.thumb_down_rounded : Symbols.thumb_down_rounded,
                label: AppLocalizations.of(context).t('player.action.dislike'),
                active: disliked,
                onTap: onDislikeToggle,
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: Symbols.reply_rounded,
                label: AppLocalizations.of(context).t('player.action.share'),
                onTap: onShare,
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: Symbols.download_rounded,
                label: AppLocalizations.of(context).t('player.action.download'),
                onTap: onDownload,
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: Symbols.playlist_add_rounded,
                label: AppLocalizations.of(context).t('player.action.save'),
                onTap: onSave,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Material(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white10
              : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              AppLocalizations.of(context).t('player.descriptionStub'),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          AppLocalizations.of(context).t('player.noRecommendations'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
        ),
        const SizedBox(height: 18),
        const _CommentsSection(),
        const SizedBox(height: 18),
        const _RecommendationsSection(),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF2F2F2);
    final bgActive =
        isDark ? const Color(0xFF3A3A3A) : Colors.white.withOpacity(0.95);
    final fgInactive = isDark ? Colors.white.withOpacity(0.85) : Colors.black87;
    final fgActive = active
        ? (isDark
            ? theme.colorScheme.primary.withOpacity(0.95)
            : theme.colorScheme.primary)
        : fgInactive;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? bgActive : bg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: fgActive,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: fgActive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context).t('player.comments'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              '• 123',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFDDDDDD),
                  child: Icon(Symbols.person_rounded, size: 16, color: Colors.black54),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User $i • 2 hours ago',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Great video!',
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Symbols.thumb_up_rounded,
                              size: 14, color: Colors.black54),
                          SizedBox(width: 4),
                          Text('24', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RecommendationsSection extends StatelessWidget {
  const _RecommendationsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).t('player.upNext'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            return Row(
              children: [
                Container(
                  width: 120,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Symbols.play_arrow_rounded, color: Colors.black54),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended video #$i',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Channel name • 123K views • 3 days ago',
                        style:
                            TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

String _fmt(Duration d) {
  final totalSeconds = d.inSeconds;
  final s = totalSeconds % 60;
  final m = (totalSeconds ~/ 60) % 60;
  final h = totalSeconds ~/ 3600;
  if (h > 0) {
    return '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString()}:${s.toString().padLeft(2, '0')}';
}

