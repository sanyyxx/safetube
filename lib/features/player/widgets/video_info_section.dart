import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/video_item.dart';
import '../../../data/video_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/video_list_item.dart';

@immutable
class PlayerActionsState {
  const PlayerActionsState({
    required this.liked,
    required this.disliked,
    required this.subscribed,
    required this.likesCount,
  });

  final bool liked;
  final bool disliked;
  final bool subscribed;
  final int likesCount;

  PlayerActionsState copyWith({
    bool? liked,
    bool? disliked,
    bool? subscribed,
    int? likesCount,
  }) {
    return PlayerActionsState(
      liked: liked ?? this.liked,
      disliked: disliked ?? this.disliked,
      subscribed: subscribed ?? this.subscribed,
      likesCount: likesCount ?? this.likesCount,
    );
  }
}

/// Инфо-секция плеера в стиле YouTube: title → meta → channel → actions → comments → рекомендации.
class VideoInfoSection extends StatefulWidget {
  const VideoInfoSection({
    super.key,
    required this.video,
    required this.actions,
    required this.qualityLabel,
    required this.onLikeToggle,
    required this.onDislikeToggle,
    required this.onSubscribeToggle,
    required this.onShare,
    required this.onDownload,
    required this.onSave,
  });

  final VideoItem video;
  final ValueListenable<PlayerActionsState> actions;
  final String qualityLabel;
  final VoidCallback onLikeToggle;
  final VoidCallback onDislikeToggle;
  final VoidCallback onSubscribeToggle;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onSave;

  @override
  State<VideoInfoSection> createState() => _VideoInfoSectionState();
}

class _VideoInfoSectionState extends State<VideoInfoSection> {
  bool _titleExpanded = false;

  // OPT6: cached format strings — computed once, not on every build()
  late String _cachedViewsText;
  late String _cachedPublishedText;

  @override
  void initState() {
    super.initState();
    _updateCachedTexts();
  }

  @override
  void didUpdateWidget(VideoInfoSection old) {
    super.didUpdateWidget(old);
    if (old.video != widget.video) _updateCachedTexts();
  }

  void _updateCachedTexts() {
    _cachedViewsText = _formatViews(widget.video.viewsText);
    _cachedPublishedText = _formatPublished(widget.video.publishedText);
  }

