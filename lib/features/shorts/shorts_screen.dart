import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/app_localizations.dart';
import '../../data/short_item.dart';
import '../../data/short_repository.dart';
import 'shorts_comments_sheet.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({
    super.key,
    required this.isActive,
  });

  /// Вкладка Shorts выбрана в [IndexedStack]. Иначе не грузим видео (иначе звук на фоне).
  final bool isActive;

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  late final PageController _pageController;
  List<ShortItem> _items = [];
  VideoPlayerController? _videoController;
  VideoPlayerController? _preloadController;
  int _preloadedIndex = -1;
  int _currentIndex = 0;
  bool _isPlaying = false;

  bool _loading = true;
  String? _error;

  List<int> _likesCounts = [];
  List<int> _commentCounts = [];
  List<bool> _likedStates = [];
  List<bool> _dislikedStates = [];
  List<bool> _subscribedStates = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadShorts();
  }

  Future<void> _loadShorts({bool force = false}) async {
    setState(() {
      _loading = true;
      if (force) _error = null;
    });
    try {
      await ShortRepository.instance.loadShorts(force: force);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _items = List<ShortItem>.from(ShortRepository.instance.cachedShorts);
        _rebuildSideState();
      });
      _currentIndex = 0;
      if (_items.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _items.isEmpty) return;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
          if (widget.isActive) {
            _loadVideoForIndex(0);
          }
        });
      } else {
        _videoController?.dispose();
        _videoController = null;
        if (mounted) setState(() => _isPlaying = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ShortRepository.instance.lastError ?? e.toString();
      });
      if (_items.isEmpty) {
        _videoController?.dispose();
        _videoController = null;
        if (mounted) setState(() => _isPlaying = false);
      }
    }
  }

  void _rebuildSideState() {
    _likesCounts = List<int>.generate(
      _items.length,
      (i) => _parseCompactLikes(_items[i].likesText),
    );
    _commentCounts = List<int>.generate(_items.length, (i) => 120 + i * 7);
    _likedStates = List<bool>.filled(_items.length, false);
    _dislikedStates = List<bool>.filled(_items.length, false);
    _subscribedStates = List<bool>.filled(_items.length, false);
  }

  @override
  void didUpdateWidget(ShortsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      if (_items.isNotEmpty) {
        _loadVideoForIndex(_currentIndex.clamp(0, _items.length - 1));
      }
    }
    if (oldWidget.isActive && !widget.isActive) {
      _videoController?.pause();
      _videoController?.dispose();
      _videoController = null;
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  // OPT7: preload BOTH next and previous
  VideoPlayerController? _preloadPrevController;
  int _preloadedPrevIndex = -1;

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    _preloadController?.dispose();
    _preloadPrevController?.dispose();
    super.dispose();
  }

  Future<void> _loadVideoForIndex(int index) async {
    if (!widget.isActive) return;
    final safeIndex = index.clamp(0, _items.length - 1);

    VideoPlayerController controller;

    // Use preloaded controller if it matches
    if (_preloadedIndex == safeIndex && _preloadController != null) {
      _videoController?.dispose();
      controller = _preloadController!;
      _videoController = controller;
      _preloadController = null;
      _preloadedIndex = -1;
    } else if (_preloadedPrevIndex == safeIndex && _preloadPrevController != null) {
      // OPT7: swap in the prev-preloaded controller
      _videoController?.dispose();
      controller = _preloadPrevController!;
      _videoController = controller;
      _preloadPrevController = null;
      _preloadedPrevIndex = -1;
    } else {
      _videoController?.dispose();
      _preloadController?.dispose();
      _preloadPrevController?.dispose();
      _preloadController = null;
      _preloadPrevController = null;
      _preloadedIndex = -1;
      _preloadedPrevIndex = -1;

      final item = _items[safeIndex];
      controller = VideoPlayerController.networkUrl(Uri.parse(item.playbackUrl));
      _videoController = controller;
      if (mounted) setState(() => _isPlaying = false);

      await controller.initialize();
      if (!mounted || !widget.isActive || _videoController != controller) {
        controller.dispose();
        return;
      }
    }

    await controller.setLooping(true);
    await controller.play();
    if (!mounted) return;
    setState(() => _isPlaying = true);

    // OPT7: preload both next and previous
    unawaited(_preloadForIndex(safeIndex + 1));
    unawaited(_preloadPrevForIndex(safeIndex - 1));
  }

  Future<void> _preloadForIndex(int index) async {
    if (index < 0 || index >= _items.length) return;
    if (_preloadedIndex == index) return;

    _preloadController?.dispose();
    _preloadController = null;
    _preloadedIndex = index;

    final item = _items[index];
    final controller = VideoPlayerController.networkUrl(Uri.parse(item.playbackUrl));
    _preloadController = controller;

    await controller.initialize();
    if (!mounted || _preloadController != controller) {
      controller.dispose();
      return;
    }
  }

  // OPT7: preload previous video
  Future<void> _preloadPrevForIndex(int index) async {
    if (index < 0 || index >= _items.length) return;
    if (_preloadedPrevIndex == index) return;

    _preloadPrevController?.dispose();
    _preloadPrevController = null;
    _preloadedPrevIndex = index;

    final item = _items[index];
    final controller = VideoPlayerController.networkUrl(Uri.parse(item.playbackUrl));
    _preloadPrevController = controller;

    await controller.initialize();
    if (!mounted || _preloadPrevController != controller) {
      controller.dispose();
      return;
    }
  }

  Future<void> _togglePlayPause() async {
    final c = _videoController;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await c.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  int _parseCompactLikes(String s) {
    final v = s.trim().toUpperCase();
    if (v.endsWith('K')) {
      final n = double.tryParse(v.replaceAll('K', '').trim()) ?? 0;
      return (n * 1000).round();
    }
    if (v.endsWith('M')) {
      final n = double.tryParse(v.replaceAll('M', '').trim()) ?? 0;
      return (n * 1000000).round();
    }
    return int.tryParse(v) ?? 0;
  }

  String _formatCompactCount(int value) {
    if (value >= 1000000) {
      final m = value / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final k = value / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return value.toString();
  }

  void _toggleLike(int index) {
    setState(() {
      if (_likedStates[index]) {
        _likedStates[index] = false;
        _likesCounts[index] = math.max(0, _likesCounts[index] - 1);
        return;
      }

      _likedStates[index] = true;
      _likesCounts[index] += 1;
      if (_dislikedStates[index]) _dislikedStates[index] = false;
    });
  }

  void _toggleDislike(int index) {
    setState(() {
      if (_dislikedStates[index]) {
        _dislikedStates[index] = false;
        return;
      }

      _dislikedStates[index] = true;
      if (_likedStates[index]) {
        _likedStates[index] = false;
        _likesCounts[index] = math.max(0, _likesCounts[index] - 1);
      }
    });
  }

  List<ShortsComment> _demoCommentsFor(int index, AppLocalizations l) {
    return [
      ShortsComment(
        authorHandle: '@pmx2n',
        authorAvatarUrl: null,
        text: l.t('shorts.demo.comment1.text'),
        timeAgo: l.t('shorts.demo.comment1.timeAgo'),
        likeCount: 1800,
        isPinned: true,
        pinnedByHandle: '@pmx2n',
        replyCount: 40,
        isVerified: true,
        creatorLiked: true,
      ),
      ShortsComment(
        authorHandle: '@user_kk',
        authorAvatarUrl: null,
        text: l.t('shorts.demo.comment2.text'),
        timeAgo: l.t('shorts.demo.comment2.timeAgo'),
        likeCount: 234,
        replyCount: 5,
      ),
      ShortsComment(
        authorHandle: '@music_fan',
        authorAvatarUrl: null,
        text: l.t('shorts.demo.comment3.text'),
        timeAgo: l.t('shorts.demo.comment3.timeAgo'),
        likeCount: 89,
        replyCount: 12,
      ),
    ];
  }

  void _openCommentsSheet(int index) {
    final l = AppLocalizations.of(context);
    final comments = _demoCommentsFor(index, l);
    showShortsCommentsSheet(
      context,
      commentCount: _commentCounts[index],
      comments: comments,
      onSendComment: (text) {
        if (!mounted) return;
        setState(() => _commentCounts[index] += 1);
      },
    );
  }

  void _shareShort(int index) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.link_rounded),
              title: Text(AppLocalizations.of(ctx).t('shorts.sheet.copyLink')),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(AppLocalizations.of(context).t('shorts.sheet.linkCopied')),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Symbols.share_rounded),
              title: Text(AppLocalizations.of(ctx).t('shorts.sheet.share')),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSubscribe(int index) {
    setState(() {
      _subscribedStates[index] = !_subscribedStates[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final topPad = MediaQuery.paddingOf(context).top;

    if (_loading && _items.isEmpty && _error == null) {
      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  l.t('shorts.feed.loading'),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.t('shorts.feed.loadError'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_error!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _loadShorts(force: true),
                    icon: const Icon(Symbols.refresh_rounded),
                    label: Text(l.t('home.feed.retry')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l.t('shorts.feed.empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
            Positioned(
              top: topPad + 4,
              right: 8,
              child: IconButton(
                tooltip: l.t('home.feed.refreshFeed'),
                onPressed: () => _loadShorts(force: true),
                icon: Icon(
                  Symbols.refresh_rounded,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _items.length,
        onPageChanged: (index) {
          _currentIndex = index;
          if (widget.isActive) {
            _loadVideoForIndex(index);
          }
        },
        itemBuilder: (context, index) {
          final s = _items[index];
          final isCurrent = index == _currentIndex;
          final controller = isCurrent ? _videoController : null;
          final initialized = controller?.value.isInitialized ?? false;
          final liked = _likedStates[index];
          final disliked = _dislikedStates[index];
          final subscribed = _subscribedStates[index];
          final likesCount = _likesCounts[index];
          final commentCount = _commentCounts[index];

          return Semantics(
            container: true,
            button: true,
            label: isCurrent
                ? (_isPlaying
                    ? l.t('shorts.semantics.pauseShort')
                    : l.t('shorts.semantics.playShort'))
                : l.t('shorts.semantics.short'),
            onTap: _togglePlayPause,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayPause,
              child: Stack(
                children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: initialized && controller != null
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: controller.value.size.width,
                              height: controller.value.size.height,
                              child: VideoPlayer(controller),
                            ),
                          )
                        : s.thumbnailUrl.trim().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: s.thumbnailUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const ColoredBox(
                                  color: Color(0xFFEEEEEE),
                                ),
                                errorWidget: (_, __, ___) => const ColoredBox(
                                  color: Color(0xFFEEEEEE),
                                ),
                              )
                            : const ColoredBox(color: Color(0xFF222222)),
                  ),
                ),
                // GUI2: top gradient so header area is always readable
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment(0, -0.4),
                          colors: [Color(0xAA000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                ),
                // GUI2: bottom gradient behind text/buttons
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment(0, 0.1),
                          colors: [Color(0xCC000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Иконка play/пауза по центру
                if (isCurrent)
                  AnimatedOpacity(
                    opacity: _isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Center(
                      child: Icon(
                        Symbols.play_circle_rounded,
                        fill: 1,
                        color: Colors.white70,
                        size: 72,
                      ),
                    ),
                  ),
                // GUI1: progress bar at very bottom using AnimatedBuilder
                if (isCurrent && controller != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (_, __) {
                        final dur = controller.value.duration.inMilliseconds;
                        final pos = controller.value.position.inMilliseconds;
                        final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
                        return LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                        );
                      },
                    ),
                  ),
                Positioned(
                  right: 16,
                  bottom: 80,
                  child: Column(
                    children: [
                      IconButton(
                        onPressed: () => _toggleLike(index),
                        icon: Icon(
                          Symbols.thumb_up_rounded,
                          color: liked ? Colors.redAccent : Colors.white70,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCompactCount(likesCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      IconButton(
                        onPressed: () => _toggleDislike(index),
                        icon: Icon(
                          Symbols.thumb_down_rounded,
                          color: disliked ? Colors.redAccent : Colors.white70,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      IconButton(
                        onPressed: () => _openCommentsSheet(index),
                        icon: const Icon(
                          Symbols.comment_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCompactCount(commentCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      IconButton(
                        onPressed: () => _shareShort(index),
                        icon: const Icon(
                          Symbols.share_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 32,
                  right: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${s.channelName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: subscribed
                              ? Colors.white10
                              : Colors.red.withValues(alpha: 0.9),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => _toggleSubscribe(index),
                        child: Text(subscribed
                            ? AppLocalizations.of(context)
                                .t('shorts.subscribed')
                            : AppLocalizations.of(context).t('shorts.subscribe')),
                      ),
                    ],
                  ),
                ),
              ],
              ),
            ),
          );
        },
      ),
          Positioned(
            top: topPad + 4,
            right: 8,
            child: IconButton(
              tooltip: l.t('home.feed.refreshFeed'),
              onPressed: () => _loadShorts(force: true),
              icon: const Icon(
                Symbols.refresh_rounded,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

