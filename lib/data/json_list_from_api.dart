/// Вытаскивает список объектов из типичных ответов Laravel / JSON API.
List<dynamic> extractJsonObjectList(dynamic decoded) {
  if (decoded is List) return decoded;
  if (decoded is Map) {
    final map = Map<String, dynamic>.from(decoded);
    final data = map['data'];
    if (data is List) return data;
    if (data is Map) {
      final inner = Map<String, dynamic>.from(data)['data'];
      if (inner is List) return inner;
      final inner2 = extractJsonObjectList(data);
      if (inner2.isNotEmpty) return inner2;
    }
    final videos = map['videos'];
    if (videos is List) return videos;
    final shorts = map['shorts'];
    if (shorts is List) return shorts;
    final result = map['result'];
    if (result is List) return result;
    if (result is Map) {
      final r2 = extractJsonObjectList(result);
      if (r2.isNotEmpty) return r2;
    }
    final items = map['items'];
    if (items is List) return items;
    if (map['success'] == true && data is Map) {
      return extractJsonObjectList(data);
    }
  }
  return const [];
}