  /// Форматирует ISO-дату / произвольную строку в удобочитаемый вид.
  String _formatPublished(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays >= 365) {
        final y = (diff.inDays / 365).floor();
        return '$y г. назад';
      } else if (diff.inDays >= 30) {
        final m = (diff.inDays / 30).floor();
        return '$m мес. назад';
      } else if (diff.inDays >= 1) {
        return '${diff.inDays} дн. назад';
      } else if (diff.inHours >= 1) {
        return '${diff.inHours} ч. назад';
      } else {
        return '${diff.inMinutes} мин. назад';
      }
    } catch (_) {
      return raw;
    }
  }

  String _formatViews(String raw) {
    if (raw.isEmpty) return '';
    final n = int.tryParse(raw.replaceAll(RegExp(r'[^\d]'), ''));
    if (n == null) return raw;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} млн просмотров';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)} тыс. просмотров';
    return '$n просмотров';
  }

  String _formatLikes(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)} млн';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)} тыс.';
    return count.toString();
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(video: widget.video),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final metaColor = isDark ? Colors.white54 : Colors.black45;

    final recs = VideoRepository.instance.cachedFeed
        .where((v) => v.id != widget.video.id)
        .take(10)
        .toList();

    return ColoredBox(
      color: bg,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Title block (tap → expand description inline) ─────────────
          _TitleBlock(
            title: widget.video.title,
            description: AppLocalizations.of(context).t('player.descriptionStub'),
            expanded: _titleExpanded,
            onToggle: () => setState(() => _titleExpanded = !_titleExpanded),
            viewsText: _cachedViewsText,
            publishedText: _cachedPublishedText,
            isDark: isDark,
          ),
          Divider(height: 1, color: dividerColor),

          // ── Channel + Subscribe ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _ChannelRow(
              channelName: widget.video.channelName,
              actions: widget.actions,
              onSubscribeToggle: widget.onSubscribeToggle,
            ),
          ),
          Divider(height: 1, color: dividerColor),

          // ── Action pills: Like | Dislike | Share | Download | Save ───────
          SizedBox(
            height: 52,
            child: _ActionsRow(
              actions: widget.actions,
              formatLikes: _formatLikes,
              onLike: widget.onLikeToggle,
              onDislike: widget.onDislikeToggle,
              onShare: widget.onShare,
              onDownload: widget.onDownload,
              onSave: widget.onSave,
            ),
          ),
          Divider(height: 1, color: dividerColor),

          // ── Comments card (tap → bottom sheet) ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: _CommentsPreviewCard(
              isDark: isDark,
              metaColor: metaColor,
              onTap: () => _openComments(context),
            ),
          ),
          const SizedBox(height: 8),

          // ── Recommended videos ────────────────────────────────────────────
          if (recs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                AppLocalizations.of(context).t('player.upNext'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            for (final rec in recs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: VideoListItem(
                  video: rec,
                  onTap: () {},
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.description,
    required this.expanded,
    required this.onToggle,
    required this.viewsText,
    required this.publishedText,
    required this.isDark,
  });

  final String title;
  final String description;
  final bool expanded;
  final VoidCallback onToggle;
  final String viewsText;
  final String publishedText;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final metaColor = isDark ? Colors.white54 : Colors.black45;
    final descBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2);

    final meta = [viewsText, publishedText].where((s) => s.isNotEmpty).join(' • ');

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with animated arrow
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: expanded ? null : 2,
                    overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Symbols.keyboard_arrow_down_rounded,
                    color: metaColor,
                    size: 22,
                  ),
                ),
              ],
            ),
            // Meta row: views • date
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: metaColor),
              ),
            ],
            // Description panel — visible only when expanded
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: descBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? const Color(0xDEFFFFFF) : Colors.black87,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// GUI9: reuse channel color helper from video_list_item.dart logic
Color _channelColorForName(String name) {
  const palette = [
    Color(0xFFE53935), Color(0xFF8E24AA), Color(0xFF1E88E5),
    Color(0xFF00897B), Color(0xFF43A047), Color(0xFFE91E63),
    Color(0xFF3949AB), Color(0xFF039BE5), Color(0xFF00ACC1),
    Color(0xFF7CB342), Color(0xFFF4511E), Color(0xFF6D4C41),
  ];
  if (name.isEmpty) return palette[0];
  final code = name.codeUnits.fold(0, (a, b) => a + b);
  return palette[code % palette.length];
}

