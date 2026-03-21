# Деплой Flutter Web на `https://youtube.esl.kz/app/`

## 1. Базовый URL API (Flutter)

В коде: [`lib/core/api_config.dart`](../lib/core/api_config.dart) — `ApiConfig.baseUrl` по умолчанию **`https://youtube.esl.kz/api/v1`**.

Сборка с другим API (опционально):

```bash
flutter build web --release --no-web-resources-cdn --base-href /app/ \
  --dart-define=API_BASE_URL=https://youtube.esl.kz/api/v1
```

Использование в коде:

```dart
import 'package:utube_flutter/core/api_config.dart';

final url = ApiConfig.uri('videos'); // или 'videos/123'
// http.get(url), dio.getUri(url), и т.д.
```

## 2. Сборка под подпапку `/app/`

Из корня проекта:

```bash
flutter build web --release --no-web-resources-cdn --base-href /app/
```

Сборка попадает в **`build/web/`**.

## 3. Заливка на сервер (Laravel)

Содержимое **`build/web/`** целиком в **`public/app/`** на сервере:

```text
/var/www/youtube.esl.kz/public/app/index.html
/var/www/youtube.esl.kz/public/app/main.dart.js
/var/www/youtube.esl.kz/public/app/assets/...
...
```

Пример (scp с локальной машины):

```bash
scp -r build/web/* user@server:/var/www/youtube.esl.kz/public/app/
```

Открытие в браузере: **`https://youtube.esl.kz/app/`**

## 4. CORS (если браузер блокирует запросы к API)

Веб-приложение с `https://youtube.esl.kz/app/` обращается к `https://youtube.esl.kz/api/v1` — тот же origin по домену, но путь **разный** (`/app` vs `/api`), браузер считает это **cross-origin** и применяет CORS.

Нужно на Laravel разрешить origin фронта и методы/заголовки.

### `config/cors.php` (пример)

```php
'paths' => ['api/*', 'sanctum/csrf-cookie'],

'allowed_origins' => [
    'https://youtube.esl.kz',
],

'allowed_origins_patterns' => [],

'allowed_methods' => ['*'],

'allowed_headers' => ['*'],

'exposed_headers' => [],

'max_age' => 0,

'supports_credentials' => true,
```

При необходимости добавьте в `allowed_origins` точный URL с `/app/` (обычно достаточно схемы + хоста).

### Заголовки ответа API

Убедитесь, что ответы с API возвращают, например:

- `Access-Control-Allow-Origin: https://youtube.esl.kz`
- при `supports_credentials: true` — нельзя использовать `*` в Origin, нужен конкретный origin.

Пакет **`fruitcake/laravel-cors`** (или встроенный CORS в Laravel 11+) обычно уже есть — проверьте `config/cors.php` и `middleware` в `bootstrap/app.php` или `Kernel.php`.

## 5. Nginx (если отдаётся статика)

Для SPA Flutter в подпапке часто нужен fallback на `index.html`:

```nginx
location /app/ {
    alias /var/www/youtube.esl.kz/public/app/;
    try_files $uri $uri/ /app/index.html;
}
```

Точная конфигурация зависит от вашего текущего `server { }`.

---

## 6. Ошибка: `manifest.json` 404, «Manifest fetch … failed»

**Симптом:** в консоли браузера запрос к `https://youtube.esl.kz/manifest.json` (корень сайта), а приложение лежит в **`/app/`**.

**Почему:** в `index.html` стоит `<base href="/">`. Относительные ссылки (`manifest.json`, `flutter_bootstrap.js`, `main.dart.js`, иконки) считаются от **корня** домена, а не от `/app/`, поэтому браузер ищет файлы не там.

**Что сделать:** пересобрать с базой под подпапку и снова залить **`build/web/`** в `public/app/`:

```bash
flutter build web --release --no-web-resources-cdn --base-href /app/
```

После сборки в `build/web/index.html` должно быть **` <base href="/app/">`**, а `manifest.json` будет открываться как **`https://youtube.esl.kz/app/manifest.json`**.

**Не** кладите только один `index.html` без остальных файлов из `build/web/` — нужны все артефакты сборки.
