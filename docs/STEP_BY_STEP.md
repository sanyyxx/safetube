# Пошагово: API, сборка, заливка на хостинг

## Часть A — Flutter (куда какие файлы)

### Шаг 1. Уже есть в проекте

| Файл | Зачем |
|------|--------|
| `lib/core/api_config.dart` | Базовый URL API: `https://youtube.esl.kz/api/v1` и хелпер `ApiConfig.uri('путь')` |
| `lib/services/api_service.dart` | Один класс `ApiService.instance` — все GET/POST через него |

### Шаг 2. Зависимость `http`

В `pubspec.yaml` уже добавлен пакет **`http`**. После клонирования репозитория один раз:

```bash
flutter pub get
```

### Шаг 3. Как вызывать API из экрана

1. Открой нужный файл, например `lib/features/home/home_screen.dart`.
2. Вверху файла добавь импорт:

```dart
import 'package:utube_flutter/services/api_service.dart';
```

3. Внутри `StatefulWidget` / `async` метода:

```dart
try {
  final response = await ApiService.instance.get('videos');
  if (response.statusCode == 200) {
    // разбор response.body (JSON)
  }
} catch (e) {
  // сеть / ошибка
}
```

Путь **`videos`** превратится в полный URL:  
`https://youtube.esl.kz/api/v1/videos`  
(без дублирования базы в каждом экране).

### Шаг 4. Другой URL API без правки кода

Сборка с переопределением:

```bash
flutter build web --release --no-web-resources-cdn --base-href /app/ ^
  --dart-define=API_BASE_URL=https://другой-домен/api/v1
```

(В PowerShell многострочно можно через `` ` `` или одной строкой.)

---

## Часть B — Сборка веба под `/app/`

В папке проекта (где `pubspec.yaml`):

```bash
cd путь\к\utube_kids_fr
flutter pub get
flutter build web --release --no-web-resources-cdn --base-href /app/
```

Результат: папка **`build/web/`** — её целиком отдаём на сервер.

---

## Часть C — Заливка на сервер (Laravel)

### Шаг 1. Куда копировать

На сервере корень сайта для статики — обычно **`public/`**.  
Flutter кладём в подпапку **`app`**:

| На твоём ПК | На сервере |
|-------------|------------|
| всё из `build/web/` | `/var/www/youtube.esl.kz/public/app/` |

Должно получиться, например:

- `/var/www/youtube.esl.kz/public/app/index.html`
- `/var/www/youtube.esl.kz/public/app/main.dart.js`
- `/var/www/youtube.esl.kz/public/app/assets/...`
- и т.д.

### Шаг 2. Как скопировать (пример SCP)

С **Windows** (PowerShell), из папки проекта:

```powershell
scp -r build/web/* user@youtube.esl.kz:/var/www/youtube.esl.kz/public/app/
```

`user` — твой SSH-пользователь. Путь на сервере поправь, если другой.

### Шаг 3. Открыть в браузере

**`https://youtube.esl.kz/app/`**  
(именно с `/app/` в конце — под это и собран `--base-href /app/`).

---

## Часть D — Если браузер ругается на CORS

Фронт: `https://youtube.esl.kz/app/`  
API: `https://youtube.esl.kz/api/v1/...`  

Разные пути — браузер проверяет CORS. На **Laravel** в `config/cors.php` укажи origin:

```php
'allowed_origins' => ['https://youtube.esl.kz'],
```

Подробнее — в **`docs/DEPLOY_HOSTING.md`**.

---

## Часть E — Видео в админке есть, в приложении пусто

Готовый пример контроллера/Resource для Laravel (скопировать на сервер): **`docs/LARAVEL_VIDEOS_API_EXAMPLE.md`**.

1. Открой в браузере **`https://youtube.esl.kz/api/v1/videos?per_page=100`** — в JSON должны быть **объекты с URL файла** (`playback_url`, или вложенное `media`, или только в `attributes` — клиент это теперь понимает).
2. Если массив `data` пустой — проблема на **бэкенде** (статус «черновик», фильтр, другая таблица).
3. Если объекты есть, но в приложении пусто — в **Chrome → F12 → Console** (режим **debug** сборки) может быть сообщение `VideoRepository: с API пришло N объектов…` — значит в JSON **нет распознаваемого URL** воспроизведения.
4. После загрузки нового ролика сделай **потягивание ленты вниз** (обновление) — кэш клиента иначе может показывать старый список.

Подробнее по полям — **`docs/API_VIDEOS.md`**.

---

## Краткая схема

```
lib/core/api_config.dart     → базовый URL (один раз настроен)
lib/services/api_service.dart → все запросы отсюда
lib/features/.../xxx_screen.dart → import ApiService + await get('...')
build/web/                   → после flutter build web …
public/app/ на сервере       → сюда копируешь содержимое build/web/
https://youtube.esl.kz/app/ → открываешь сайт
```
