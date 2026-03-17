import 'package:flutter/material.dart';

import '../../data/short_item.dart';

class ShortsScreen extends StatelessWidget {
  const ShortsScreen({
    super.key,
    required this.shorts,
    required this.onOpenShort,
  });

  final List<ShortItem> shorts;
  final Future<void> Function(ShortItem) onOpenShort;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: shorts.length,
        itemBuilder: (context, index) {
          final s = shorts[index];
          return GestureDetector(
            onTap: () => onOpenShort(s),
            child: Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Image.network(
                      s.thumbnailUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 80,
                  child: Column(
                    children: const [
                      Icon(Icons.thumb_up_outlined,
                          color: Colors.white, size: 28),
                      SizedBox(height: 16),
                      Icon(Icons.thumb_down_outlined,
                          color: Colors.white, size: 28),
                      SizedBox(height: 16),
                      Icon(Icons.comment_outlined,
                          color: Colors.white, size: 28),
                      SizedBox(height: 16),
                      Icon(Icons.share_outlined,
                          color: Colors.white, size: 28),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 32,
                  right: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${s.channelName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

