import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'json_list_from_api.dart';
import 'video_item.dart';

/// Лента видео с Laravel API (`GET /api/v1/videos` по умолчанию).
///
/// Формат ответа — см. [docs/API_VIDEOS.md](../docs/API_VIDEOS.md).
class VideoRepository {
  VideoRepository._();
  static final VideoRepository instance = VideoRepository._();

  List<VideoItem> _feed = [];
  String? _lastError;
  Future<List<VideoItem>>? _inFlight;

  /// Текущий фильтр ленты по slug канала (`?channel=`), `null` — все видео.
  String? _activeChannelSlug;

  int _loadGeneration = 0;

  // OPT10: notifier fires when the feed is updated so widgets can react
  // without going through a full HomeShell rebuild.
  final ValueNotifier<List<VideoItem>> feedNotifier = ValueNotifier([]);

  List<VideoItem> get cachedFeed => List.unmodifiable(_feed);

  String? get lastError => _lastError;

  String? get activeChannelSlug => _activeChannelSlug;

  /// Загрузить ленту. Повторный вызов без [force] вернёт кэш без запроса.
  ///
  /// [channelSlug] — фильтр API по slug канала (как `GET .../videos?channel=slug`).
  Future<List<VideoItem>> loadFeed({
    bool force = false,
    String? channelSlug,
  }) async {
    final slug = channelSlug?.trim();
    final normalized = (slug == null || slug.isEmpty) ? null : slug;
    final sameFilter = _activeChannelSlug == normalized;
    if (_feed.isNotEmpty && !force && sameFilter) return _feed;
    if (_inFlight != null && !force && sameFilter) return _inFlight!;

    _lastError = null;
    Future<List<VideoItem>> run() async {
      final gen = ++_loadGeneration;
      final res = await ApiService.instance.get(
        'videos',
        headers: {'Accept': 'application/json'},
        queryParameters: {
          'per_page': '100',
          if (normalized != null) 'channel': normalized,
        },
      );

      if (gen != _loadGeneration) {
        return _feed;
      }

      // OPT8: 304 Not Modified — cache is still valid
      if (res.statusCode == 304) return _feed;

      if (res.statusCode < 200 || res.statusCode >= 300) {
        _lastError = 'HTTP ${res.statusCode}';
        throw Exception(_lastError);
      }

      final decoded = jsonDecode(res.body);
      final raw = extractJsonObjectList(decoded);
      final items = <VideoItem>[];

      for (final e in raw) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        final item = VideoItem.fromJson(map);
        if (item.isValidForPlayback) {
          items.add(item);
        }
      }

      if (kDebugMode && items.isEmpty && raw.isNotEmpty) {
        debugPrint(
          'VideoRepository: с API пришло ${raw.length} объект(ов), но ни один не имеет '
          'валидного URL воспроизведения (https?:// или относительный путь к файлу). '
          'Проверьте JSON в GET .../videos (поля playback_url, media[].url и т.д.).',
        );
      }

      if (gen != _loadGeneration) {
        return _feed;
      }

      _activeChannelSlug = normalized;
      _feed = items;
      feedNotifier.value = List.unmodifiable(_feed); // OPT10: notify listeners
      return _feed;
    }

    _inFlight = run();
    try {
      return await _inFlight!;
    } finally {
      _inFlight = null;
    }
  }

  void clearCache() {
    _feed = [];
    _lastError = null;
    _activeChannelSlug = null;
  }
}
