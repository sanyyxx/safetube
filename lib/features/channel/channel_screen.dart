import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/json_list_from_api.dart';
import '../../data/video_item.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../home/widgets/video_list_item.dart';

class ChannelScreen extends StatefulWidget {
  const ChannelScreen({
    super.key,
    required this.channelSlug,
    required this.channelName,
    required this.onOpenVideo,
  });

  final String channelSlug;
  final String channelName;
  final Future<void> Function(VideoItem) onOpenVideo;

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  bool _loading = true;
  String? _error;
  List<VideoItem> _videos = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.instance.get(
        'videos',
        headers: {'Accept': 'application/json'},
        queryParameters: {
          'per_page': '100',
          'channel': widget.channelSlug,
        },
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final decoded = jsonDecode(res.body);
      final raw = extractJsonObjectList(decoded);
      final out = <VideoItem>[];
      for (final e in raw) {
        if (e is! Map) continue;
        final item = VideoItem.fromJson(Map<String, dynamic>.from(e));
        if (item.isValidForPlayback) out.add(item);
      }
      if (!mounted) return;
      setState(() {
        _videos = out;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = widget.channelName.isNotEmpty
        ? widget.channelName
        : widget.channelSlug;
    final avatar = title.isNotEmpty ? title.characters.first.toUpperCase() : '?';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final banner = isDark ? const Color(0xFF1A2B3D) : const Color(0xFFD8E8FF);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(title),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 110, color: banner),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 32, child: Text(avatar)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text('@${widget.channelSlug}'),
                            const SizedBox(height: 2),
                            Text(
                              l
                                  .t('channel.videoCount')
                                  .replaceAll('%s', '${_videos.length}'),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () {},
                        child: Text(l.t('shorts.subscribe')),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ),
            )
          else if (_videos.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(l.t('channel.empty'))),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: VideoListItem(
                    video: _videos[i],
                    onTap: () => widget.onOpenVideo(_videos[i]),
                  ),
                ),
                childCount: _videos.length,
              ),
            ),
        ],
      ),
    );
  }
}
