import 'video_item.dart';

class ShortItem {
  const ShortItem({
    this.id,
    required this.playbackUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.channelName,
    required this.likesText,
  });

  final String? id;

  final String playbackUrl;
  final String thumbnailUrl;
  final String title;
  final String channelName;
  final String likesText;

  /// Собирает шорт из уже распарсенного [VideoItem] + сырых полей лайков из JSON.
  factory ShortItem.fromVideoJson(Map<String, dynamic> json, VideoItem v) {
    String pickLikes() {
      for (final k in [
        'likes_text',
        'likesText',
        'likes',
        'like_count',
        'likeCount',
      ]) {
        final x = json[k];
        if (x != null && x.toString().trim().isNotEmpty) {
          return x.toString().trim();
        }
      }
      return '';
    }

    final likes = pickLikes();
    return ShortItem(
      id: v.id,
      playbackUrl: v.playbackUrl,
      thumbnailUrl: v.thumbnailUrl,
      title: v.title,
      channelName: v.channelName,
      likesText: likes.isEmpty ? '0' : likes,
    );
  }

  VideoItem toVideoItem() {
    return VideoItem(
      id: id,
      playbackUrl: playbackUrl,
      thumbnailUrl: thumbnailUrl,
      title: title,
      channelName: channelName,
      viewsText: '$likesText likes',
      publishedText: 'Shorts',
    );
  }
}

