/// Базовый URL бэкенда (Laravel API).
///
/// Переопределение при сборке:
/// ```bash
/// flutter build web --release --no-web-resources-cdn --base-href /app/ \
///   --dart-define=API_BASE_URL=https://youtube.esl.kz/api/v1
/// ```
abstract final class ApiConfig {
  ApiConfig._();

  /// Корень REST API (без завершающего `/`).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://youtube.esl.kz/api/v1',
  );

  /// Полный [Uri] для пути вида `videos` или `/videos`.
  static Uri uri(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$base/$p');
  }
}
