import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../data/video_item.dart';
import '../../data/short_item.dart';
import '../../data/short_store.dart';
import '../../data/video_store.dart';
import '../player/player_screen.dart';
import '../shorts/shorts_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/video_list_item.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.onThemeChanged,
    required this.themeSliderValue,
    required this.locale,
    required this.onLocaleChanged,
  });

  final void Function(double) onThemeChanged;
  final double themeSliderValue;
  final Locale locale;
  final void Function(Locale) onLocaleChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  VideoItem? _activeItem;
  VideoPlayerController? _playerController;
  bool _miniActive = false;

  Future<void> _openVideo(VideoItem item) async {
    _activeItem = item;
    _miniActive = false;

    _playerController?.dispose();
    _playerController =
        VideoPlayerController.networkUrl(Uri.parse(item.playbackUrl));
    await _playerController!.initialize();
    await _playerController!.play();

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          video: item,
          controller: _playerController!,
          onEnterMini: () {
            _miniActive = true;
            Navigator.of(context).pop();
            setState(() {});
          },
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          value: widget.themeSliderValue,
          onThemeChanged: widget.onThemeChanged,
          locale: widget.locale,
          onLocaleChanged: widget.onLocaleChanged,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: [
              HomeScreen(
                onOpenVideo: _openVideo,
                onProfile: _openSettings,
              ),
              ShortsScreen(
                shorts: demoShorts,
                onOpenShort: (ShortItem s) => _openVideo(s.toVideoItem()),
              ),
              const _PublishScreen(),
              _SubscriptionsScreen(onOpenVideo: _openVideo),
              _LibraryScreen(onOpenVideo: _openVideo),
            ],
          ),
          if (_miniActive && _playerController != null && _activeItem != null)
            _MiniPlayerOverlay(
              controller: _playerController!,
              title: _activeItem!.title,
              onTap: () async {
                _miniActive = false;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                      video: _activeItem!,
                      controller: _playerController!,
                      onEnterMini: () {
                        _miniActive = true;
                        Navigator.of(context).pop();
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
              onClose: () {
                _miniActive = false;
                _playerController?.dispose();
                _playerController = null;
                _activeItem = null;
                setState(() {});
              },
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Symbols.home_rounded),
            selectedIcon: Icon(Symbols.home_rounded),
            label: l.t('nav.home'),
          ),
          NavigationDestination(
            icon: Icon(Symbols.play_arrow_rounded),
            selectedIcon: Icon(Symbols.play_arrow_rounded),
            label: l.t('nav.shorts'),
          ),
          NavigationDestination(
            icon: Icon(Symbols.add_circle_rounded),
            selectedIcon: Icon(Symbols.add_circle_rounded),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Symbols.subscriptions_rounded),
            selectedIcon: Icon(Symbols.subscriptions_rounded),
            label: l.t('nav.subscriptions'),
          ),
          NavigationDestination(
            icon: Icon(Symbols.video_library_rounded),
            selectedIcon: Icon(Symbols.video_library_rounded),
            label: l.t('nav.you'),
          ),
        ],
      ),
    );
  }
}

