import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/video_store.dart';
import '../../data/video_item.dart';
import 'widgets/video_list_item.dart';
import 'search_screen.dart';
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
  String _searchQuery = '';
  final List<SearchHistoryEntry> _searchHistory = [];
  // Internal filter ids (not localized), used for basic filtering on demo data.
  String _activeFilter = 'all';

  List<VideoItem> get _filteredFeed {
    final base = demoFeed;
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

      // Demo feed is tiny; if nothing matches, show all so UI never looks broken.
      if (result.isEmpty) result = base;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where(
        (v) =>
            v.title.toLowerCase().contains(q) ||
            v.channelName.toLowerCase().contains(q),
      );
    }

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
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          initialQuery: _searchQuery,
          history: List<SearchHistoryEntry>.from(_searchHistory),
          onSearch: (query) {
            setState(() {
              _searchHistory.removeWhere((e) => e.query == query);
              _searchHistory.insert(0, SearchHistoryEntry(query: query));
              if (_searchHistory.length > 20) _searchHistory.removeLast();
            });
          },
          onApplyQuery: (query) {
            setState(() => _searchQuery = query);
          },
          onOpenVideo: (item) => widget.onOpenVideo(item),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _searchQuery = result.trim();
    });
  }

  void _updateFilter(String value) {
    setState(() {
      _activeFilter = value;
    });
  }

  void _showCastSheet() {
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
              const Text(
                'Connect to a TV or other device to play video on a bigger screen.',
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Symbols.tv_rounded),
                title: const Text('Chromecast'),
                subtitle: const Text('Not connected'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSimpleSnack('Searching for devices…');
                },
              ),
              ListTile(
                leading: const Icon(Symbols.help_outline_rounded),
                title: const Text('Help'),
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
                    child: const Text('Mark all as read'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  Icon(Symbols.notifications_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'You\'re all caught up',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'No new notifications',
                    style: TextStyle(color: Colors.grey),
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
    final topics = <String>[
      'Music',
      'Gaming',
      'Sports',
      'News',
      'Learning',
      'Fashion',
      'Science',
      'Cooking',
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
                        label: Text(t),
                        onPressed: () {
                          Navigator.pop(ctx);
                          final mapped = switch (t) {
                            'News' => 'newToYou',
                            'Learning' => 'programming',
                            'Science' => 'programming',
                            'Cooking' => 'cooking',
                            'Fashion' => 'diy',
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
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 150));
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _TopBar(
                    onCast: _showCastSheet,
                    onNotifications: _showNotificationsSheet,
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
                        final controller = TextEditingController();
                        return AlertDialog(
                          title: const Text('Send feedback'),
                          content: TextField(
                            controller: controller,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Tell us what you think',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('CANCEL'),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showSimpleSnack('Thanks for your feedback!');
                              },
                              child: const Text('SEND'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
    required this.onSearch,
    required this.onProfile,
  });

  final VoidCallback onCast;
  final VoidCallback onNotifications;
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
            label: 'YouTube',
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
            tooltip: l.t('home.search'),
            onPressed: onSearch,
            icon: const Icon(Symbols.search_rounded),
          ),
          Semantics(
            label: 'Profile',
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

