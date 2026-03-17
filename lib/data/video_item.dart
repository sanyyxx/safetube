class VideoItem {
  const VideoItem({
    required this.playbackUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.channelName,
    required this.viewsText,
    required this.publishedText,
  });

  /// Direct media URL (mp4/hls) that we control (admin-provided).
  final String playbackUrl;

  /// Thumbnail URL (admin-provided).
  final String thumbnailUrl;

  final String title;
  final String channelName;
  final String viewsText;
  final String publishedText;
}
