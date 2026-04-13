import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/video_item.dart';
import '../../data/short_repository.dart';
import '../../data/video_repository.dart';
import '../channel/channel_screen.dart';
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
  // OPT3: track which tabs have been built (lazy tab creation)
  final Set<int> _visitedTabs = {0};

  VideoItem? _activeItem;
  VideoPlayerController? _playerController;
  bool _miniActive = false;

  // GUI8: compute prev/next from the feed
  VideoItem? _prevVideo(VideoItem current) {
    final feed = VideoRepository.instance.cachedFeed;
    final idx = feed.indexWhere((v) => v.id == current.id || v.playbackUrl == current.playbackUrl);
    if (idx <= 0) return null;
    return feed[idx - 1];
  }

  VideoItem? _nextVideo(VideoItem current) {
    final feed = VideoRepository.instance.cachedFeed;
    final idx = feed.indexWhere((v) => v.id == current.id || v.playbackUrl == current.playbackUrl);
    if (idx < 0 || idx >= feed.length - 1) return null;
    return feed[idx + 1];
  }

  Future<void> _openVideo(VideoItem item) async {
    _activeItem = item;
    _miniActive = false;

    _playerController?.dispose();
    _playerController =
        VideoPlayerController.networkUrl(Uri.parse(item.playbackUrl));

    // Initialize but do NOT play yet — PlayerScreen will call play()
    // after it is rendered so the screen is visible before audio starts.
    await _playerController!.initialize();

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          video: item,
          controller: _playerController!,
          onOpenVideo: (v) {
            Navigator.of(context).pop();
            _openVideo(v);
          },
          onOpenChannel: _openChannelFromVideo,
          onEnterMini: () {
            _miniActive = true;
            Navigator.of(context).pop();
            setState(() {});
          },
          onPrevious: _prevVideo(item) != null ? () {
            Navigator.of(context).pop();
            _openVideo(_prevVideo(item)!);
          } : null,
          onNext: _nextVideo(item) != null ? () {
            Navigator.of(context).pop();
            _openVideo(_nextVideo(item)!);
          } : null,
        ),
      ),
    );

    // If we closed the player without switching to mini-mode, clean up the
    // controller so we don't keep wake locks/resources around.
    if (!mounted) return;
    if (!_miniActive) {
      _playerController?.dispose();
      _playerController = null;
      _activeItem = null;
    }
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

  Future<void> _openChannelFromVideo(VideoItem item) async {
    final slug = item.channelSlug?.trim();
    if (slug == null || slug.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('channel.unavailable'))),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChannelScreen(
          channelSlug: slug,
          channelName: item.channelName,
          onOpenVideo: _openVideo,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    VideoRepository.instance.loadFeed().then((_) {
      if (mounted) setState(() {});
    });
    ShortRepository.instance.loadShorts().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _playerController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(
        children: [
          // OPT3: lazy tab construction — only build a tab on first visit
          IndexedStack(
            index: _index,
            children: [
              if (_visitedTabs.contains(0))
                HomeScreen(
                  onOpenVideo: _openVideo,
                  onOpenChannel: _openChannelFromVideo,
                  onProfile: _openSettings,
                )
              else
                const SizedBox.shrink(),
              if (_visitedTabs.contains(1))
                ShortsScreen(isActive: _index == 1)
              else
                const SizedBox.shrink(),
              if (_visitedTabs.contains(2))
                const _PublishScreen()
              else
                const SizedBox.shrink(),
              if (_visitedTabs.contains(3))
                _SubscriptionsScreen(onOpenVideo: _openVideo)
              else
                const SizedBox.shrink(),
              if (_visitedTabs.contains(4))
                _LibraryScreen(onOpenVideo: _openVideo)
              else
                const SizedBox.shrink(),
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
                      onOpenVideo: (v) {
                        Navigator.of(context).pop();
                        _openVideo(v);
                      },
                      onOpenChannel: _openChannelFromVideo,
                      onEnterMini: () {
                        _miniActive = true;
                        Navigator.of(context).pop();
                        setState(() {});
                      },
                    ),
                  ),
                );

                // Same cleanup rule as in _openVideo: if user exited the player
                // without going back to mini-mode, fully release controller.
                if (!mounted) return;
                if (!_miniActive) {
                  _playerController?.dispose();
                  _playerController = null;
                  _activeItem = null;
                }
              },
              onClose: () {
                _miniActive = false;
                _playerController?.dispose();
                _playerController = null;
                _activeItem = null;
                WakelockPlus.disable();
                setState(() {});
              },
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visitedTabs.add(i); // OPT3: mark tab as visited so it gets built
        }),
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
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                l.t('publish.createTitle'),
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
                  title: l.t('publish.uploadVideosTitle'),
                  subtitle: l.t('publish.uploadVideosSubtitle'),
                  onTap: () {
                    _showUploadOptions(context);
                  },
                ),
                _CreateTile(
                  icon: Symbols.live_tv_rounded,
                  title: l.t('publish.goLiveTitle'),
                  subtitle: l.t('publish.goLiveSubtitle'),
                  onTap: () {
                    _showGoLiveOptions(context);
                  },
                ),
                _CreateTile(
                  icon: Symbols.videocam_rounded,
                  title: l.t('publish.createShortTitle'),
                  subtitle: l.t('publish.createShortSubtitle'),
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
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.folder_open_rounded),
              title: Text(l.t('publish.options.chooseFromDevice')),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.t('publish.options.chooseVideoToUpload'))),
                );
              },
            ),
            ListTile(
              leading: const Icon(Symbols.cloud_upload_rounded),
              title: Text(l.t('publish.options.uploadFromLink')),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.t('publish.options.pasteVideoLink'))),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGoLiveOptions(BuildContext context) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.videocam_rounded),
              title: Text(l.t('publish.options.streamWithCamera')),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.t('publish.options.startingStream'))),
                );
              },
            ),
            ListTile(
              leading: const Icon(Symbols.screen_share_rounded),
              title: Text(l.t('publish.options.streamScreen')),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.t('publish.options.selectScreenToShare'))),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShortOptions(BuildContext context) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.videocam_rounded),
              title: Text(l.t('publish.options.recordShort')),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.t('publish.options.openingCamera'))),
                );
              },
            ),
            ListTile(
              leading: const Icon(Symbols.photo_library_rounded),
              title: Text(l.t('publish.options.createFromPhotos')),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.t('publish.options.choosePhotos'))),
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
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l.t('subscriptions.manageSubscriptions')),
              leading: const Icon(Symbols.settings_rounded),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              title: Text(l.t('subscriptions.turnOnAllNotifications')),
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
    final l = AppLocalizations.of(context);
    final channels = <_ChannelEntry>[
      _ChannelEntry(
        matchName: 'Flutter Academy',
        displayName: l.t('subscriptions.channel.flutterAcademy'),
        newCount: 2,
        latest: 'Getting started with Flutter',
      ),
      _ChannelEntry(
        matchName: 'DIY & Crafts',
        displayName: l.t('subscriptions.channel.diyCrafts'),
        newCount: 1,
        latest: 'Easy craft ideas',
      ),
      _ChannelEntry(
        matchName: 'Cooking with Kids',
        displayName: l.t('subscriptions.channel.cookingWithKids'),
        newCount: 0,
        latest: 'Pancakes recipe',
      ),
      _ChannelEntry(
        matchName: 'Funny Animals',
        displayName: l.t('subscriptions.channel.funnyAnimals'),
        newCount: 3,
        latest: 'Best of the week',
      ),
      _ChannelEntry(
        matchName: 'Learning Channel',
        displayName: l.t('subscriptions.channel.learningChannel'),
        newCount: 0,
        latest: 'Math tips',
      ),
    ];
    // Видео от подписанных каналов — для демо берём общую ленту (как на главной)
    final subscribedChannelNames = channels.map((c) => c.matchName.toLowerCase()).toSet();
    final apiFeed = VideoRepository.instance.cachedFeed;
    final feedVideos = apiFeed.where((v) {
      return subscribedChannelNames.any((name) => v.channelName.toLowerCase().contains(name) || name.contains(v.channelName.toLowerCase()));
    }).toList();
    final videos = feedVideos.isEmpty ? apiFeed : feedVideos;

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
                    l.t('subscriptions.title'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showManageSheet(context),
                  child: Text(l.t('subscriptions.manage')),
                ),
              ],
            ),
          ),
          // Строка каналов с аватарками
          SizedBox(
            height: 112,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              // Не "съедаем" высоту вертикальным padding'ом: иначе при
              // масштабировании шрифтов/рендере web получается
              // RenderFlex overflowed by a few pixels.
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
                              channelName: ch.displayName,
                            videos: VideoRepository.instance.cachedFeed,
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
                                ch.displayName.characters.first.toUpperCase(),
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
                            ch.displayName,
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
              // Avoid double bottom insets (SafeArea + extra padding) that can
              // cause small RenderFlex overflows on web.
              padding: EdgeInsets.zero,
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
    required this.matchName,
    required this.displayName,
    required this.newCount,
    required this.latest,
  });
  final String matchName;
  final String displayName;
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
    final userExtra = l.t('you.privateProfileDemo');

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
                      SnackBar(
                        content: Text(l.t('you.editProfile')),
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
                              videos: VideoRepository.instance.cachedFeed,
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
    final l = AppLocalizations.of(context);
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
                    l.t('library.noVideosHereYet'),
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
  bool _isDragging = false;
  final Duration _snapDuration = const Duration(milliseconds: 380);

  Offset _nearestCorner({
    required Size screenSize,
    required double miniWidth,
    required double miniHeight,
    required Offset currentOffset,
  }) {
    const edgeInset = 8.0;
    final minRight = edgeInset;
    final maxRight = screenSize.width - miniWidth - edgeInset;
    final minBottom = edgeInset;
    final maxBottom = screenSize.height - miniHeight - edgeInset;

    final safeMaxRight = maxRight < minRight ? minRight : maxRight;
    final safeMaxBottom = maxBottom < minBottom ? minBottom : maxBottom;

    final corners = <Offset>[
      Offset(minRight, minBottom), // bottom-right
      Offset(safeMaxRight, minBottom), // bottom-left
      Offset(minRight, safeMaxBottom), // top-right
      Offset(safeMaxRight, safeMaxBottom), // top-left
    ];

    double bestDistSq = double.infinity;
    Offset best = corners.first;
    for (final c in corners) {
      final dx = currentOffset.dx - c.dx;
      final dy = currentOffset.dy - c.dy;
      final distSq = dx * dx + dy * dy;
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        best = c;
      }
    }
    return best;
  }

  Offset _clampToQuadrant({
    required Size screenSize,
    required double miniWidth,
    required double miniHeight,
    required Offset candidateOffset,
  }) {
    const edgeInset = 8.0;
    final minRight = edgeInset;
    final maxRight = screenSize.width - miniWidth - edgeInset;
    final minBottom = edgeInset;
    final maxBottom = screenSize.height - miniHeight - edgeInset;

    final safeMaxRight = maxRight < minRight ? minRight : maxRight;
    final safeMaxBottom = maxBottom < minBottom ? minBottom : maxBottom;

    final midRight = (minRight + safeMaxRight) / 2;
    final midBottom = (minBottom + safeMaxBottom) / 2;

    // Right side if closer to the right edge (smaller "right" offset).
    final isRightSide = candidateOffset.dx <= midRight;
    // Bottom side if closer to the bottom edge (smaller "bottom" offset).
    final isBottomSide = candidateOffset.dy <= midBottom;

    final clampedDx = isRightSide
        ? candidateOffset.dx.clamp(minRight, midRight)
        : candidateOffset.dx.clamp(midRight, safeMaxRight);
    final clampedDy = isBottomSide
        ? candidateOffset.dy.clamp(minBottom, midBottom)
        : candidateOffset.dy.clamp(midBottom, safeMaxBottom);

    return Offset(clampedDx, clampedDy);
  }

  // GUI6: track vertical swipe velocity for dismiss gesture
  double _swipeVelocity = 0;

  @override
  void initState() {
    super.initState();
    // Resume playback if it was interrupted during the screen transition.
    final c = widget.controller;
    if (c.value.isInitialized && !c.value.isPlaying) {
      c.play();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // OPT2: removed _onVideoTick setState — replaced with AnimatedBuilder in build()

  void _togglePlayPause() {
    final c = widget.controller;
    if (!c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    // No setState needed — AnimatedBuilder handles play/pause icon update
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

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : _snapDuration,
      curve: Curves.easeOutCubic,
      right: _offset.dx,
      bottom: _offset.dy,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() => _isDragging = true);
        },
        onPanUpdate: (details) {
          // GUI6: track vertical velocity for swipe-down dismiss
          _swipeVelocity = details.delta.dy;
          final candidate = Offset(
            _offset.dx - details.delta.dx,
            _offset.dy - details.delta.dy,
          );
          setState(() {
            _offset = _clampToQuadrant(
              screenSize: size,
              miniWidth: width,
              miniHeight: totalHeight,
              candidateOffset: candidate,
            );
          });
        },
        onPanEnd: (_) {
          // GUI6: swipe down fast → dismiss mini-player
          if (_swipeVelocity > 12) {
            widget.onClose();
            return;
          }
          setState(() {
            _isDragging = false;
            _offset = _nearestCorner(
              screenSize: size,
              miniWidth: width,
              miniHeight: totalHeight,
              currentOffset: _offset,
            );
          });
        },
        onPanCancel: () {
          setState(() {
            _isDragging = false;
            _offset = _nearestCorner(
              screenSize: size,
              miniWidth: width,
              miniHeight: totalHeight,
              currentOffset: _offset,
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
                // OPT2: AnimatedBuilder scopes all reactive parts to one subtree.
                AnimatedBuilder(
                  animation: widget.controller,
                  builder: (_, __) {
                    final v = widget.controller.value;
                    final playing = v.isPlaying;
                    final dur = v.duration;
                    final pos = v.position;
                    final progress = dur.inMilliseconds > 0
                        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0;
                    return Column(
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
                                    : const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(onTap: widget.onTap, child: const SizedBox.expand()),
                              ),
                              if (initialized && !playing)
                                Center(
                                  child: Material(
                                    color: Colors.black45,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      onPressed: _togglePlayPause,
                                      icon: const Icon(Symbols.play_arrow_rounded, color: Colors.white, size: 36, fill: 1),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        LayoutBuilder(
                          builder: (_, constraints) {
                            final barW = constraints.maxWidth;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (d) => _seekFromLocalX(d.localPosition.dx, barW),
                              onHorizontalDragUpdate: (d) => _seekFromLocalX(d.localPosition.dx, barW),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(1),
                                child: SizedBox(
                                  height: progressH,
                                  width: barW,
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: progressH,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
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
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: widget.onClose,
                        icon: const Icon(Symbols.close_rounded, color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ), // end AnimatedBuilder
              ],
            ),
          ),
        ),
      ),
    );
  }
}
