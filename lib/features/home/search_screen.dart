import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/video_item.dart';
import '../../data/video_repository.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/video_list_item.dart';

/// One entry in search history (query + optional thumbnail for "watched video").
class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.query,
    this.thumbnailUrl,
  });
  final String query;
  final String? thumbnailUrl;
}

/// Full-screen YouTube-style search: black background, back + pill search field + mic,
/// scrollable history/suggestions list (clock icon, text, optional thumbnail, arrow).
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.initialQuery,
    required this.history,
    required this.onSearch,
    required this.onApplyQuery,
    this.onOpenVideo,
  });

  final String initialQuery;
  final List<SearchHistoryEntry> history;
  final void Function(String query) onSearch;
  final void Function(String query) onApplyQuery;
  final void Function(VideoItem)? onOpenVideo;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  List<VideoItem> _results = [];
  bool _hasSearched = false;

  static const _headerBg = Color(0xFF000000);
  static const _fieldBg = Color(0xFF2A2A2A);
  static const _textColor = Color(0xFFFFFFFF);
  static const _hintColor = Color(0xFFAAAAAA);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focusNode = FocusNode();
    VideoRepository.instance.loadFeed().then((_) {
      if (mounted) setState(() {});
    });
    if (widget.initialQuery.isNotEmpty) {
      _runSearch(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    final qLower = q.trim().toLowerCase();
    if (qLower.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    try {
      await VideoRepository.instance.loadFeed();
    } catch (_) {}
    if (!mounted) return;
    final list = VideoRepository.instance.cachedFeed.where((v) {
      return v.title.toLowerCase().contains(qLower) ||
          v.channelName.toLowerCase().contains(qLower);
    }).toList();
    setState(() {
      _results = list;
      _hasSearched = true;
    });
  }

  void _submitQuery(String q) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    widget.onSearch(trimmed);
    _runSearch(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _headerBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, l, isDark),
            Expanded(
              child: _hasSearched || _controller.text.isNotEmpty
                  ? _buildResults(context)
                  : _buildHistoryList(context, l),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l, bool isDark) {
    return Container(
      color: _headerBg,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Symbols.chevron_left_rounded, color: _textColor, size: 28),
            onPressed: () {
              widget.onApplyQuery(_controller.text.trim());
              Navigator.of(context).pop(_controller.text.trim());
            },
          ),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _fieldBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(color: _textColor, fontSize: 16),
                decoration: InputDecoration(
                  hintText: l.t('search.hintYouTube'),
                  hintStyle: const TextStyle(color: _hintColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: _submitQuery,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Symbols.mic_rounded, color: _textColor, size: 26),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.t('search.voiceUnavailable'))),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, AppLocalizations l) {
    if (widget.history.isEmpty) {
      return const Center(
        child: Text(
          '',
          style: TextStyle(color: _hintColor),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.history.length,
      itemBuilder: (context, i) {
        final entry = widget.history[i];
        return Material(
          color: _headerBg,
          child: InkWell(
            onTap: () {
              _controller.text = entry.query;
              _submitQuery(entry.query);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Symbols.history_rounded,
                    color: _hintColor,
                    size: 22,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      entry.query,
                      style: const TextStyle(
                        color: _textColor,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (entry.thumbnailUrl != null) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: entry.thumbnailUrl!,
                        width: 48,
                        height: 36,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(
                          width: 48,
                          height: 36,
                          child: ColoredBox(color: _fieldBg),
                        ),
                        errorWidget: (_, __, ___) => const SizedBox(
                          width: 48,
                          height: 36,
                          child: ColoredBox(color: _fieldBg),
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(
                      Symbols.north_west_rounded,
                      color: _hintColor,
                      size: 20,
                    ),
                    onPressed: () {
                      _controller.text = entry.query;
                      _submitQuery(entry.query);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_results.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).t('search.noResults'),
          style: const TextStyle(color: _hintColor, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final item = _results[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: VideoGridItem(
            video: item,
            onTap: () {
              widget.onSearch(_controller.text.trim());
              widget.onApplyQuery(_controller.text.trim());
              if (widget.onOpenVideo != null) {
                widget.onOpenVideo!(item);
              }
              Navigator.of(context).pop(_controller.text.trim());
            },
          ),
        );
      },
    );
  }
}
