import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'json_list_from_api.dart';
import 'short_item.dart';
import 'video_item.dart';

/// Шортсы с Laravel API (`GET /api/v1/shorts` по умолчанию).
///
/// Формат — см. [docs/API_SHORTS.md](../docs/API_SHORTS.md).
class ShortRepository {
  ShortRepository._();
  static final ShortRepository instance = ShortRepository._();

  List<ShortItem> _list = [];
  String? _lastError;
  Future<List<ShortItem>>? _inFlight;

  // OPT10: notifier fires when shorts list is updated
  final ValueNotifier<List<ShortItem>> shortsNotifier = ValueNotifier([]);

  List<ShortItem> get cachedShorts => List.unmodifiable(_list);

  String? get lastError => _lastError;

  Future<List<ShortItem>> loadShorts({bool force = false}) async {
    if (_list.isNotEmpty && !force) return _list;
    if (_inFlight != null && !force) return _inFlight!;

    _lastError = null;
    Future<List<ShortItem>> run() async {
      final res = await ApiService.instance.get(
        'shorts',
        headers: {'Accept': 'application/json'},
        queryParameters: {'per_page': '100'},
      );

      // OPT8: 304 Not Modified — cache is still valid
      if (res.statusCode == 304) return _list;

      if (res.statusCode < 200 || res.statusCode >= 300) {
        _lastError = 'HTTP ${res.statusCode}';
        throw Exception(_lastError);
      }

      final decoded = jsonDecode(res.body);
      final raw = extractJsonObjectList(decoded);
      final items = <ShortItem>[];

      for (final e in raw) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        final v = VideoItem.fromJson(map);
        if (!v.isValidForPlayback) continue;
        items.add(ShortItem.fromVideoJson(map, v));
      }

      if (kDebugMode && items.isEmpty && raw.isNotEmpty) {
        debugPrint(
          'ShortRepository: с API пришло ${raw.length} объект(ов), но ни один не имеет '
          'валидного URL воспроизведения. Проверьте GET .../shorts.',
        );
      }

      _list = items;
      shortsNotifier.value = List.unmodifiable(_list); // OPT10
      return _list;
    }

    _inFlight = run();
    try {
      return await _inFlight!;
    } finally {
      _inFlight = null;
    }
  }

  void clearCache() {
    _list = [];
    _lastError = null;
  }
}
