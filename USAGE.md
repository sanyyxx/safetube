# Что нужно для использования приложения

## 1. Запуск (уже можно пользоваться)

### Вариант A: Web в браузере (рекомендуется)

1. **Flutter через Puro** (если ещё не установлено):
   ```powershell
   winget install -e --id pingbird.Puro --accept-source-agreements --accept-package-agreements
   ```
2. **Включи режим разработчика Windows** (для symlink):  
   Параметры → Конфиденциальность и безопасность → Для разработчиков → Режим разработчика — Вкл.

3. **В папке проекта:**
   ```powershell
   cd c:\Users\sany\Desktop\utube\utube_kids_fr
   & "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" create stable
   & "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" use stable
   & "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" flutter pub get
   & "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" flutter build web --debug
   ```
4. **Раздать папку сборки:**
   ```powershell
   cd build\web
   python -m http.server 8080
   ```
5. Открыть в браузере: **http://localhost:8080**

### Вариант B: Chrome через Flutter (если нет ошибки SDK)

```powershell
puro flutter run -d chrome
```
(После добавления `puro` в PATH или из папки, где он установлен.)

### Вариант C: Android / iOS / Windows

```powershell
puro flutter run -d windows
puro flutter run -d <device_id>
```

---

## 2. Что уже работает «из коробки»

- Splash, Home, Shorts, Publish, Subscriptions, Library — все экраны открываются.
- Поиск и фильтры на главной (по локальному списку).
- Просмотр видео в плеере (пауза, перемотка, полноэкран, мини-плеер).
- Шортсы: вертикальная лента, свайп, автопроигрывание, пауза по тапу.
- Настройки темы (Light / System / Dark) в профиле.
- Кнопки обратной связи, уведомлений, Cast и т.д. показывают сообщения или диалоги.

---

## 3. Что нужно сделать для «полноценного» использования

| Задача | Сейчас | Что нужно |
|--------|--------|-----------|
| **Контент (видео и шортсы)** | Один демо-ролик + 2 шортса с одного URL | Подключить свой источник: API (YouTube Data API v3, свой бэкенд) или загрузка списка из админки/файла. Обновить `video_store.dart` и `short_store.dart` (или заменить на запросы к API). |
| **Cast (трансляция на ТВ)** | SnackBar «не настроено» | Интеграция с Chromecast SDK (например `flutter_cast`) или аналог. |
| **Уведомления** | Заглушка | Push-уведомления (Firebase Cloud Messaging и т.п.) или свой сервер. |
| **Реальные подписки** | Демо-список каналов | Хранить подписки пользователя (локально или в аккаунте на бэкенде) и подтягивать ленту по ним. |
| **Загрузка видео офлайн** | SnackBar «не реализовано» | Сохранение файла через `video_player` + разрешения на запись, либо плагин для скачивания. |
| **Плейлисты / Watch later / History** | Только сообщения | Хранилище (SharedPreferences, SQLite, бэкенд) и экраны списков. |
| **Комментарии и рекомендации** | Заглушки | API комментариев и рекомендаций (YouTube API или свой бэкенд). |
| **Авторизация** | Нет | Если нужен «свой канал», подписки и плейлисты — добавить OAuth (Google и т.д.) или логин/пароль к своему API. |
| **Публикация (Publish)** | Кнопки без логики | Выбор файла с устройства, загрузка на сервер (multipart), возможно запись с камеры. |

---

## 4. Минимум для «использования под свои видео»

1. **Свой список видео**  
   Заменить/дополнить `demoFeed` в `lib/data/video_store.dart` и при необходимости `demoShorts` в `lib/data/short_store.dart` на свои URL (прямые ссылки на `.mp4` или HLS/DASH), заголовки и превью.

2. **Сборка и запуск**  
   Выполнять шаги из раздела 1 (build web + `python -m http.server 8080` или `puro flutter run -d chrome`).

3. **Режим разработчика Windows**  
   Должен быть включён, иначе `flutter pub get` может ругаться на symlink.

Дальше уже по желанию: бэкенд, API, авторизация, Cast, уведомления и т.д. по таблице выше.
