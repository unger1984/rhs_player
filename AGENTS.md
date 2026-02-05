# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Правила проекта (обязательно к применению)

Перед работой с кодом учитывай правила из `.cursor/rules/`:

| Правило                                                                      | Назначение                                                                               |
| ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| [flutter-plugin-standards.mdc](.cursor/rules/flutter-plugin-standards.mdc)   | Стандарты Flutter Plugin: FVM, архитектура, стиль кода, нативный Kotlin, видео-специфика |
| [rhs-player-context.mdc](.cursor/rules/rhs-player-context.mdc)               | Контекст rhs_player: стек, фичи, ключевые файлы, сборка                                  |
| [keep-docs-in-sync.mdc](.cursor/rules/keep-docs-in-sync.mdc)                 | При изменениях API/архитектуры — обновлять правила и README                              |
| [player-controls-structure.mdc](.cursor/rules/player-controls-structure.mdc) | Архитектура контролов плеера в example                                                   |

**Роль:** эксперт Flutter Plugin; фокус на надёжный, производительный, поддерживаемый код. Подробнее: [flutter-plugin-standards.mdc](.cursor/rules/flutter-plugin-standards.mdc).

**Инструменты:** команды только с префиксом `fvm` (`fvm dart format`, `fvm flutter analyze`, `fvm flutter pub add` и т.д.). После правок — `fvm dart format .`, при необходимости `fvm dart fix`.

**Язык:** ответы и комментарии — на **русском языке**.

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

Все команды — с префиксом **fvm**. Подробнее: [flutter-plugin-standards.mdc](.cursor/rules/flutter-plugin-standards.mdc), [rhs-player-context.mdc](.cursor/rules/rhs-player-context.mdc).

- **Format:** `fvm dart format .`
- **Analyze:** `fvm flutter analyze .`
- **Test:** `fvm flutter test .`
- **Run Example:** `cd example && fvm flutter run`

## Code Style (Non-Standard)

Русские комментарии, префикс Rhs для классов, без `!`, разделение слоёв. Детали: [flutter-plugin-standards.mdc](.cursor/rules/flutter-plugin-standards.mdc). Example: размеры через `flutter_screenutil` (.w, .h, .r, .sp), см. [rhs-player-context.mdc](.cursor/rules/rhs-player-context.mdc).

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

## После изменений

При изменении API, архитектуры или паттернов обновляй правила и README: [keep-docs-in-sync.mdc](.cursor/rules/keep-docs-in-sync.mdc).
