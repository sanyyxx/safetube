#!/usr/bin/env python3
"""
Сервер для Flutter Web: раздаёт build/web, при изменениях в коде пересобирает.
Запуск: из корня проекта  python scripts/serve_web.py
Или:  python scripts/serve_web.py --port 8080
Открой в браузере http://localhost:8080 и просто обновляй вкладку после правок.
"""
import argparse
import os
import shutil
import subprocess
import sys
import threading
import time
from http.server import HTTPServer, SimpleHTTPRequestHandler

# Попытка использовать watchdog для наблюдения за файлами
try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
    HAS_WATCHDOG = True
except ImportError:
    HAS_WATCHDOG = False


def project_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def flutter_command_prefix():
    """Путь к Flutter: `flutter` в PATH или `puro flutter` (Windows)."""
    if shutil.which("flutter"):
        return ["flutter"]
    puro = shutil.which("puro")
    if puro:
        return [puro, "flutter"]
    return ["flutter"]


def run_build(root: str) -> bool:
    """Запускает flutter build web. Возвращает True при успехе."""
    # --no-web-resources-cdn: CanvasKit идёт из build/web/canvaskit (без gstatic).
    # Иначе при блокировке CDN / офлайне часто «вечный» белый экран.
    cmd = flutter_command_prefix() + [
        "build",
        "web",
        "--no-web-resources-cdn",
    ]
    print("[build] Запуск: %s" % " ".join(cmd))
    r = subprocess.run(
        cmd,
        cwd=root,
        shell=False,
    )
    if r.returncode == 0:
        print("[build] Готово. Обнови вкладку в браузере.")
    else:
        print("[build] Ошибка сборки (code %s)." % r.returncode)
    return r.returncode == 0


class RebuildHandler(FileSystemEventHandler):
    def __init__(self, root: str, debounce_sec: float = 1.0):
        self.root = root
        self.debounce_sec = debounce_sec
        self.last_build_time = 0.0
        self.pending = False

    def _schedule_build(self):
        now = time.time()
        if now - self.last_build_time < self.debounce_sec:
            if not self.pending:
                self.pending = True
                threading.Timer(self.debounce_sec, self._do_build).start()
            return
        self._do_build()

    def _do_build(self):
        self.pending = False
        self.last_build_time = time.time()
        run_build(self.root)

    def on_modified(self, event):
        if event.is_directory:
            return
        p = event.src_path
        if "build" in p or ".dart_tool" in p:
            return
        if p.endswith(".dart") or "pubspec" in os.path.basename(p):
            self._schedule_build()


def watch_with_watchdog(root: str):
    observer = Observer()
    handler = RebuildHandler(root)
    for d in ["lib", "."]:
        path = os.path.join(root, d)
        if os.path.isdir(path):
            observer.schedule(handler, path, recursive=(d == "lib"))
    observer.start()
    return observer


def main():
    parser = argparse.ArgumentParser(description="Сервер Flutter Web + пересборка при изменениях")
    parser.add_argument("--port", type=int, default=8080, help="Порт сервера (по умолчанию 8080)")
    parser.add_argument("--no-watch", action="store_true", help="Не следить за файлами, только сервер")
    parser.add_argument("--no-build", action="store_true", help="Не собирать перед стартом (только если build/web уже есть)")
    args = parser.parse_args()

    root = project_root()
    os.chdir(root)

    build_dir = os.path.join(root, "build", "web")
    if not args.no_build:
        if not run_build(root):
            sys.exit(1)
    else:
        if not os.path.isdir(build_dir):
            print("Папка build/web не найдена. Запусти без --no-build.")
            sys.exit(1)

    # Сервер раздаёт build/web
    os.chdir(build_dir)
    port = args.port
    server = HTTPServer(("", port), SimpleHTTPRequestHandler)

    if not args.no_watch and HAS_WATCHDOG:
        observer = watch_with_watchdog(root)
        print("[watch] Слежу за изменениями в lib/ и pubspec. После правок — пересборка, затем обнови вкладку.")
    elif not args.no_watch:
        print("[watch] Установи watchdog: pip install watchdog — тогда будет авто-пересборка.")

    print("Сервер: http://localhost:%s — открой в браузере и обновляй вкладку после правок." % port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    if not args.no_watch and HAS_WATCHDOG:
        observer.stop()
        observer.join()
    server.shutdown()
    print("Выход.")


if __name__ == "__main__":
    main()
