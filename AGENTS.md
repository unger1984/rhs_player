# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Overview

- **rhs_player**: Android-only Flutter video player plugin using ExoPlayer
- **Architecture**: Thin Flutter wrapper over Android ExoPlayer (Media3)
- **No iOS support**: iOS code has been removed entirely

## Critical Architecture Rules (MANDATORY)

### Flutter

- 1 Controller = 1 native player (strict 1:1 mapping)
- All logic lives in Controller, no state in Widget
- Use TextureRegistry only (no SurfaceView / PlatformView for video)

### Android

- Use androidx.media3 ExoPlayer only
- No singleton ExoPlayer instances
- Explicit lifecycle: create → release
- SharedPlayerRegistry manages player instances with reference counting

## Non-Standard Patterns

### Controller-View Architecture

- Controller holds all playback logic
- View is purely visual with optional overlay
- attachViewId() method binds controller to native view ID
- Method channels are view-specific (rhsplayer/view\_$id)

### Event System

- Separate event channels for different data types:
  - Playback state (position, duration, buffering, playing, error)
  - Track information (video/audio/subtitle tracks)
- Events use ValueNotifier + BehaviorSubject for reactive programming
- No polling - native side pushes updates

### Track Selection

- Video tracks identified by "height:width:bitrate" string format
- selectVideoTrack() uses double approach: override + max size/bitrate
- Audio/subtitle tracks use "groupIndex:trackIndex" format
- Tracks are sent to Flutter immediately when available

### Android TV Support

- Custom focus navigation system with Chain of Responsibility pattern
- Rows and items are structured in a grid for directional navigation
- ProgressSliderItem handles arrow keys for seeking
- Visual focus indicators with blue glow effect
- Simultaneous mouse and remote control support

### DRM Handling

- DRM config comes from Flutter side
- Native side must not store keys
- Supports Widevine and ClearKey
- Custom HTTP client provider for network requests

### Memory Management

- SharedPlayerEntry with reference counting
- WeakReference for attached views to prevent memory leaks
- Proper cleanup in dispose() methods
- MediaSessionCompat integration for system integration

## Build/Lint/Test Commands

- **FVM Required**: All commands must use `fvm flutter` prefix
- **Format**: `fvm dart format .`
- **Analyze**: `fvm flutter analyze .`
- **Test**: `fvm flutter test .`
- **Integration Test**: `cd example && fvm flutter test integration_test`
- **Run Example**: `cd example && fvm flutter run`

## Code Style (Non-Standard)

- Russian comments in source code
- Custom naming: Rhs prefix for all classes (RhsPlayerController, etc.)
- Strict separation of concerns between layers
- No operator `!` - use null-aware operators instead
- Extensive logging with android.util.Log.d for debugging

### Example app (example/)

- **Sizes:** All dimensions use `flutter_screenutil` (designSize 1920×1080 from Figma). Use `.w`, `.h`, `.r`, `.sp` — no raw pixel values for layout, fonts, or icons.

## Testing Specifics

- Unit tests for platform interface and method channel
- Integration tests for end-to-end functionality
- Tests use mock method call handlers
- No widget tests in main package (only in example)

## Critical Gotchas

- Video track selection requires double approach (override + max size)
- Audio suppression during buffering to prevent audio glitches
- Ready fallback timer for edge cases in playback start
- Data saver mode applies bitrate limits through track selection
- Picture-in-Picture requires Android O+ and activity context

# AI Правила для Flutter Plugin разработки

Для ответов и комментариев используй Русский язык

## Роль и Инструменты

- **Роль:** Эксперт Flutter Plugin разработчик. Фокус: Надежный, производительный, поддерживаемый код плагина.
- **Объяснения:** Объясняй возможности Dart (null safety, streams, futures) и Platform Channels для новых пользователей.
- **Инструменты:** ВСЕГДА запускай `fvm dart format`. Используй `fvm dart fix` для очистки кода. Используй `analyze_files` с `flutter_lints` для раннего обнаружения ошибок.
- **Зависимости:** Добавляй через `fvm flutter pub add`. Используй `pub_dev_search` для поиска. Объясняй, зачем нужен пакет.
- **FVM:** Всегда используй префикс `fvm` перед командами Flutter/Dart для консистентности версий.

