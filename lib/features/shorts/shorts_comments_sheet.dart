import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';

/// One comment for the Shorts comments sheet.
class ShortsComment {
  const ShortsComment({
    required this.authorHandle,
    required this.authorAvatarUrl,
    required this.text,
    required this.timeAgo,
    required this.likeCount,
    this.isPinned = false,
    this.pinnedByHandle,
    this.replyCount = 0,
    this.isVerified = false,
    this.creatorLiked = false,
  });

  final String authorHandle;
  final String? authorAvatarUrl;
  final String text;
  final String timeAgo;
  final int likeCount;
  final bool isPinned;
  final String? pinnedByHandle;
  final int replyCount;
  final bool isVerified;
  final bool creatorLiked;
}

/// YouTube-style comments bottom sheet for Shorts: drag handle, header with count,
/// list of comments (avatar, username, time, like/dislike/reply), pinned, input at bottom.
void showShortsCommentsSheet(
  BuildContext context, {
  required int commentCount,
  required List<ShortsComment> comments,
  required void Function(String text) onSendComment,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => _ShortsCommentsContent(
        commentCount: commentCount,
        comments: comments,
        scrollController: scrollController,
        onSendComment: onSendComment,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
}

class _ShortsCommentsContent extends StatefulWidget {
  const _ShortsCommentsContent({
    required this.commentCount,
    required this.comments,
    required this.scrollController,
    required this.onSendComment,
    required this.onClose,
  });

  final int commentCount;
  final List<ShortsComment> comments;
  final ScrollController scrollController;
  final void Function(String text) onSendComment;
  final VoidCallback onClose;

  @override
  State<_ShortsCommentsContent> createState() => _ShortsCommentsContentState();
}

class _ShortsCommentsContentState extends State<_ShortsCommentsContent> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  static const _bg = Color(0xFF000000);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFFAAAAAA);
  static const _inputBg = Color(0xFF2A2A2A);

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _bg : Colors.white;
    final textPrimary = isDark ? _textPrimary : Colors.black87;
    final textSecondary = isDark ? _textSecondary : const Color(0xFF666666);
    final inputBg = isDark ? _inputBg : const Color(0xFFF2F2F2);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _buildHandle(textSecondary),
          _buildHeader(context, l, textPrimary),
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: widget.comments.length,
              itemBuilder: (context, i) => _CommentTile(comment: widget.comments[i], l: l),
            ),
          ),
          _buildInput(context, l, bg, inputBg, textPrimary, textSecondary),
        ],
      ),
    );
  }

  Widget _buildHandle(Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: textSecondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '${l.t('shorts.commentsTitle')} ${widget.commentCount}',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Symbols.tune_rounded, color: textPrimary, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.t('shorts.filterComments'))),
              );
            },
          ),
          IconButton(
            icon: Icon(Symbols.close_rounded, color: textPrimary, size: 24),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
    BuildContext context,
    AppLocalizations l,
    Color bg,
    Color inputBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      color: bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: inputBg,
            child: Icon(Symbols.person_rounded, color: textSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocus,
              style: TextStyle(color: textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: l.t('shorts.commentPlaceholder'),
                hintStyle: TextStyle(color: textSecondary),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onSubmitted: (value) {
                final t = value.trim();
                if (t.isNotEmpty) {
                  widget.onSendComment(t);
                  _inputController.clear();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.l});

  final ShortsComment comment;
  final AppLocalizations l;

  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFFAAAAAA);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? _textPrimary : Colors.black87;
    final textSecondary = isDark ? _textSecondary : const Color(0xFF666666);
    final avatarBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEFEFEF);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarBg,
            backgroundImage: comment.authorAvatarUrl != null
                ? NetworkImage(comment.authorAvatarUrl!)
                : null,
            child: comment.authorAvatarUrl == null
                ? Icon(Symbols.person_rounded, color: textSecondary, size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (comment.isPinned && comment.pinnedByHandle != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Symbols.push_pin_rounded, size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${l.t('shorts.pinnedBy')} ${comment.pinnedByHandle}',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      comment.authorHandle,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (comment.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Symbols.check_circle_rounded, size: 14, color: Color(0xFF1E90FF)),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      comment.timeAgo,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Symbols.more_vert_rounded, color: textSecondary, size: 20),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: TextStyle(color: textPrimary, fontSize: 14, height: 1.3),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Symbols.thumb_up_rounded, size: 18, color: textSecondary),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                    ),
                    if (comment.likeCount > 0)
                      Text(
                        _formatCount(comment.likeCount),
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Symbols.thumb_down_rounded, size: 18, color: textSecondary),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Symbols.reply_rounded, size: 18, color: textSecondary),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                    ),
                    if (comment.creatorLiked) ...[
                      const SizedBox(width: 8),
                      const Icon(Symbols.favorite_rounded, size: 16, color: Colors.red),
                    ],
                  ],
                ),
                if (comment.replyCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l.t('shorts.repliesCount').replaceAll('%s', comment.replyCount.toString()),
                      style: const TextStyle(
                        color: Color(0xFF1E90FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) {
      final v = (n / 1000).toStringAsFixed(1);
      return l.t('shorts.countThousands').replaceAll('%s', v);
    }
    return n.toString();
  }
}
