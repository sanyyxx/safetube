import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/video_item.dart';
import '../../data/video_store.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/video_list_item.dart';

// Reuse the existing history model from the current search implementation.
import 'search_screen.dart' show SearchHistoryEntry;

class YouTubeSearchScreen extends StatefulWidget {
  const YouTubeSearchScreen({
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
  State<YouTubeSearchScreen> createState() => _YouTubeSearchScreenState();
}

class _YouTubeSearchScreenState extends State<YouTubeSearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  bool _suggestionsLoading = false;
  List<String> _suggestions = const [];

  int _suggestionRequestId = 0;
  Timer? _debounce;

  static const _headerBg = Color(0xFF000000);
  static const _fieldBg = Color(0xFF2A2A2A);
  static const _textColor = Color(0xFFFFFFFF);
  static const _hintColor = Color(0xFFAAAAAA);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focusNode = FocusNode();

    if (widget.initialQuery.trim().isNotEmpty) {
      _scheduleSuggestions(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;

  void _scheduleSuggestions(String raw) {
    final q = raw.trim();
    _debounce?.cancel();

    if (q.isEmpty) {
      setState(() {
        _suggestionsLoading = false;
        _suggestions = const [];
      });
      return;
    }

    _suggestionRequestId++;
    final requestId = _suggestionRequestId;

    setState(() {
      _suggestionsLoading = true;
      _suggestions = const [];
    });

    _debounce = Timer(const Duration(milliseconds: 220), () async {
      // Local/demo data: still delay a bit so the skeleton is visible
      // and matches YouTube-like behavior.
      await Future<void>.delayed(const Duration(milliseconds: 90));
      if (!mounted || requestId != _suggestionRequestId) return;
      final next = _computeSuggestions(q);
      setState(() {
        _suggestionsLoading = false;
        _suggestions = next;
      });
    });
  }

  List<String> _computeSuggestions(String q) {
    final qLower = q.toLowerCase();
    final seen = <String>{};
    final out = <String>[];

    // 1) Suggestions from history (prefix match).
    for (final entry in widget.history) {
      final h = entry.query.trim();
      if (h.isEmpty) continue;
      final hLower = h.toLowerCase();
      if (hLower.startsWith(qLower)) {
        if (seen.add(h)) out.add(h);
      }
      if (out.length >= 6) return out;
    }

    // 2) Suggestions from demo content (prefix match on title/channel).
    for (final v in demoFeed) {
      final candidates = <String>[v.title, v.channelName];
      for (final candidate in candidates) {
        final c = candidate.trim();
        if (c.isEmpty) continue;
        final cLower = c.toLowerCase();
        if (cLower.startsWith(qLower)) {
          if (seen.add(c)) out.add(c);
        }
        if (out.length >= 8) return out;
      }
    }

    // 3) Fallback: show the query itself (so user always has something to tap).
    if (out.isEmpty) out.add(q);
    return out;
  }

  void _openResults(String q) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;

    widget.onSearch(trimmed);
    widget.onApplyQuery(trimmed);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SearchResultsScreen(
          query: trimmed,
          onOpenVideo: widget.onOpenVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _headerBg : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, l),
            Expanded(
              child: !_hasText ? _buildHistory(context) : _buildSuggestions(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? _headerBg : Colors.white;
    final fieldBg = isDark ? _fieldBg : const Color(0xFFF2F2F2);
    final textColor = isDark ? _textColor : Colors.black87;
    final hintColor = isDark ? _hintColor : const Color(0xFF666666);

    return Container(
      color: headerBg,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Symbols.chevron_left_rounded, color: textColor, size: 28),
            onPressed: () {
              widget.onApplyQuery(_controller.text.trim());
              Navigator.of(context).pop(_controller.text.trim());
            },
          ),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: TextStyle(color: textColor, fontSize: 16),
                decoration: InputDecoration(
                  hintText: l.t('search.hintYouTube'),
                  hintStyle: TextStyle(color: hintColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onChanged: _scheduleSuggestions,
                onSubmitted: _openResults,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Symbols.mic_rounded, color: textColor, size: 26),
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

  Widget _buildHistory(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? _headerBg : Colors.white;
    final textColor = isDark ? _textColor : Colors.black87;
    final hintColor = isDark ? _hintColor : const Color(0xFF666666);

    if (widget.history.isEmpty) {
      return Center(
        child: Text('', style: TextStyle(color: hintColor)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.history.length,
      itemBuilder: (context, i) {
        final entry = widget.history[i];
        return Material(
          color: headerBg,
          child: InkWell(
            onTap: () => _openResults(entry.query),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Symbols.history_rounded, color: hintColor, size: 22),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      entry.query,
                      style: TextStyle(color: textColor, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Symbols.north_west_rounded, color: hintColor, size: 20),
                    onPressed: () => _openResults(entry.query),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? _headerBg : Colors.white;
    final textColor = isDark ? _textColor : Colors.black87;
    final hintColor = isDark ? _hintColor : const Color(0xFF666666);

    if (_suggestionsLoading) {
      return _SearchSuggestionsSkeleton();
    }

    if (_suggestions.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).t('search.noSuggestions'),
          style: TextStyle(color: hintColor),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0x22000000) : const Color(0x22000000)),
      itemBuilder: (context, i) {
        final q = _suggestions[i];
        return Material(
          color: headerBg,
          child: InkWell(
            onTap: () => _openResults(q),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Symbols.search_rounded, color: hintColor, size: 22),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      q,
                      style: TextStyle(color: textColor, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Symbols.chevron_right_rounded, color: hintColor, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchSuggestionsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF242424) : const Color(0xFFEAEAEA);
    const gap = 10.0;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 1),
      itemBuilder: (context, i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: base),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(color: base),
                ),
              ),
              const SizedBox(width: gap),
            ],
          ),
        );
      },
    );
  }
}

class _SearchResultsScreen extends StatefulWidget {
  const _SearchResultsScreen({
    required this.query,
    required this.onOpenVideo,
  });

  final String query;
  final void Function(VideoItem)? onOpenVideo;

  @override
  State<_SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<_SearchResultsScreen> {
  Future<List<VideoItem>> _loadResults() async {
    // Fake a tiny network delay so skeleton is visible.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final qLower = widget.query.toLowerCase();
    return demoFeed.where((v) {
      return v.title.toLowerCase().contains(qLower) ||
          v.channelName.toLowerCase().contains(qLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final text = isDark ? Colors.white : Colors.black87;
    final hint = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    tooltip: AppLocalizations.of(context).t('search.back'),
                    icon: Icon(
                      Symbols.chevron_left_rounded,
                      color: text,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: text,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<VideoItem>>(
                future: _loadResults(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const _ResultsSkeletonList();
                  }
                  final results = snapshot.data!;
                  if (results.isEmpty) {
                    return Center(
                      child: Text(
                        AppLocalizations.of(context).t('search.noResults'),
                        style: TextStyle(color: hint),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final item = results[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: VideoListItem(
                          video: item,
                          onTap: () {
                            widget.onOpenVideo?.call(item);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsSkeletonList extends StatelessWidget {
  const _ResultsSkeletonList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEAEAEA);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 84,
              decoration: BoxDecoration(
                color: base,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ],
        );
      },
    );
  }
}