## Архитектура плагина

- **Структура:**
  - `lib/` - Dart API плагина
  - `android/` - Android нативная реализация
  - `ios/` - iOS нативная реализация (если есть)
  - `example/` - Пример использования плагина
- **Слои:**
  - Platform Interface (абстракция)
  - Platform Implementation (нативный код)
  - Public API (Dart интерфейс для пользователей)
- **SOLID:** строго соблюдается.
- **Platform Channels:**
  - Используй `MethodChannel` для вызовов методов
  - Используй `EventChannel` для потоков событий
  - Используй `PlatformView` для встраивания нативных view

## Код плагина - Лучшие практики

- **API дизайн:** Простой, интуитивный, хорошо документированный публичный API.
- **Обработка ошибок:** Всегда обрабатывай ошибки с обеих сторон (Dart и нативный код).
- **Типобезопасность:** Строгая типизация для всех параметров и возвращаемых значений.
- **Null Safety:** НЕТ оператора `!`. Используй `?` и flow analysis (например, `if (x != null)`).
- **Async:** Используй `async/await` для асинхронных операций. Перехватывай все ошибки через `try-catch`.
- **Документация:** Каждый публичный метод должен иметь dartdoc комментарии.

## Стиль кода и Качество

- **Именование:** `PascalCase` (Типы), `camelCase` (Члены), `snake_case` (Файлы).
- **Краткость:** Функции <20 строк. Избегай многословности.
- **Логирование:** Используй `dart:developer` `log()` для отладки. НИКОГДА не используй `print`.
- **Неизменяемость:** `const` конструкторы везде, где возможно.
- **Композиция:** Разбивай сложную логику на небольшие, переиспользуемые компоненты.

## Нативный код (Android/Kotlin)

- **Стиль:** Следуй Kotlin coding conventions.
- **Lifecycle:** Правильно управляй lifecycle компонентов (Activity, View).
- **Threading:** Используй корутины для асинхронных операций.
- **Ресурсы:** Всегда освобождай ресурсы (dispose, cleanup).

## Example приложение

- **Цель:** Демонстрация всех возможностей плагина.
- **Простота:** Код должен быть понятным и легко читаемым.
- **UI:** Чистый, функциональный интерфейс для тестирования фич.
- **Документация:** README с примерами использования.
- **Размеры:** Все размеры в example — через `flutter_screenutil` (designSize 1920×1080, макет из Figma). Использовать `.w`, `.h`, `.r`, `.sp`; сырые пиксели для верстки/шрифтов/иконок не использовать.

## Тестирование плагина

- **Тесты:** Тесты писать НЕ нужны (согласно требованиям проекта).

## Публикация

- **pubspec.yaml:** Корректные метаданные (version, description, homepage, repository).
- **CHANGELOG.md:** Документируй все изменения.
- **LICENSE:** Указывай лицензию.
- **README.md:** Полная документация по использованию.
- **API docs:** Генерируй через `fvm dart doc`.

## Справочник команд (с FVM)

- **Форматирование:** `fvm dart format .`
- **Анализ:** `fvm flutter analyze .`
- **Тесты:** `fvm flutter test .`
- **Pub get:** `fvm flutter pub get`
- **Добавить зависимость:** `fvm flutter pub add <package>`
- **Build Runner:** `fvm dart run build_runner build --delete-conflicting-outputs`
- **Запуск example:** `cd example && fvm flutter run`
- **Генерация docs:** `fvm dart doc`

## Специфика видео плагина

- **Performance:** Минимизируй overhead при передаче данных между Dart и нативным кодом.
- **Memory:** Эффективное управление памятью при работе с видео потоками.
- **Platform Views:** Используй Hybrid Composition для лучшей производительности на Android.
- **Lifecycle:** Правильная обработка pause/resume/dispose для видео плеера.
- **Error handling:** Детальная обработка ошибок загрузки и воспроизведения.
