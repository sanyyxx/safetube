import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/video_item.dart';
import '../../data/video_repository.dart';
import 'widgets/video_list_item.dart';
import 'search_screen.dart';
import 'youtube_search_screen.dart';
import '../../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenVideo,
    required this.onProfile,
  });

  final Future<void> Function(VideoItem) onOpenVideo;
  final VoidCallback onProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<SearchHistoryEntry> _searchHistory = [];
  // Internal filter ids (not localized), used for basic filtering on feed.
  String _activeFilter = 'all';

  bool _feedLoading = true;
  String? _feedError;

  @override
  void initState() {
    super.initState();
    // OPT10: listen to feedNotifier so only HomeScreen rebuilds on new data
    VideoRepository.instance.feedNotifier.addListener(_onFeedNotified);
    _loadFeed();
  }

  @override
  void dispose() {
    VideoRepository.instance.feedNotifier.removeListener(_onFeedNotified);
    super.dispose();
  }

  void _onFeedNotified() {
    if (mounted) setState(() {});
  }

  Future<void> _loadFeed({bool force = false}) async {
    setState(() {
      _feedLoading = true;
      if (force) _feedError = null;
    });
    try {
      await VideoRepository.instance.loadFeed(force: force);
      _feedError = null;
    } catch (e) {
      _feedError = VideoRepository.instance.lastError ?? e.toString();
    }
    if (mounted) {
      setState(() => _feedLoading = false);
    }
  }

  List<VideoItem> get _filteredFeed {
    final base = VideoRepository.instance.cachedFeed;
    Iterable<VideoItem> result = base;

    if (_activeFilter != 'all') {
      final keyword = switch (_activeFilter) {
        'newToYou' => 'new',
        'programming' => 'programming',
        'cooking' => 'cooking',
        'comedy' => 'comedy',
        'diy' => 'diy',
        'friedRice' => 'fried',
        'recentlyViewed' => 'recent',
        'live' => 'live',
        _ => '',
      };

      result = result.where(
        (v) =>
            v.title.toLowerCase().contains(keyword) ||
            v.channelName.toLowerCase().contains(keyword),
      );

      // If nothing matches the chip filter, show full feed so UI never looks empty.
      if (result.isEmpty) result = base;
    }

    // Поиск — отдельный экран; не фильтруем главную ленту по строке поиска,
    // иначе после «назад» из поиска остаётся запрос и лента может стать пустой.

    return result.toList();
  }

  Future<void> _showSimpleSnack(String message) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _showSearchDialog() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => YouTubeSearchScreen(
          initialQuery: '',
          history: List<SearchHistoryEntry>.from(_searchHistory),
          onSearch: (query) {
            setState(() {
              _searchHistory.removeWhere((e) => e.query == query);
              _searchHistory.insert(0, SearchHistoryEntry(query: query));
              if (_searchHistory.length > 20) _searchHistory.removeLast();
            });
          },
          onApplyQuery: (_) {},
          onOpenVideo: (item) => widget.onOpenVideo(item),
        ),
      ),
    );
  }

  void _updateFilter(String value) {
    setState(() {
      _activeFilter = value;
    });
  }

  void _showCastSheet() {
    final l = AppLocalizations.of(context);
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
                AppLocalizations.of(ctx).t('home.cast'),
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(l.t('home.cast.connectToTv')),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Symbols.tv_rounded),
                title: Text(l.t('home.cast.chromecast')),
                subtitle: Text(l.t('home.cast.notConnected')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSimpleSnack(l.t('home.cast.searchingDevices'));
                },
              ),
              ListTile(
                leading: const Icon(Symbols.help_outline_rounded),
                title: Text(l.t('home.cast.help')),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(ctx).t('home.notifications'),
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      AppLocalizations.of(ctx).t('home.notifications.markAllAsRead'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Symbols.notifications_rounded,
                    size: 64,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(ctx).t('home.notifications.caughtUpTitle'),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(ctx).t('home.notifications.noNewNotifications'),
                    style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExploreSheet() {
    final l = AppLocalizations.of(context);
    final topics = <Map<String, String>>[
      {'id': 'music', 'label': l.t('home.topic.music')},
      {'id': 'gaming', 'label': l.t('home.topic.gaming')},
      {'id': 'sports', 'label': l.t('home.topic.sports')},
      {'id': 'news', 'label': l.t('home.topic.news')},
      {'id': 'learning', 'label': l.t('home.topic.learning')},
      {'id': 'fashion', 'label': l.t('home.topic.fashion')},
      {'id': 'science', 'label': l.t('home.topic.science')},
      {'id': 'cooking', 'label': l.t('home.topic.cooking')},
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
                AppLocalizations.of(ctx).t('home.explore'),
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: topics
                    .map(
                      (t) => ActionChip(
                        label: Text(t['label'] ?? ''),
                        onPressed: () {
                          Navigator.pop(ctx);
                          final id = t['id'] ?? 'all';
                          final mapped = switch (id) {
                            'news' => 'newToYou',
                            'learning' => 'programming',
                            'science' => 'programming',
                            'cooking' => 'cooking',
                            'fashion' => 'diy',
                            _ => 'all',
                          };
                          _updateFilter(mapped);
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final feed = VideoRepository.instance.cachedFeed;
    final showInitialLoading = _feedLoading && feed.isEmpty && _feedError == null;
    final showError = _feedError != null && feed.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadFeed(force: true),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _TopBar(
                    onCast: _showCastSheet,
                    onNotifications: _showNotificationsSheet,
                    onRefreshFeed: () => _loadFeed(force: true),
                    onSearch: _showSearchDialog,
                    onProfile: widget.onProfile,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: _ChipsRow(
                  activeFilter: _activeFilter,
                  onFilterChanged: _updateFilter,
                  onExplore: _showExploreSheet,
                  onFeedback: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (context) {
                      final l = AppLocalizations.of(context);
                        final controller = TextEditingController();
                        return AlertDialog(
                        title: Text(l.t('home.feedback.title')),
                          content: TextField(
                            controller: controller,
                            maxLines: 4,
                          decoration: InputDecoration(
                            hintText: l.t('home.feedback.hint'),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                            child: Text(l.t('home.feedback.cancel')),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              _showSimpleSnack(l.t('home.feedback.thanks'));
                              },
                            child: Text(l.t('home.feedback.send')),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              // GUI4: skeleton shimmer cards while loading
              if (showInitialLoading)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: _SkeletonVideoCard(),
                    ),
                    childCount: 6,
                  ),
                )
              else if (showError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.wifi_off_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l.t('home.feed.loadError'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (_feedError != null && _feedError!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _feedError!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => _loadFeed(force: true),
                            icon: const Icon(Symbols.refresh_rounded),
                            label: Text(l.t('home.feed.retry')),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_filteredFeed.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        l.t('home.feed.empty'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final item = _filteredFeed[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: VideoListItem(
                          video: item,
                          onTap: () => widget.onOpenVideo(item),
                        ),
                      );
                    },
                    childCount: _filteredFeed.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onCast,
    required this.onNotifications,
    required this.onRefreshFeed,
    required this.onSearch,
    required this.onProfile,
  });

  final VoidCallback onCast;
  final VoidCallback onNotifications;
  final VoidCallback onRefreshFeed;
  final VoidCallback onSearch;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Semantics(
            label: l.t('app.youtube'),
            child: const Icon(Symbols.smart_display_rounded, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 6),
          Text(
            l.t('app.youtube'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          IconButton(
            tooltip: l.t('home.cast'),
            onPressed: onCast,
            icon: const Icon(Symbols.cast_rounded),
          ),
          IconButton(
            tooltip: l.t('home.notifications'),
            onPressed: onNotifications,
            icon: const Icon(Symbols.notifications_rounded),
          ),
          IconButton(
            tooltip: l.t('home.feed.refreshFeed'),
            onPressed: onRefreshFeed,
            icon: const Icon(Symbols.refresh_rounded),
          ),
          IconButton(
            tooltip: l.t('home.search'),
            onPressed: onSearch,
            icon: const Icon(Symbols.search_rounded),
          ),
          Semantics(
            label: l.t('nav.you'),
            button: true,
            child: InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFEEEEEE),
                  child: Icon(Symbols.person_rounded, size: 18, color: Colors.black54),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({
    required this.activeFilter,
    required this.onFilterChanged,
    required this.onExplore,
    required this.onFeedback,
  });

  final String activeFilter;
  final void Function(String) onFilterChanged;
  final VoidCallback onExplore;
  final VoidCallback onFeedback;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final filters = <String>[
      'all',
      'newToYou',
      'programming',
      'cooking',
      'comedy',
      'diy',
      'friedRice',
      'recentlyViewed',
      'live',
    ];

    final filterLabels = <String, String>{
      'all': l.t('home.filter.all'),
      'newToYou': l.t('home.filter.newToYou'),
      'programming': l.t('home.filter.programming'),
      'cooking': l.t('home.filter.cooking'),
      'comedy': l.t('home.filter.comedy'),
      'diy': l.t('home.filter.diy'),
      'friedRice': l.t('home.filter.friedRice'),
      'recentlyViewed': l.t('home.filter.recentlyViewed'),
      'live': l.t('home.filter.live'),
    };

    final chips = <Widget>[
      ActionChip(
        label: Text(l.t('home.explore')),
        avatar: const Icon(Symbols.explore_rounded, size: 18),
        onPressed: onExplore,
      ),
      const _DotSeparator(),
      for (final f in filters)
        _FilterChip(
          text: filterLabels[f] ?? f,
          selected: activeFilter == f,
          onSelected: () => onFilterChanged(f),
        ),
      TextButton(
        onPressed: onFeedback,
        child: Text(
          l.t('home.sendFeedback'),
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => Center(child: chips[i]),
      ),
    );
  }
}

class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Colors.black54,
    );
  }
}

// GUI4: shimmer skeleton card shown while feed is loading
class _SkeletonVideoCard extends StatefulWidget {
  const _SkeletonVideoCard();
  @override
  State<_SkeletonVideoCard> createState() => _SkeletonVideoCardState();
}

class _SkeletonVideoCardState extends State<_SkeletonVideoCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final base = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
        final highlight = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF0F0F0);
        final color = Color.lerp(base, highlight, _anim.value)!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: Container(color: color)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 20, backgroundColor: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 14, width: double.infinity, color: color),
                        const SizedBox(height: 6),
                        Container(height: 12, width: 160, color: color),
                        const SizedBox(height: 4),
                        Container(height: 12, width: 100, color: color),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.text,
    this.selected = false,
    required this.onSelected,
  });
  final String text;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(text),
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: const Color(0xFF9A9898),
    );
  }
}

