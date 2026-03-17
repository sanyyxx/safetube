import 'package:flutter/material.dart';

import '../../data/video_store.dart';
import '../../data/video_item.dart';
import 'widgets/video_list_item.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Will be wired to admin-loaded feed later.
            await Future<void>.delayed(const Duration(milliseconds: 150));
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _TopBar(
                    onCast: () {},
                    onNotifications: () {},
                    onSearch: () {},
                    onProfile: widget.onProfile,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              const SliverToBoxAdapter(child: _ChipsRow()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: ListView.separated(
                  primary: false,
                  shrinkWrap: true,
                  itemCount: demoFeed.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = demoFeed[i];
                    return VideoListItem(
                      video: item,
                      onTap: () => widget.onOpenVideo(item),
                    );
                  },
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
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Semantics(
            label: 'YouTube',
            child: const Icon(Icons.smart_display, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 6),
          Text(
            'YouTube',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Cast',
            onPressed: onCast,
            icon: const Icon(Icons.cast),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: onSearch,
            icon: const Icon(Icons.search),
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
                  child: Icon(Icons.person, size: 18, color: Colors.black54),
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
  const _ChipsRow();

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      ActionChip(
        label: const Text('Explore'),
        avatar: const Icon(Icons.explore_outlined, size: 18),
        onPressed: () {},
      ),
      const _DotSeparator(),
      const _FilterChip(text: 'All', selected: true),
      const _FilterChip(text: 'New to you'),
      const _FilterChip(text: 'Computer Programming'),
      const _FilterChip(text: 'Cooking'),
      const _FilterChip(text: 'Comedy'),
      const _FilterChip(text: 'DIY'),
      const _FilterChip(text: 'Fried Rice'),
      const _FilterChip(text: 'Recently Viewed'),
      const _FilterChip(text: 'Live'),
      TextButton(
        onPressed: () {},
        child: const Text(
          'SEND FEEDBACK',
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
  const _FilterChip({required this.text, this.selected = false});
  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(text),
      onSelected: (_) {},
      showCheckmark: false,
      selectedColor: const Color(0xFF9A9898),
    );
  }
}

