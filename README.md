## utubeFlutter

Flutter-версия проекта `Youtube-Clone` (Splash → Home-лента + экран просмотра с YouTube-плеером + нижняя навигация).

### Что реализовано (1:1 по поведению)
- **Splash**: экран с иконкой YouTube, авто-переход через 3 секунды.
- **Home**:
  - верхняя панель: YouTube + кнопки Cast / Notifications / Search / Profile
  - горизонтальная “лента” чипов (Explore + категории + SEND FEEDBACK)
- **Лента видео без API**: сейчас это локальный список (как заглушка под будущую админку).
- **Player**: экран просмотра видео с **YouTube iframe плеером** (контролы и UX как в современном YouTube).
- **Bottom navigation**: Home / Shorts / Publish / Subscriptions / Library (как в оригинале; остальные вкладки — заглушки).
- **Доступность**: добавлены базовые `Semantics`/tooltips для кнопок и карточек.

### Важно про генерацию платформенных папок
В этой папке добавлен готовый `lib/` и `pubspec.yaml`. Если у вас ещё нет стандартных папок Flutter (`android/`, `ios/`, и т.д.), создайте их командой:

```bash
flutter create .
```

Если `flutter create` перезапишет `lib/` — просто восстановите `lib/` из текущего состояния (в этом репозитории/папке).

**Подробно: как запустить и что доделать для использования — см. [USAGE.md](USAGE.md).**

### Сервер для Web: авто-пересборка и обновление в браузере

Чтобы не запускать каждый раз `flutter run -d chrome`, можно поднять локальный сервер: он соберёт проект, раздаст `build/web`, и при изменениях в `lib/` или `pubspec` пересоберёт — остаётся только обновить вкладку в браузере.

1. Установи зависимости (один раз):
   ```bash
   pip install -r scripts/requirements.txt
   ```
2. Из корня проекта:
   ```bash
   python scripts/serve_web.py
   ```
   По умолчанию сервер на http://localhost:8080. Открой этот адрес в браузере. После правок в коде — просто обнови страницу (F5).

   Опции: `--port 9000` (другой порт), `--no-watch` (только сервер, без слежения за файлами), `--no-build` (не собирать при старте, если `build/web` уже есть).

#### Белый экран в браузере

1. **Не открывай `index.html` двойным щелчком** — нужен HTTP-сервер (`python scripts/serve_web.py` или `python -m http.server` из папки `build/web`).
2. По умолчанию Flutter тянет **CanvasKit с CDN** (`gstatic.com`). Если сеть/фаервол блокирует CDN — приложение не стартует (белый экран). Скрипт `serve_web.py` собирает с **`--no-web-resources-cdn`** (CanvasKit лежит в `build/web/canvaskit/`). Вручную: `flutter build web --no-web-resources-cdn`.
3. Сделай **жёсткое обновление** страницы (Ctrl+F5) или очисти данные сайта — старый **service worker** мог закэшировать сломанную сборку.

### API и продакшен (`/app/` на сервере)

- Базовый URL API задаётся в **`lib/core/api_config.dart`** (по умолчанию `https://youtube.esl.kz/api/v1`), при сборке можно переопределить: `--dart-define=API_BASE_URL=...`
- Полная инструкция: **[docs/DEPLOY_HOSTING.md](docs/DEPLOY_HOSTING.md)** (сборка с `--base-href /app/`, заливка в `public/app/`, CORS для Laravel, nginx).
- **Пошагово «куда что и как»:** **[docs/STEP_BY_STEP.md](docs/STEP_BY_STEP.md)**

