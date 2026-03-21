import 'package:http/http.dart' as http;

import '../core/api_config.dart';

/// Единая точка HTTP-запросов к Laravel API.
///
/// Импорт в экранах/виджетах:
/// ```dart
/// import 'package:utube_flutter/services/api_service.dart';
///
/// final res = await ApiService.instance.get('videos');
/// ```
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // OPT8: store ETags per URL path to support If-None-Match caching
  final Map<String, String> _etags = {};

  /// GET `GET {baseUrl}/{path}`.
  ///
  /// Automatically adds `If-None-Match` header when we have a stored ETag,
  /// and stores the new ETag from 200 responses for future requests.
  /// Returns null on 304 (Not Modified) — callers should keep using their cache.
  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    var uri = ApiConfig.uri(path);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          ...queryParameters,
        },
      );
    }
    final cacheKey = uri.toString();
    final merged = <String, String>{
      if (headers != null) ...headers,
      if (_etags.containsKey(cacheKey)) 'If-None-Match': _etags[cacheKey]!,
    };
    final res = await http.get(uri, headers: merged.isEmpty ? null : merged);
    if (res.statusCode == 200) {
      final etag = res.headers['etag'];
      if (etag != null && etag.isNotEmpty) {
        _etags[cacheKey] = etag;
      }
    }
    return res;
  }

  /// POST с телом.
  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http.post(
      ApiConfig.uri(path),
      headers: headers,
      body: body,
    );
  }
}
