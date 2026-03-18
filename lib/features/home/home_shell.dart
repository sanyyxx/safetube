import 'package:flutter/material.dart';
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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: l.t('nav.home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.play_arrow_outlined),
            selectedIcon: Icon(Icons.play_arrow),
            label: l.t('nav.shorts'),
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.subscriptions_outlined),
            selectedIcon: Icon(Icons.subscriptions),
            label: l.t('nav.subscriptions'),
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
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
                  icon: Icons.upload_file,
                  title: 'Upload videos',
                  subtitle: 'Upload from your device',
                  onTap: () {
                    _showUploadOptions(context);
                  },
                ),
                _CreateTile(
                  icon: Icons.live_tv,
                  title: 'Go live',
                  subtitle: 'Stream in real time',
                  onTap: () {
                    _showGoLiveOptions(context);
                  },
                ),
                _CreateTile(
                  icon: Icons.videocam,
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
              leading: const Icon(Icons.folder_open),
              title: const Text('Choose from device'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Choose a video to upload')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
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
              leading: const Icon(Icons.videocam),
              title: const Text('Stream with camera'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Starting stream…')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.screen_share),
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
              leading: const Icon(Icons.videocam),
              title: const Text('Record a Short'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening camera…')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
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
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SubscriptionsScreen extends StatelessWidget {
  const _SubscriptionsScreen({required this.onOpenVideo});

  final Future<void> Function(VideoItem) onOpenVideo;

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
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: const Text('Manage subscriptions'),
                              leading: const Icon(Icons.settings),
                              onTap: () => Navigator.pop(ctx),
                            ),
                            ListTile(
                              title: const Text('Turn on all notifications'),
                              leading: const Icon(Icons.notifications),
                              onTap: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Manage'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final ch = channels[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Text(
                      ch.name.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(ch.name)),
                      if (ch.newCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${ch.newCount} new',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    ch.newCount > 0 ? 'New: ${ch.latest}' : ch.latest,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
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
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: videos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
        icon: Icons.history,
        label: l.t('you.history'),
        description: l.t('you.historyDesc'),
      ),
      _LibraryItem(
        icon: Icons.playlist_play,
        label: l.t('you.yourVideos'),
        description: l.t('you.yourVideosDesc'),
      ),
      _LibraryItem(
        icon: Icons.file_download_outlined,
        label: l.t('you.downloads'),
        description: l.t('you.downloadsDesc'),
      ),
      _LibraryItem(
        icon: Icons.video_library,
        label: l.t('you.playlists'),
        description: l.t('you.playlistsDesc'),
      ),
    ];

    const userAvatar = Icon(Icons.person, size: 44);
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
                    icon: const Icon(Icons.settings_outlined),
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
                      trailing: const Icon(Icons.chevron_right),
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
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
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
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width * 0.5;
    final height = width * 9 / 16 + 40;
    final initialized = widget.controller.value.isInitialized;

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
                    child: initialized
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: widget.controller.value.size.width,
                              height: widget.controller.value.size.height,
                              child: VideoPlayer(widget.controller),
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
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
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