class _PublishScreen extends StatelessWidget {
  const _PublishScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Create',
                style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _CreateTile(
                  icon: Symbols.upload_file_rounded,
                  title: 'Upload videos',
                  subtitle: 'Upload from your device',
                  onTap: () {
                    _showUploadOptions(context);
                  },
                ),
                _CreateTile(
                  icon: Symbols.live_tv_rounded,
                  title: 'Go live',
                  subtitle: 'Stream in real time',
                  onTap: () {
                    _showGoLiveOptions(context);
                  },
                ),
                _CreateTile(
                  icon: Symbols.videocam_rounded,
                  title: 'Create a Short',
                  subtitle: 'Create short videos',
                  onTap: () {
                    _showShortOptions(context);
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.folder_open_rounded),
              title: const Text('Choose from device'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Choose a video to upload')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Symbols.cloud_upload_rounded),
              title: const Text('Upload from link'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Paste video link')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGoLiveOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.videocam_rounded),
              title: const Text('Stream with camera'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Starting stream…')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Symbols.screen_share_rounded),
              title: const Text('Stream screen'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Select screen to share')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShortOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.videocam_rounded),
              title: const Text('Record a Short'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening camera…')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Symbols.photo_library_rounded),
              title: const Text('Create from photos'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Choose photos')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Symbols.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _SubscriptionsScreen extends StatelessWidget {
  const _SubscriptionsScreen({required this.onOpenVideo});

  final Future<void> Function(VideoItem) onOpenVideo;

  void _showManageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Manage subscriptions'),
              leading: const Icon(Symbols.settings_rounded),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              title: const Text('Turn on all notifications'),
              leading: const Icon(Symbols.notifications_rounded),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final channels = <_ChannelEntry>[
      const _ChannelEntry(name: 'Flutter Academy', newCount: 2, latest: 'Getting started with Flutter'),
      const _ChannelEntry(name: 'DIY & Crafts', newCount: 1, latest: 'Easy craft ideas'),
      const _ChannelEntry(name: 'Cooking with Kids', newCount: 0, latest: 'Pancakes recipe'),
      const _ChannelEntry(name: 'Funny Animals', newCount: 3, latest: 'Best of the week'),
      const _ChannelEntry(name: 'Learning Channel', newCount: 0, latest: 'Math tips'),
    ];
    // Видео от подписанных каналов — для демо берём общую ленту (как на главной)
    final subscribedChannelNames = channels.map((c) => c.name.toLowerCase()).toSet();
    final feedVideos = demoFeed.where((v) {
      return subscribedChannelNames.any((name) => v.channelName.toLowerCase().contains(name) || name.contains(v.channelName.toLowerCase()));
    }).toList();
    final videos = feedVideos.isEmpty ? demoFeed : feedVideos;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Subscriptions',
                    style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showManageSheet(context),
                  child: const Text('Manage'),
                ),
              ],
            ),
          ),
          // Строка каналов с аватарками
          SizedBox(
            height: 112,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final ch = channels[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _ChannelFeedScreen(
                            channelName: ch.name,
                            videos: demoFeed,
                            onOpenVideo: onOpenVideo,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              child: Text(
                                ch.name.characters.first.toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                            if (ch.newCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${ch.newCount}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 64,
                          child: Text(
                            ch.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Список видео карточками (как на главной)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: videos.length,
              itemBuilder: (context, i) {
                final item = videos[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: VideoListItem(
                    video: item,
                    onTap: () => onOpenVideo(item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelEntry {
  const _ChannelEntry({
    required this.name,
    required this.newCount,
    required this.latest,
  });
  final String name;
  final int newCount;
  final String latest;
}

class _ChannelFeedScreen extends StatelessWidget {
  const _ChannelFeedScreen({
    required this.channelName,
    required this.videos,
    required this.onOpenVideo,
  });

  final String channelName;
  final List<VideoItem> videos;
  final Future<void> Function(VideoItem) onOpenVideo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(channelName),
        actions: [
          IconButton(icon: const Icon(Symbols.notifications_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Symbols.search_rounded), onPressed: () {}),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: videos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final item = videos[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: VideoListItem(
              video: item,
              onTap: () => onOpenVideo(item),
            ),
          );
        },
      ),
    );
  }
}

class _LibraryScreen extends StatelessWidget {
  const _LibraryScreen({required this.onOpenVideo});

  final Future<void> Function(VideoItem) onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final sections = <_LibraryItem>[
      _LibraryItem(
        icon: Symbols.history_rounded,
        label: l.t('you.history'),
        description: l.t('you.historyDesc'),
      ),
      _LibraryItem(
        icon: Symbols.playlist_play_rounded,
        label: l.t('you.yourVideos'),
        description: l.t('you.yourVideosDesc'),
      ),
      _LibraryItem(
        icon: Symbols.download_rounded,
        label: l.t('you.downloads'),
        description: l.t('you.downloadsDesc'),
      ),
      _LibraryItem(
        icon: Symbols.video_library_rounded,
        label: l.t('you.playlists'),
        description: l.t('you.playlistsDesc'),
      ),
    ];

    const userAvatar = Icon(Symbols.person_rounded, size: 44);
    const userName = 'Sany';
    const userHandle = '@sanyyyvfx';
    const userExtra = 'Private profile';

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: userAvatar,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userHandle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userExtra,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.t('you.editProfile'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Edit profile (demo).'),
                        ),
                      );
                    },
                    icon: const Icon(Symbols.settings_rounded),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = sections[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(item.icon,
                          color: theme.colorScheme.onSurface),
                      title: Text(item.label),
                      subtitle: Text(item.description),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _LibrarySectionScreen(
                              title: item.label,
                              icon: item.icon,
                              videos: demoFeed,
                              onOpenVideo: onOpenVideo,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                childCount: sections.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySectionScreen extends StatelessWidget {
  const _LibrarySectionScreen({
    required this.title,
    required this.icon,
    required this.videos,
    required this.onOpenVideo,
  });

  final String title;
  final IconData icon;
  final List<VideoItem> videos;
  final Future<void> Function(VideoItem) onOpenVideo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Symbols.search_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Symbols.more_vert_rounded), onPressed: () {}),
        ],
      ),
      body: videos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No videos here yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: videos.length,
separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final item = videos[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: VideoListItem(
                video: item,
                onTap: () => onOpenVideo(item),
              ),
            );
          },
        ),
    );
  }
}

class _LibraryItem {
  const _LibraryItem({
    required this.icon,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String description;
}

class _MiniPlayerOverlay extends StatefulWidget {
  const _MiniPlayerOverlay({
    required this.controller,
    required this.title,
    required this.onTap,
    required this.onClose,
  });

  final VideoPlayerController controller;
  final String title;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_MiniPlayerOverlay> createState() => _MiniPlayerOverlayState();
}

class _MiniPlayerOverlayState extends State<_MiniPlayerOverlay> {
  Offset _offset = const Offset(16, 16);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVideoTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVideoTick);
    super.dispose();
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    final c = widget.controller;
    if (!c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  void _seekFromLocalX(double localX, double barWidth) {
    final c = widget.controller;
    if (!c.value.isInitialized || barWidth <= 0) return;
    final d = c.value.duration;
    if (d.inMilliseconds <= 0) return;
    final f = (localX / barWidth).clamp(0.0, 1.0);
    final ms = (d.inMilliseconds * f).round().clamp(0, d.inMilliseconds);
    c.seekTo(Duration(milliseconds: ms));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width * 0.5;
    const progressH = 4.0;
    const titleBarH = 44.0;
    final videoH = width * 9 / 16;
    final totalHeight = videoH + progressH + titleBarH;
    final initialized = widget.controller.value.isInitialized;
    final v = widget.controller.value;
    final duration = v.duration;
    final position = v.position;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final playing = v.isPlaying;

    return Positioned(
      right: _offset.dx,
      bottom: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset = Offset(
              (_offset.dx - details.delta.dx)
                  .clamp(8, size.width - width - 8),
              (_offset.dy - details.delta.dy).clamp(
                8,
                size.height - totalHeight - 8,
              ),
            );
          });
        },
        behavior: HitTestBehavior.deferToChild,
        child: Material(
          elevation: 12,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: videoH,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.black,
                        child: initialized
                            ? FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: v.size.width,
                                  height: v.size.height,
                                  child: VideoPlayer(widget.controller),
                                ),
                              )
                            : const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onTap,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      if (initialized && !playing)
                        Center(
                          child: Material(
                            color: Colors.black45,
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: _togglePlayPause,
                              icon: const Icon(
                                Symbols.play_arrow_rounded,
                                color: Colors.white,
                                size: 36,
                                fill: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Шкала прогресса (тап / перетаскивание для перемотки)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final barW = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) =>
                          _seekFromLocalX(d.localPosition.dx, barW),
                      onHorizontalDragUpdate: (d) =>
                          _seekFromLocalX(d.localPosition.dx, barW),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: SizedBox(
                          height: progressH,
                          width: barW,
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: progressH,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF0000),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  height: titleBarH,
                  color: const Color(0xFF1A1A1A),
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: _togglePlayPause,
                        icon: Icon(
                          playing ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                          fill: 1,
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onTap,
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: widget.onClose,
                        icon: const Icon(
                          Symbols.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
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
