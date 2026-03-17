import 'video_item.dart';

/// Temporary in-app feed data.
///
/// Later this will be replaced by admin-loaded items.
const demoFeed = <VideoItem>[
  VideoItem(
    playbackUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    thumbnailUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg',
    title: 'Demo video (admin link placeholder)',
    channelName: 'Channel',
    viewsText: '1.2M views',
    publishedText: '2 days ago',
  ),
];

