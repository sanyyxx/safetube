import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../l10n/app_localizations.dart';

import '../../data/video_item.dart';
import 'widgets/video_info_section.dart';
import 'widgets/video_player_section.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.video,
    required this.controller,
    required this.onEnterMini,
    required this.onOpenVideo,
    required this.onOpenChannel,
    this.onPrevious,
    this.onNext,
  });

  final VideoItem video;
  final VideoPlayerController controller;
  final VoidCallback onEnterMini;
  final void Function(VideoItem) onOpenVideo;
  final void Function(VideoItem) onOpenChannel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _isMini = false;
  String _qualityLabel = 'Auto';
  Timer? _hideTimer;
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
    // No _onTick listener needed — VideoPlayerSection uses AnimatedBuilder internally.
    WakelockPlus.enable();
    _scheduleHide();
    // Start playing after the first frame so the screen is visible before
    // audio begins — avoids the "sound before image" race condition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.controller.value.isPlaying) {
        widget.controller.play();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
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

    final videoSection = VideoPlayerSection(
      isFullscreen: _isFullscreen,
      initialized: isReady,
      controller: c,
      showControls: _showControls,
      onTap: _toggleControls,
      onBack: _isFullscreen ? () => _exitFullscreen() : _requestEnterMini,
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
      onPrevious: widget.onPrevious,
      onNext: widget.onNext,
    );

    // Fullscreen: video fills the whole Scaffold (landscape layout)
    if (_isFullscreen) {
      final scaffold = Scaffold(
        backgroundColor: Colors.black,
        body: videoSection,
      );
      return WillPopScope(
        onWillPop: () async {
          await _exitFullscreen();
          return false;
        },
        child: scaffold,
      );
    }

    final scaffold = Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isMini)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: videoSection,
              ),
            if (!_isFullscreen)
              Expanded(
                child: Container(
                  color: const Color(0xFF0F0F0F),
                  child: VideoInfoSection(
                    video: widget.video,
                    actions: _actions,
                    qualityLabel: _qualityLabel,
                    onOpenVideo: widget.onOpenVideo,
                    onOpenChannel: widget.onOpenChannel,
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
                        likesCount: a.liked
                            ? math.max(0, a.likesCount - 1)
                            : a.likesCount,
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
              ),
          ],
        ),
      ),
    );

    return WillPopScope(
      onWillPop: () async {
        _requestEnterMini();
        return false;
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

