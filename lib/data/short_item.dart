import 'video_item.dart';

class ShortItem {
  const ShortItem({
    required this.playbackUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.channelName,
    required this.likesText,
  });

  final String playbackUrl;
  final String thumbnailUrl;
  final String title;
  final String channelName;
  final String likesText;

  VideoItem toVideoItem() {
    return VideoItem(
      playbackUrl: playbackUrl,
      thumbnailUrl: thumbnailUrl,
      title: title,
      channelName: channelName,
      viewsText: '$likesText likes',
      publishedText: 'Shorts',
    );
  }
}

