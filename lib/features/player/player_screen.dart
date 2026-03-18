import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../l10n/app_localizations.dart';

import '../../data/video_item.dart';

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
  bool _liked = false;
  bool _disliked = false;
  bool _subscribed = false;
  int _likesCount = 0;
  String _qualityLabel = 'Auto';
  Timer? _hideTimer;
  Duration _lastPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _likesCount = 100 + math.Random().nextInt(900);
    widget.controller.addListener(_onTick);
    WakelockPlus.enable();
    _scheduleHide();
  }

  void _onTick() {
    final c = widget.controller;
    final pos = c.value.position;
    if (pos != _lastPosition && mounted) {
      _lastPosition = pos;
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    widget.controller.removeListener(_onTick);
    WakelockPlus.disable();
    _exitFullscreenIfNeeded();
    super.dispose();
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
                    onBack: () => Navigator.of(context).maybePop(),
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
                    onMiniToggle: () => widget.onEnterMini(),
                  ),
                if (!_isFullscreen)
                  Expanded(
                child: _MetadataPanel(
                  video: widget.video,
                  liked: _liked,
                  disliked: _disliked,
                  subscribed: _subscribed,
                  likesCount: _likesCount,
                  qualityLabel: _qualityLabel,
                  onLikeToggle: () {
                    setState(() {
                      if (_liked) {
                        _liked = false;
                        if (_likesCount > 0) _likesCount -= 1;
                      } else {
                        _liked = true;
                        _likesCount += 1;
                        if (_disliked) {
                          _disliked = false;
                        }
                      }
                    });
                  },
                  onDislikeToggle: () {
                    setState(() {
                      _disliked = !_disliked;
                      if (_disliked && _liked) {
                        _liked = false;
                        if (_likesCount > 0) _likesCount -= 1;
                      }
                    });
                  },
                  onSubscribeToggle: () {
                    setState(() => _subscribed = !_subscribed);
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

    return scaffold;
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
                      ? const Icon(Icons.check, color: Colors.red)
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
              leading: const Icon(Icons.speed),
              title: Text(AppLocalizations.of(ctx).t('player.settings.playback')),
              subtitle: Text(AppLocalizations.of(ctx).t('player.settings.playbackSubtitle')),
              onTap: () {
                Navigator.pop(ctx);
                _showSpeedQualitySheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.closed_caption),
              title: Text(AppLocalizations.of(ctx).t('player.settings.captions')),
              subtitle: Text(AppLocalizations.of(ctx).t('player.settings.captionsSubtitle')),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
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
                leading: const Icon(Icons.link),
                title: Text(AppLocalizations.of(ctx).t('player.sheet.copyLink')),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).t('player.sheet.linkCopied'))),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat),
                title: Text(AppLocalizations.of(ctx).t('player.sheet.shareToMessages')),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.email),
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
              const ListTile(
                leading: Icon(Icons.high_quality),
                title: Text('Quality'),
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
                      SnackBar(content: Text('Saved to $name')),
                    );
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add),
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
    if (initialized && c != null) {
      content = Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      );
    } else {
      content = const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
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
                                   Icon(Icons.replay_10,
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
                                   Icon(Icons.forward_10,
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
                              tooltip: 'Back',
                              onPressed: onBack,
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Playback speed / quality',
                              onPressed: widget.onSpeedPressed,
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                            ),
                            IconButton(
                              tooltip: 'Settings',
                              onPressed: widget.onSettingsPressed,
                              icon: const Icon(Icons.settings_outlined, color: Colors.white),
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
                            tooltip: 'Rewind 10 seconds',
                            onPressed: () => onSeekRelative(const Duration(seconds: -10)),
                            icon: const Icon(Icons.replay_10, color: Colors.white, size: 34),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            tooltip: playing ? 'Pause' : 'Play',
                            onPressed: onPlayPause,
                            icon: Icon(
                              playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: Colors.white,
                              size: 54,
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            tooltip: 'Forward 10 seconds',
                            onPressed: () => onSeekRelative(const Duration(seconds: 10)),
                            icon: const Icon(Icons.forward_10, color: Colors.white, size: 34),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Bottom progress
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 6, bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              '${_fmt(position)} / ${_fmt(duration)}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Mini player',
                              onPressed: widget.onMiniToggle,
                              icon: const Icon(Icons.picture_in_picture, color: Colors.white),
                            ),
                            IconButton(
                              tooltip: isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
                              onPressed: onFullscreen,
                              icon: Icon(
                                isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _ProgressBar(
                        value: progress,
                        bufferedValue: bufferProgress,
                        onChange: (v) async {
                          final clamped = v.clamp(0.0, 1.0);
                          final targetMs = (duration.inMilliseconds * clamped).round();
                          await onScrubTo(Duration(milliseconds: targetMs));
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final initialized = c?.value.isInitialized ?? false;

    final size = MediaQuery.of(context).size;
    final width = size.width * 0.5;
    final height = width * 9 / 16 + 40;

    return Positioned(
      right: _offset.dx,
      bottom: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset = Offset(
              (_offset.dx - details.delta.dx).clamp(8, size.width - width - 8),
              (_offset.dy - details.delta.dy).clamp(8, size.height - height - 8),
            );
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
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
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
              child: Icon(Icons.person, color: Colors.black54),
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
                icon: liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                label: likesCount.toString(),
                active: liked,
                onTap: onLikeToggle,
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: disliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                label: AppLocalizations.of(context).t('player.action.dislike'),
                active: disliked,
                onTap: onDislikeToggle,
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: Icons.reply_outlined,
                label: AppLocalizations.of(context).t('player.action.share'),
                onTap: onShare,
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: Icons.download_outlined,
                label: AppLocalizations.of(context).t('player.action.download'),
                onTap: onDownload,
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: Icons.playlist_add_outlined,
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
                  child: Icon(Icons.person, size: 16, color: Colors.black54),
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
                          Icon(Icons.thumb_up_alt_outlined,
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
                  child: const Icon(Icons.play_arrow, color: Colors.black54),
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