// GUI7: generate a plausible subscriber count from channel name
String _mockSubscribers(String name) {
  if (name.isEmpty) return '';
  final code = name.codeUnits.fold(0, (a, b) => a + b);
  final base = (code % 980) + 20; // 20..999
  final bucket = (code % 4);
  if (bucket == 0) return '$base тыс. подписчиков';
  if (bucket == 1) return '${base * 10} тыс. подписчиков';
  if (bucket == 2) return '${(base / 10).toStringAsFixed(1)} млн подписчиков';
  return '$base подписчиков';
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channelName,
    required this.actions,
    required this.onSubscribeToggle,
  });

  final String channelName;
  final ValueListenable<PlayerActionsState> actions;
  final VoidCallback onSubscribeToggle;

  @override
  Widget build(BuildContext context) {
    final avatarColor = _channelColorForName(channelName);
    final subscriberText = _mockSubscribers(channelName);
    return ValueListenableBuilder<PlayerActionsState>(
      valueListenable: actions,
      builder: (context, a, _) {
        return Row(
          children: [
            // GUI9: colored initial avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: avatarColor,
              child: Text(
                channelName.isNotEmpty ? channelName.characters.first.toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  // GUI7: subscriber count below channel name
                  if (subscriberText.isNotEmpty)
                    Text(
                      subscriberText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: a.subscribed
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF0F0F0))
                    : Colors.red,
                foregroundColor: a.subscribed
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                minimumSize: const Size(0, 36),
              ),
              onPressed: onSubscribeToggle,
              child: Text(
                AppLocalizations.of(context)
                    .t(a.subscribed ? 'shorts.subscribed' : 'shorts.subscribe'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.actions,
    required this.formatLikes,
    required this.onLike,
    required this.onDislike,
    required this.onShare,
    required this.onDownload,
    required this.onSave,
  });

  final ValueListenable<PlayerActionsState> actions;
  final String Function(int) formatLikes;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<PlayerActionsState>(
      valueListenable: actions,
      builder: (context, a, _) {
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: [
            // Like + Dislike в одной pill-группе
            _PillGroup(children: [
              _PillBtn(
                icon: Symbols.thumb_up_rounded,
                label: formatLikes(a.likesCount),
                fill: a.liked,
                onTap: onLike,
              ),
              _PillDivider(),
              _PillBtn(
                icon: Symbols.thumb_down_rounded,
                fill: a.disliked,
                onTap: onDislike,
              ),
            ]),
            const SizedBox(width: 8),
            _PillGroup(children: [
              _PillBtn(
                icon: Symbols.reply_rounded,
                label: l.t('player.action.share'),
                onTap: onShare,
              ),
            ]),
            const SizedBox(width: 8),
            _PillGroup(children: [
              _PillBtn(
                icon: Symbols.download_rounded,
                label: l.t('player.action.download'),
                onTap: onDownload,
              ),
            ]),
            const SizedBox(width: 8),
            _PillGroup(children: [
              _PillBtn(
                icon: Symbols.playlist_add_rounded,
                label: l.t('player.action.save'),
                onTap: onSave,
              ),
            ]),
          ],
        );
      },
    );
  }
}

class _PillGroup extends StatelessWidget {
  const _PillGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: ColoredBox(
        color: bg,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _PillDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 24,
      color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFDDDDDD),
    );
  }
}

class _PillBtn extends StatelessWidget {
  const _PillBtn({
    required this.icon,
    this.label,
    this.fill = false,
    this.onTap,
  });

  final IconData icon;
  final String? label;
  final bool fill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = fill
        ? Theme.of(context).colorScheme.primary
        : (isDark ? Colors.white : Colors.black87);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: label != null ? 14 : 12, vertical: 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: fg, fill: fill ? 1 : 0),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: fg,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _DescriptionCard extends StatefulWidget {
  const _DescriptionCard({required this.isDark});
  final bool isDark;

  @override
  State<_DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<_DescriptionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).t('player.descriptionStub'),
                maxLines: _expanded ? null : 2,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _expanded
                    ? AppLocalizations.of(context).t('player.descriptionCollapse')
                    : AppLocalizations.of(context).t('player.descriptionExpand'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _CommentsPreviewCard extends StatelessWidget {
  const _CommentsPreviewCard({
    required this.isDark,
    required this.metaColor,
    required this.onTap,
  });

  final bool isDark;
  final Color metaColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l.t('player.comments'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  l.t('player.comments.dotCount'),
                  style: TextStyle(fontSize: 13, color: metaColor),
                ),
                const Spacer(),
                Icon(Symbols.keyboard_arrow_down_rounded, color: metaColor, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFDDDDDD),
                  child: Icon(Symbols.person_rounded, size: 16, color: Colors.black54),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.t('player.comments.greatVideo'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Боттом-шит с комментариями (как на референсном скрине 3).
class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.video});
  final VideoItem video;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  int _sortIndex = 0; // 0=popular, 1=topics, 2=timestamp

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final metaColor = isDark ? Colors.white54 : Colors.black45;
    final l = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.5, 0.75, 0.95],
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      l.t('player.comments'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Symbols.info_rounded,
                      size: 18,
                      color: metaColor,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Symbols.close_rounded, color: metaColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Sort chips ───────────────────────────────────────────────
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _SortChip(
                      label: l.t('player.comments.sort.popular'),
                      selected: _sortIndex == 0,
                      onTap: () => setState(() => _sortIndex = 0),
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: l.t('player.comments.sort.topics'),
                      selected: _sortIndex == 1,
                      starred: true,
                      onTap: () => setState(() => _sortIndex = 1),
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: l.t('player.comments.sort.timestamp'),
                      selected: _sortIndex == 2,
                      onTap: () => setState(() => _sortIndex = 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Content ──────────────────────────────────────────────────
              Expanded(
                child: _sortIndex == 1
                    ? _TopicsView(
                        isDark: isDark,
                        scrollController: scrollController,
                        l: l,
                      )
                    : _CommentsList(
                        scrollController: scrollController,
                        metaColor: metaColor,
                        l: l,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.starred = false,
  });

  final String label;
  final bool selected;
  final bool starred;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0));
    final fg = selected
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white70 : Colors.black87);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (starred) ...[
              Icon(Symbols.star_rounded, size: 14, color: fg, fill: 1),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicsView extends StatelessWidget {
  const _TopicsView({
    required this.isDark,
    required this.scrollController,
    required this.l,
  });

  final bool isDark;
  final ScrollController scrollController;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5);
    final metaColor = isDark ? Colors.white38 : Colors.black38;

    final aiTopics = [
      (l.t('player.comments.ai.topic1'), l.t('player.comments.ai.topic1detail')),
      (l.t('player.comments.ai.topic2'), l.t('player.comments.ai.topic2detail')),
      (l.t('player.comments.ai.topic3'), l.t('player.comments.ai.topic3detail')),
      (l.t('player.comments.ai.topic4'), l.t('player.comments.ai.topic4detail')),
    ];

    // OPT9: ListView.builder for the topics list
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: 1 + aiTopics.length,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Container(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l.t('player.comments.aiSummary'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const Spacer(),
                    Icon(Symbols.more_vert_rounded, color: metaColor, size: 20),
                  ],
                ),
                const SizedBox(height: 2),
                Text(l.t('player.comments.aiDisclaimer'), style: TextStyle(fontSize: 12, color: metaColor)),
                const SizedBox(height: 10),
              ],
            ),
          );
        }
        final t = aiTopics[i - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _AiTopicTile(title: t.$1, detail: t.$2, isDark: isDark, cardBg: cardBg),
        );
      },
    );
  }
}

