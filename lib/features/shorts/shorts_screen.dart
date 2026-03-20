import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/app_localizations.dart';
import '../../data/short_item.dart';
import 'shorts_comments_sheet.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({
    super.key,
    required this.shorts,
    required this.onOpenShort,
  });

  final List<ShortItem> shorts;
  final Future<void> Function(ShortItem) onOpenShort;

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  late final PageController _pageController;
  late final List<ShortItem> _items;
  VideoPlayerController? _videoController;
  int _currentIndex = 0;
  bool _isPlaying = false;

  late final List<int> _likesCounts;
  late final List<int> _commentCounts;
  late final List<bool> _likedStates;
  late final List<bool> _dislikedStates;
  late final List<bool> _subscribedStates;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Перемешиваем шортсы, чтобы порядок был “рандомным”.
    _items = List<ShortItem>.from(widget.shorts)..shuffle(math.Random());

    _likesCounts =
        List<int>.generate(_items.length, (i) => _parseCompactLikes(_items[i].likesText));
    _commentCounts = List<int>.generate(_items.length, (i) => 120 + i * 7);
    _likedStates = List<bool>.filled(_items.length, false);
    _dislikedStates = List<bool>.filled(_items.length, false);
    _subscribedStates = List<bool>.filled(_items.length, false);

    _loadVideoForIndex(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadVideoForIndex(int index) async {
    if (index < 0 || index >= _items.length) return;

    _videoController?.dispose();
    final item = _items[index];

    final controller =
        VideoPlayerController.networkUrl(Uri.parse(item.playbackUrl));
    _videoController = controller;
    setState(() {
      _isPlaying = false;
    });

    await controller.initialize();
    await controller.play();
    setState(() {
      _isPlaying = true;
    });
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

  List<ShortsComment> _demoCommentsFor(int index) {
    return [
      ShortsComment(
        authorHandle: '@pmx2n',
        authorAvatarUrl: null,
        text: 'Отличное исполнение! Жду ещё таких шортсов.',
        timeAgo: '1 г. назад',
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
        text: 'Супер, подписался на канал 👍',
        timeAgo: '2 мес. назад',
        likeCount: 234,
        replyCount: 5,
      ),
      ShortsComment(
        authorHandle: '@music_fan',
        authorAvatarUrl: null,
        text: 'Как называется эта композиция?',
        timeAgo: '1 нед. назад',
        likeCount: 89,
        replyCount: 12,
      ),
    ];
  }

  void _openCommentsSheet(int index) {
    final comments = _demoCommentsFor(index);
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _items.length,
        onPageChanged: (index) {
          _currentIndex = index;
          _loadVideoForIndex(index);
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
            label: isCurrent ? (_isPlaying ? 'Pause short' : 'Play short') : 'Short',
            onTap: () {
              _togglePlayPause();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayPause,
              onDoubleTap: () => widget.onOpenShort(s),
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
                        : Image.network(
                            s.thumbnailUrl,
                            fit: BoxFit.cover,
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
    );
  }
}

