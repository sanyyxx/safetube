import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/video_item.dart';

class VideoListItem extends StatelessWidget {
  const VideoListItem({
    super.key,
    required this.video,
    required this.onTap,
  });

  final VideoItem video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = video.title;
    final channel = video.channelName;
    final views = video.viewsText;
    final when = video.publishedText;
    final meta = [channel, views, when].where((s) => s.isNotEmpty).join(' • ');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final metaColor = isDark ? Colors.white70 : const Color(0xFF606060);

    return Semantics(
      container: true,
      label: 'Video: $title. $meta',
      child: InkWell(
        onTap: onTap,
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
                  Semantics(
                    label: 'Channel avatar',
                    image: true,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      child: Text(
                        channel.isNotEmpty
                            ? channel.characters.first.toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
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
                      tooltip: 'More actions',
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
                                    title: const Text('Play now'),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      onTap();
                                    },
                                  ),
                                  ListTile(
                                    leading:
                                        const Icon(Symbols.watch_later_rounded),
                                    title: const Text('Watch later'),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Added to “Watch later” ',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading:
                                        const Icon(Symbols.playlist_add_rounded),
                                    title: const Text('Save to playlist'),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Saved to playlist',
                                          ),
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
    );
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
    final title = video.title;
    final channel = video.channelName;
    final views = video.viewsText;
    final meta = [channel, views].where((s) => s.isNotEmpty).join(' • ');

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Semantics(
      container: true,
      label: 'Video: $title. $meta',
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