class _AiTopicTile extends StatelessWidget {
  const _AiTopicTile({
    required this.title,
    required this.detail,
    required this.isDark,
    required this.cardBg,
  });

  final String title;
  final String detail;
  final bool isDark;
  final Color cardBg;

  @override
  Widget build(BuildContext context) {
    final innerBg = isDark ? const Color(0xFF2E2E2E) : Colors.white;
    final metaColor = isDark ? Colors.white54 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: innerBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEEEEEE),
            child: Icon(
              Symbols.chat_bubble_rounded,
              size: 18,
              color: metaColor,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: metaColor),
          ),
          trailing: Icon(Symbols.chevron_right_rounded, color: metaColor, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          onTap: () {},
        ),
      ),
    );
  }
}

class _CommentsList extends StatelessWidget {
  const _CommentsList({
    required this.scrollController,
    required this.metaColor,
    required this.l,
  });

  final ScrollController scrollController;
  final Color metaColor;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: 15,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final isPinned = i == 0;
        // GUI9: unique color per commenter
        const initials = ['А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ж', 'З', 'И', 'К', 'Л', 'М', 'Н', 'О', 'П'];
        final avatarColor = _channelColorForName('user$i');
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: avatarColor,
              child: Text(
                initials[i % initials.length],
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPinned)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Symbols.push_pin_rounded, size: 13, color: metaColor),
                          const SizedBox(width: 4),
                          Text(
                            l.t('player.comments.pinnedComment'),
                            style: TextStyle(fontSize: 11, color: metaColor),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    l.t('player.comments.userTime').replaceAll('%s', i.toString()),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: metaColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.t('player.comments.greatVideo'),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Symbols.thumb_up_rounded, size: 15, color: metaColor),
                      const SizedBox(width: 4),
                      Text('${24 + i * 7}',
                          style: TextStyle(fontSize: 12, color: metaColor)),
                      const SizedBox(width: 14),
                      Icon(Symbols.thumb_down_rounded, size: 15, color: metaColor),
                      const SizedBox(width: 16),
                      Text(
                        l.t('player.comments.replyLabel'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: metaColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
