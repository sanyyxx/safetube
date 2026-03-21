# API: шортсы

Запрос: **`GET {API_BASE_URL}/shorts`**  
Пример: `https://youtube.esl.kz/api/v1/shorts?per_page=100`

Заголовок: `Accept: application/json`

## Формат ответа

Такой же, как для видео: массив в `data`, или корневой массив, или `videos` / `shorts` / пагинация Laravel — см. разбор в `lib/data/json_list_from_api.dart`.

## Поля одного элемента

Используется тот же парсинг, что и для ленты видео (`VideoItem.fromJson`): нужен **валидный URL воспроизведения** (`playback_url`, `media`, относительный `/storage/...` и т.д.).

Дополнительно для UI:

| Поле | Примечание |
|------|------------|
| `likes_text` / `likesText` / `likes` / `like_count` | Текст лайков (иначе покажется `0`) |

Остальное: `title`, `channel_name`, `thumbnail_url` — как в **`docs/API_VIDEOS.md`**.

## Laravel

Добавь маршрут и контроллер по аналогии с `videos`, например `GET /api/v1/shorts`, отдающий опубликованные шортсы в том же формате, что и видео.

Пример см. **`docs/LARAVEL_VIDEOS_API_EXAMPLE.md`** (раздел можно скопировать и заменить ресурс на Short).
