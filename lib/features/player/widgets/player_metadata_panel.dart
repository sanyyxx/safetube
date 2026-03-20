import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/video_item.dart';
import '../../../l10n/app_localizations.dart';

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

class PlayerMetadataPanel extends StatelessWidget {
  const PlayerMetadataPanel({
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
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      children: [
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '${video.viewsText} • ${video.publishedText}'.trim(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quality: $qualityLabel',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFEEEEEE),
              child: Icon(Symbols.person_rounded, color: Colors.black54),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                video.channelName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ValueListenableBuilder<PlayerActionsState>(
              valueListenable: actions,
              builder: (context, a, _) {
                return FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        a.subscribed ? Colors.grey[800] : Colors.red,
                  ),
                  onPressed: onSubscribeToggle,
                  child: Text(
                    AppLocalizations.of(context).t(
                      a.subscribed ? 'shorts.subscribed' : 'shorts.subscribe',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ValueListenableBuilder<PlayerActionsState>(
                valueListenable: actions,
                builder: (context, a, _) {
                  return _ActionPill(
                    icon: a.liked ? Symbols.thumb_up_rounded : Symbols.thumb_up_rounded,
                    label: a.likesCount.toString(),
                    active: a.liked,
                    onTap: onLikeToggle,
                  );
                },
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<PlayerActionsState>(
                valueListenable: actions,
                builder: (context, a, _) {
                  return _ActionPill(
                    icon: a.disliked
                        ? Symbols.thumb_down_rounded
                        : Symbols.thumb_down_rounded,
                    label:
                        AppLocalizations.of(context).t('player.action.dislike'),
                    active: a.disliked,
                    onTap: onDislikeToggle,
                  );
                },
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: Symbols.reply_rounded,
                label: AppLocalizations.of(context).t('player.action.share'),
                onTap: onShare,
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: Symbols.download_rounded,
                label: AppLocalizations.of(context).t('player.action.download'),
                onTap: onDownload,
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: Symbols.playlist_add_rounded,
                label: AppLocalizations.of(context).t('player.action.save'),
                onTap: onSave,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white10
              : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              AppLocalizations.of(context).t('player.descriptionStub'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context).t('player.noRecommendations'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black54,
          ),
        ),
        const SizedBox(height: 16),
        const _CommentsSection(),
        const SizedBox(height: 16),
        const _RecommendationsSection(),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF2F2F2);
    final bgActive =
        isDark ? const Color(0xFF3A3A3A) : Colors.white.withOpacity(0.95);
    final fgInactive = isDark ? Colors.white.withOpacity(0.85) : Colors.black87;
    final fgActive = active
        ? (isDark
            ? theme.colorScheme.primary.withOpacity(0.95)
            : theme.colorScheme.primary)
        : fgInactive;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? bgActive : bg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: fgActive,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: fgActive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context).t('player.comments'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              l.t('player.comments.dotCount'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFFDDDDDD),
                    child: Icon(Symbols.person_rounded,
                        size: 16, color: Colors.black54),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l
                              .t('player.comments.userTime')
                              .replaceAll('%s', i.toString()),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(l.t('player.comments.greatVideo')),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Symbols.thumb_up_rounded,
                                size: 14, color: Colors.black54),
                            SizedBox(width: 4),
                            Text('24', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (i != 2) const SizedBox(height: 10),
            ],
          ],
        ),
      ],
    );
  }
}

class _RecommendationsSection extends StatelessWidget {
  const _RecommendationsSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).t('player.upNext'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            for (var i = 0; i < 5; i++) ...[
              Row(
                children: [
                  Container(
                    width: 120,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDDDDD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Symbols.play_arrow_rounded,
                        color: Colors.black54),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l
                              .t('player.recommendations.recommendedVideo')
                              .replaceAll('%s', i.toString()),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.t('player.recommendations.channelMeta'),
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (i != 4) const SizedBox(height: 10),
            ],
          ],
        ),
      ],
    );
  }
}

