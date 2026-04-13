import '../core/api_config.dart';

class VideoItem {
  const VideoItem({
    this.id,
    required this.playbackUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.channelName,
    this.channelSlug,
    required this.viewsText,
    required this.publishedText,
    this.durationText,
  });

  /// ID с бэкенда (если есть).
  final String? id;

  /// Direct media URL (mp4/hls) that we control (admin-provided).
  final String playbackUrl;

  /// Thumbnail URL (admin-provided).
  final String thumbnailUrl;

  final String title;
  final String channelName;

  /// Slug канала с API (`channel.slug`), для фильтра `?channel=`; у старых видео может быть `null`.
  final String? channelSlug;

  final String viewsText;
  final String publishedText;

  /// Duration shown on thumbnail, e.g. "6:03".
  final String? durationText;

  /// Подмешивает `attributes`, массив `media` (Spatie) и т.п. в «плоский» вид для pick().
  static Map<String, dynamic> _mergeLaravelFields(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);

    final attrs = raw['attributes'];
    if (attrs is Map) {
      Map<String, dynamic>.from(attrs).forEach((k, v) {
        final ex = m[k];
        if (ex == null || ex.toString().trim().isEmpty) {
          m[k] = v;
        }
      });
    }

    void applyMediaMap(Map<String, dynamic> fm) {
      bool needPlayback() {
        final p = m['playback_url'] ?? m['playbackUrl'] ?? m['video_url'];
        return p == null || p.toString().trim().isEmpty;
      }

      bool needThumb() {
        final t = m['thumbnail_url'] ?? m['thumbnailUrl'];
        return t == null || t.toString().trim().isEmpty;
      }

      if (needPlayback()) {
        for (final fk in <String>[
          'original_url',
          'full_url',
          'url',
          'path',
        ]) {
          final v = fm[fk];
          if (v != null && v.toString().trim().isNotEmpty) {
            m['playback_url'] = v;
            break;
          }
        }
      }
      if (needThumb()) {
        for (final fk in <String>['preview_url', 'thumb_url', 'url']) {
          final v = fm[fk];
          if (v != null && v.toString().trim().isNotEmpty) {
            m['thumbnail_url'] = v;
            break;
          }
        }
      }
    }

    final media = raw['media'];
    if (media is List) {
      for (final item in media) {
        if (item is Map) {
          applyMediaMap(Map<String, dynamic>.from(item));
          break;
        }
      }
    }

    final rel = raw['relationships'];
    if (rel is Map) {
      final mediaRel = rel['media'];
      if (mediaRel is Map) {
        final d = mediaRel['data'];
        if (d is List) {
          for (final item in d) {
            if (item is Map) {
              final im = Map<String, dynamic>.from(item);
              if (im['attributes'] is Map) {
                applyMediaMap(
                  Map<String, dynamic>.from(im['attributes'] as Map),
                );
              } else {
                applyMediaMap(im);
              }
              break;
            }
          }
        }
      }
    }

