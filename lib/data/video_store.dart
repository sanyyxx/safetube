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
    title: 'Bee video',
    channelName: 'Channel',
    viewsText: '1.2M views',
    publishedText: '2 days ago',
  ),
  VideoItem(
    playbackUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    thumbnailUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl-2.jpg',
    title: 'Cat on keyboard',
    channelName: 'Cat Studio',
    viewsText: '540K views',
    publishedText: '1 week ago',
  ),
  VideoItem(
    playbackUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    thumbnailUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl-3.jpg',
    title: 'Neon city vibes',
    channelName: 'Night Lens',
    viewsText: '2.3M views',
    publishedText: '3 weeks ago',
  ),
];

