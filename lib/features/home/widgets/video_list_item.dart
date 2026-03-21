import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/video_item.dart';
import '../../../l10n/app_localizations.dart';

/// Pick a deterministic accent color from the channel name for the avatar.
Color _channelColor(String name) {
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

// OPT4: wrapped in RepaintBoundary so sibling repaints don't affect this card.
class VideoListItem extends StatefulWidget {
  const VideoListItem({
    super.key,
    required this.video,
    required this.onTap,
  });

  final VideoItem video;
  final VoidCallback onTap;

  @override
  State<VideoListItem> createState() => _VideoListItemState();
}

class _VideoListItemState extends State<VideoListItem> {
  // GUI10: hover state (web only)
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final video = widget.video;
    final title = video.title;
    final channel = video.channelName;
    final views = video.viewsText;
    final when = video.publishedText;
    final meta = [channel, views, when].where((s) => s.isNotEmpty).join(' • ');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final metaColor = isDark ? Colors.white70 : const Color(0xFF606060);
    final avatarColor = _channelColor(channel); // GUI9

    Widget card = Semantics(
      container: true,
      label: l
          .t('videoList.semantics.video')
          .replaceAll('%title', title)
          .replaceAll('%meta', meta),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovered
            ? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04))
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      // OPT5: cap decoded size to reduce GPU memory usage
                      memCacheWidth: 480,
                      placeholder: (context, url) => Container(color: const Color(0xFFEEEEEE)),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFFEEEEEE),
                        child: const Center(child: Icon(Symbols.broken_image_rounded)),
                      ),
                    ),
                  ),
                if (video.durationText != null && video.durationText!.isNotEmpty)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        video.durationText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GUI9: deterministic color per channel name
                  Semantics(
                    label: l.t('videoList.semantics.channelAvatar'),
                    image: true,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: avatarColor,
                      child: Text(
                        channel.isNotEmpty ? channel.characters.first.toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: metaColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                      tooltip: l.t('videoList.moreActions'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (context) {
                            return SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading:
                                        const Icon(Symbols.play_arrow_rounded),
                                    title: Text(l.t('videoList.playNow')),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      widget.onTap();
                                    },
                                  ),
                                  ListTile(
                                    leading:
                                        const Icon(Symbols.watch_later_rounded),
                                    title: Text(l.t('videoList.watchLater')),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l.t('videoList.addedToWatchLater'),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading:
                                        const Icon(Symbols.playlist_add_rounded),
                                    title: Text(l.t('videoList.saveToPlaylist')),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(l.t('videoList.savedToPlaylist')),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      icon: const Icon(Symbols.more_vert_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // OPT4: RepaintBoundary isolates paint from siblings in the feed list.
    // GUI10: MouseRegion adds hover highlight on web.
    if (kIsWeb) {
      return RepaintBoundary(
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: card,
        ),
      );
    }
    return RepaintBoundary(child: card);
  }
}

class VideoGridItem extends StatelessWidget {
  const VideoGridItem({
    super.key,
    required this.video,
    required this.onTap,
  });

  final VideoItem video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = video.title;
    final channel = video.channelName;
    final views = video.viewsText;
    final meta = [channel, views].where((s) => s.isNotEmpty).join(' • ');

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Semantics(
      container: true,
      label: l
          .t('videoList.semantics.video')
          .replaceAll('%title', title)
          .replaceAll('%meta', meta),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFFEEEEEE),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFFEEEEEE),
                    child: const Center(
                      child: Icon(Symbols.broken_image_rounded),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                    color: subtitleColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