    return m;
  }

  /// Парсинг JSON из Laravel API (`snake_case` или `camelCase`).
  factory VideoItem.fromJson(Map<String, dynamic> raw) {
    final json = _mergeLaravelFields(Map<String, dynamic>.from(raw));
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    // Вложенные объекты Laravel (media, file, video)
    Map<String, dynamic>? nestedMap(dynamic key) {
      final v = json[key];
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    String pickNested(List<String> topKeys, List<String> leafKeys) {
      for (final top in topKeys) {
        final m = nestedMap(top);
        if (m == null) continue;
        for (final k in leafKeys) {
          final v = m[k];
          if (v != null && v.toString().trim().isNotEmpty) {
            return v.toString().trim();
          }
        }
      }
      return '';
    }

    // JSON:API style attributes { "attributes": { "playback_url": "..." } }
    final attributes = nestedMap('attributes');
    String pickAttr(List<String> leafKeys) {
      if (attributes == null) return '';
      for (final k in leafKeys) {
        final v = attributes[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    String resolveMediaUrl(String raw) {
      final s = raw.trim();
      if (s.isEmpty) return '';
      if (s.startsWith('http://') || s.startsWith('https://')) return s;
      if (s.startsWith('//')) return 'https:$s';
      final base = Uri.parse(ApiConfig.baseUrl);
      final origin = base.hasPort
          ? '${base.scheme}://${base.host}:${base.port}'
          : '${base.scheme}://${base.host}';
      if (s.startsWith('/')) return '$origin$s';
      return '$origin/$s';
    }

    final idRaw = json['id'] ?? json['uuid'];

    var playbackRaw = pick([
      'playback_url',
      'playbackUrl',
      'video_url',
      'videoUrl',
      'source_url',
      'sourceUrl',
      'media_url',
      'mediaUrl',
      'file_url',
      'fileUrl',
      'stream_url',
      'streamUrl',
      'hls_url',
      'hlsUrl',
      'url',
    ]);
    if (playbackRaw.isEmpty) {
      playbackRaw = pickNested(['media', 'file', 'video'], [
        'url',
        'playback_url',
        'path',
        'original_url',
      ]);
    }
    if (playbackRaw.isEmpty) {
      playbackRaw = pickAttr([
        'playback_url',
        'playbackUrl',
        'video_url',
        'url',
      ]);
    }

    var thumbRaw = pick([
      'thumbnail_url',
      'thumbnailUrl',
      'thumb_url',
      'thumbUrl',
      'poster_url',
      'posterUrl',
      'cover_url',
      'coverUrl',
    ]);
    if (thumbRaw.isEmpty) {
      thumbRaw = pickNested(['media', 'thumbnail', 'video'], [
        'url',
        'thumbnail_url',
        'path',
      ]);
    }
    if (thumbRaw.isEmpty) {
      thumbRaw = pickAttr([
        'thumbnail_url',
        'thumbnailUrl',
      ]);
    }

    String? channelSlugOut;
    String channelNameOut = '';

    String pickFromMap(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    void applyChannelMap(Map<String, dynamic> rawCh) {
      final attrs = rawCh['attributes'];
      if (attrs is Map) {
        final am = Map<String, dynamic>.from(attrs);
        if (channelNameOut.isEmpty) {
          channelNameOut = pickFromMap(am, ['name', 'title', 'label']);
        }
        final s = am['slug'];
        if (s != null && s.toString().trim().isNotEmpty) {
          channelSlugOut = s.toString().trim();
        }
      }
      if (channelNameOut.isEmpty) {
        channelNameOut = pickFromMap(rawCh, ['name', 'title', 'label']);
      }
      if (channelSlugOut == null) {
        final s = rawCh['slug'];
        if (s != null && s.toString().trim().isNotEmpty) {
          channelSlugOut = s.toString().trim();
        }
      }
    }

    final chRaw = json['channel'];
    if (chRaw is String) {
      channelNameOut = chRaw.trim();
    } else if (chRaw is Map) {
      applyChannelMap(Map<String, dynamic>.from(chRaw));
    }

    final rel = json['relationships'];
    if (rel is Map) {
      final chRel = rel['channel'];
      if (chRel is Map) {
        final inc = chRel['data'];
        if (inc is Map &&
            (channelNameOut.isEmpty || channelSlugOut == null)) {
          applyChannelMap(Map<String, dynamic>.from(inc));
        }
      }
    }

    if (channelNameOut.isEmpty) {
      channelNameOut = pick([
        'channel_name',
        'channelName',
        'author',
      ]);
    }

    return VideoItem(
      id: idRaw?.toString(),
      playbackUrl: resolveMediaUrl(playbackRaw),
      thumbnailUrl: thumbRaw.isEmpty ? '' : resolveMediaUrl(thumbRaw),
      title: pick(['title', 'name']),
      channelName: channelNameOut,
      channelSlug: channelSlugOut,
      viewsText: pick([
        'views_text',
        'viewsText',
        'views',
      ]),
      publishedText: pick([
        'published_text',
        'publishedText',
        'published_at',
        'publishedAt',
      ]),
      durationText: () {
        final d = pick(['duration_text', 'durationText', 'duration']);
        return d.isEmpty ? null : d;
      }(),
    );
  }

  bool get isValidForPlayback {
    final u = playbackUrl.trim();
    return u.startsWith('http://') || u.startsWith('https://');
  }
}
