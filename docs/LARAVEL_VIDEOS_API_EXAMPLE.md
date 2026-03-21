# Laravel: чтобы `GET /api/v1/videos` отдавал опубликованные видео

У тебя в ответе было `"data":[]` и `"total":0` — **запрос к БД возвращает 0 строк**. Flutter тут ни при чём: нужно поправить **роут + контроллер + модель** на сервере.

Ниже — **рабочий минимум**, который можно вставить в проект и адаптировать имена таблиц/полей.

---

## 1. Проверка в БД (на сервере)

```bash
php artisan tinker
```

```php
// Подставь своё имя модели и таблицы
\App\Models\Video::count();
\App\Models\Video::query()->get(['id','title','status']);
```

Если `count()` **0** — записи не в той БД/таблице, что смотрит модель, или они не создаются.

---

## 2. Маршрут `api.php`

```php
use App\Http\Controllers\Api\V1\VideoController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::get('videos', [VideoController::class, 'index']);
});
```

Убедись, что в `bootstrap/app.php` или `RouteServiceProvider` префикс **`api`** даёт итоговый путь  
`/api/v1/videos` (как в приложении).

---

## 3. Контроллер `app/Http/Controllers/Api/V1/VideoController.php`

Замени **`Video`** на свою модель и имена полей (`status`, `is_published` и т.д.).

```php
<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\VideoFeedResource;
use App\Models\Video;
use Illuminate\Http\Request;

class VideoController extends Controller
{
    public function index(Request $request)
    {
        $perPage = min((int) $request->query('per_page', 15), 100);

        $query = Video::query()
            // ВАЖНО: приведи условие к реальному полю в БД:
            ->where('status', 'published')   // или is_published = 1, или enum
            ->orderByDesc('id');

        // Если используешь SoftDeletes и «опубликованные» не удалены — ок.
        // Если нужно показывать всё для отладки — временно закомментируй ->where(...)

        return VideoFeedResource::collection(
            $query->paginate($perPage)
        );
    }
}
```

Если в админке статус хранится **по-другому** (например `1`, `active`, `approved`) — **одна строка `where` должна совпадать с БД**.

---

## 4. Resource `app/Http/Resources/VideoFeedResource.php`

Клиент ждёт поля вроде `playback_url`, `thumbnail_url`, `title`, `channel_name`, `views_text`, `published_text` (см. `docs/API_VIDEOS.md`).

```php
<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class VideoFeedResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        // Подставь свои accessors / связи media
        $playback = $this->playback_url
            ?? $this->video_url
            ?? optional($this->getFirstMedia('video'))?->getFullUrl();

        $thumb = $this->thumbnail_url
            ?? optional($this->getFirstMedia('thumb'))?->getFullUrl();

        return [
            'id' => $this->id,
            'title' => $this->title,
            'playback_url' => $playback,
            'thumbnail_url' => $thumb ?? '',
            'channel_name' => $this->channel_name ?? $this->channel?->name ?? 'Channel',
            'views_text' => (string) ($this->views_count ?? $this->views ?? 0),
            'published_text' => optional($this->published_at ?? $this->created_at)->toIso8601String(),
            'duration_text' => $this->duration_text,
        ];
    }
}
```

Без Spatie Media — убери строки с `getFirstMedia` и оставь только поля модели.

---

## 5. После правок на сервере

```bash
php artisan route:clear
php artisan config:clear
php artisan cache:clear
```

Снова открой в браузере:

`https://youtube.esl.kz/api/v1/videos?per_page=100`

В JSON должно быть **`"total": N`** с **N > 0** и объекты в **`data`**.

---

## 6. Если всё равно пусто

1. Временно в контроллере: `return Video::query()->paginate($perPage);` без `where` — если **появились** строки, проблема только в **условии статуса**.
2. Сравни **имя таблицы** в миграции админки и в модели `Video`.
3. Проверь **один** `.env` на сервере (не локальный).

---

## 7. Шортсы: `GET /api/v1/shorts`

Приложение запрашивает **`GET .../shorts?per_page=100`** и ожидает **тот же формат элементов**, что и у видео (`playback_url`, `title`, `channel_name`, опционально `likes_text`). См. **`docs/API_SHORTS.md`**.

Маршрут:

```php
Route::get('shorts', [ShortController::class, 'index']);
```

Контроллер — копия логики `VideoController::index`, но модель **`Short`** (или отфильтрованные `Video::where('type', 'short')` — как у тебя в БД). Resource можно переиспользовать **`VideoFeedResource`**, если структура полей совпадает.

---

Этот репозиторий содержит только **Flutter**; правки на Laravel делаются **в коде на сервере** и в БД хостинга.
