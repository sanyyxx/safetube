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

    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(context, l),
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: widget.comments.length,
              itemBuilder: (context, i) => _CommentTile(comment: widget.comments[i], l: l),
            ),
          ),
          _buildInput(context, l),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: _textSecondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '${l.t('shorts.commentsTitle')} ${widget.commentCount}',
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Symbols.tune_rounded, color: _textPrimary, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.t('shorts.filterComments'))),
              );
            },
          ),
          IconButton(
            icon: const Icon(Symbols.close_rounded, color: _textPrimary, size: 24),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context, AppLocalizations l) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      color: _bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _inputBg,
            child: const Icon(Symbols.person_rounded, color: _textSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocus,
              style: const TextStyle(color: _textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: l.t('shorts.commentPlaceholder'),
                hintStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _inputBg,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF2A2A2A),
            backgroundImage: comment.authorAvatarUrl != null
                ? NetworkImage(comment.authorAvatarUrl!)
                : null,
            child: comment.authorAvatarUrl == null
                ? const Icon(Symbols.person_rounded, color: _textSecondary, size: 22)
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
                        const Icon(Symbols.push_pin_rounded, size: 14, color: _textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${l.t('shorts.pinnedBy')} ${comment.pinnedByHandle}',
                          style: const TextStyle(
                            color: _textSecondary,
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
                      style: const TextStyle(
                        color: _textPrimary,
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
                      style: const TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Symbols.more_vert_rounded, color: _textSecondary, size: 20),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: const TextStyle(color: _textPrimary, fontSize: 14, height: 1.3),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Symbols.thumb_up_rounded, size: 18, color: _textSecondary),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                    ),
                    if (comment.likeCount > 0)
                      Text(
                        _formatCount(comment.likeCount),
                        style: const TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Symbols.thumb_down_rounded, size: 18, color: _textSecondary),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Symbols.reply_rounded, size: 18, color: _textSecondary),
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
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)} тыс.';
    return n.toString();
  }
}
