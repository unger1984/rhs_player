# Player — фича видеоплеера

Основная фича example-приложения: интеграция rhs_player плагина с полнофункциональным UI для воспроизведения видео.

## Архитектура

Фича построена на принципах разделения ответственности:

- **Model** — бизнес-логика и управление состоянием
- **UI** — визуальное представление и взаимодействие с пользователем
  - PlayerView — главный виджет плеера
  - Actions — Intent/Action система для клавиатурных шорткатов
  - Controls — система управления контролами (**см. [Controls README](ui/controls/README.md)**)

## Структура

```
player/
├── model/
│   └── player_state.dart           # PlayerState — управление состоянием плеера
└── ui/
    ├── player_view.dart            # PlayerView — главный виджет
    ├── actions/                     # Intent/Action система
    │   ├── player_actions.dart     # Action классы (реализация)
    │   ├── player_intents.dart     # Intent классы (намерения)
    │   └── player_shortcuts.dart   # ShortcutActivator привязки
    └── controls/                    # Система контролов
        └── README.md                # 📖 Подробная документация
```

## Компоненты

### PlayerState (`model/player_state.dart`)

Управление состоянием плеера. Инкапсулирует всю бизнес-логику:

**Ответственность:**
- Инициализация `RhsPlayerController`
- Загрузка списка фильмов через `MediaRepository`
- Подписка на события плеера (статус, треки, позиция)
- Управление текущим воспроизводимым фильмом
- Генерация списка рекомендаций

**API:**

```dart
// Инициализация
final state = PlayerState(repository);
await state.initialize();

// Переключение фильма
state.playMedia(mediaItem);

// Получение рекомендаций
final recommended = state.getRecommendedItems();

// Текущий фильм
final current = state.currentItem;

// Контроллер плеера
state.controller.play();
state.controller.pause();

// Очистка ресурсов
state.dispose();
```

**Особенности:**
- Автоматически запускает воспроизведение первого фильма после загрузки
- Логирует все события плеера через `dart:developer`
- Поддерживает callback `onStateChanged` для обновления UI
- Поддерживает callback `backHandler` для обработки кнопки Back

### PlayerView (`ui/player_view.dart`)

Главный виджет плеера. Инкапсулирует `RhsPlayerView` с контролами и оверлеями.

**Параметры:**
- `controller` — RhsPlayerController для управления воспроизведением
- `recommendedItems` — список рекомендуемых фильмов для карусели
- `onItemSelected` — callback при выборе фильма из карусели
- `registerBackHandler` — регистрация обработчика кнопки Back
- `onBackButtonPressed` — callback при нажатии кнопки Back

**Структура:**

```dart
RhsPlayerView(
  controller: controller,
  boxFit: BoxFit.contain,
  overlay: Stack(
    children: [
      BufferingOverlay(controller: controller),  // Индикатор загрузки
      VideoControls(                              // Контролы
        controller: controller,
        recommendedItems: items,
        // ... callbacks
      ),
    ],
  ),
)
```

**Особенности:**
- Использует `BoxFit.contain` для корректного отображения видео
- Интегрирует `BufferingOverlay` для индикации загрузки
- Передаёт управление в `VideoControls` для всех UI взаимодействий

### Actions (`ui/actions/`)

Intent/Action система для клавиатурных шорткатов (Flutter Shortcuts API).

**Архитектура:**

1. **Intents** (`player_intents.dart`) — что хочет сделать пользователь (Intent классы)
2. **Actions** (`player_actions.dart`) — как это сделать (Action классы с бизнес-логикой)
3. **Shortcuts** (`player_shortcuts.dart`) — привязка клавиш к Intent'ам

**Поддерживаемые действия:**

- `PlayIntent` / `PauseIntent` / `TogglePlayPauseIntent` — управление воспроизведением
- `SeekBackwardIntent` / `SeekForwardIntent` — перемотка (с настраиваемым шагом)
- `ShowControlsIntent` / `HideControlsIntent` / `ToggleControlsVisibilityIntent` — видимость контролов
- `OpenQualityMenuIntent` / `OpenSoundtrackMenuIntent` — открытие меню

**Пример использования:**

```dart
Shortcuts(
  shortcuts: PlayerShortcuts.defaultShortcuts,
  child: Actions(
    actions: {
      PlayIntent: PlayAction(controller),
      PauseIntent: PauseAction(controller),
      SeekBackwardIntent: SeekBackwardAction(controller),
      // ...
    },
    child: child,
  ),
)
```

**Стандартные привязки клавиш:**

| Клавиша | Действие |
|---------|----------|
| `Space` | Toggle Play/Pause |
| `Left Arrow` | Seek -10s |
| `Right Arrow` | Seek +10s |
| `Escape` | Hide Controls |
| `M` | Toggle Controls Visibility |

### Controls (`ui/controls/`)

Система управления контролами видеоплеера. Включает:

- Rows (ряды кнопок)
- Items (элементы контролов)
- Navigation (D-pad навигация для Android TV)
- State Machine (управление состояниями контролов)
- Builder (декларативное построение UI)

**📖 [Подробная документация по Controls](ui/controls/README.md)**

**Основные подсистемы:**

1. **State Machine** — управление состояниями контролов (видимость, таймеры, режимы)
   - **📖 [Документация State Machine](ui/controls/state/README.md)**
2. **Navigation Manager** — D-pad навигация между элементами (Android TV)
3. **Video Controls Builder** — декларативное построение UI контролов
4. **Rows & Items** — иерархическая структура элементов контролов

## Использование

### Базовая интеграция

```dart
class PlayerPage extends StatefulWidget {
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlayerState _playerState;

  @override
  void initState() {
    super.initState();
    _playerState = PlayerState(MediaRepository());
    _playerState.initialize();
    _playerState.onStateChanged = () => setState(() {});
  }

  @override
  void dispose() {
    _playerState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PlayerView(
        controller: _playerState.controller,
        recommendedItems: _playerState.getRecommendedItems(),
        onItemSelected: _playerState.playMedia,
      ),
    );
  }
}
```

### С клавиатурными шорткатами

```dart
@override
Widget build(BuildContext context) {
  return Shortcuts(
    shortcuts: PlayerShortcuts.defaultShortcuts,
    child: Actions(
      actions: {
        PlayIntent: PlayAction(_playerState.controller),
        PauseIntent: PauseAction(_playerState.controller),
        SeekBackwardIntent: SeekBackwardAction(_playerState.controller),
        SeekForwardIntent: SeekForwardAction(_playerState.controller),
        // ...
      },
      child: Focus(
        autofocus: true,
        child: PlayerView(
          controller: _playerState.controller,
          recommendedItems: _playerState.getRecommendedItems(),
          onItemSelected: _playerState.playMedia,
        ),
      ),
    ),
  );
}
```

### Обработка кнопки Back

- **UI-кнопка «Назад»** (в верхней панели): всегда выход с экрана (`onBackButtonPressed`).
- **Аппаратная кнопка Back** (пульт/хардвар):
  - Контролы видны, карусель развёрнута → сворачивание карусели в режим peek.
  - Контролы видны (peek и др.) → скрытие контролов.
  - Контролы скрыты → показ подсказки «Для выхода нажмите Назад ещё раз» на настраиваемое время; повторное нажатие Back в этот момент выходит. Длительность задаётся параметром `PlayerPage.exitConfirmDuration` (по умолчанию из `AppDurations.exitConfirmOverlay`).

```dart
PlayerView(
  controller: _playerState.controller,
  recommendedItems: _playerState.getRecommendedItems(),
  onItemSelected: _playerState.playMedia,
  registerBackHandler: (handler) => _backHandler = handler,
  onBackButtonPressed: _requestPop,
)
```

## Зависимости

- `rhs_player` — Flutter плагин для видео (ExoPlayer)
- `flutter_screenutil` — адаптивная верстка (1920×1080)
- Внутренние:
  - `entities/media` — модели MediaItem
  - `shared/api` — MediaRepository
  - `shared/ui/widgets` — BufferingOverlay

## Особенности реализации

### 1. Reactive State Management

PlayerState использует callback-based подход:
- `onStateChanged` — уведомление об изменении состояния
- Подписки на события контроллера через listeners
- Логирование всех событий для отладки

### 2. Separation of Concerns

- **Model**: только бизнес-логика, никакого UI
- **UI**: только представление, никакой бизнес-логики
- **Actions**: переиспользуемая логика для Intent/Action системы

### 3. Composition Over Inheritance

PlayerView композирует:
- RhsPlayerView (базовый плеер)
- BufferingOverlay (индикатор загрузки)
- VideoControls (контролы)

### 4. Android TV Support

Полная поддержка D-pad навигации через:
- NavigationManager (Chain of Responsibility)
- FocusableItem интерфейс
- Визуальные индикаторы фокуса

## См. также

- **[Controls README](ui/controls/README.md)** — подробная документация системы контролов
- **[State Machine README](ui/controls/state/README.md)** — документация State Machine
- **[AGENTS.md](../../../../AGENTS.md)** — критические архитектурные правила
- **[README.md](../../../../README.md)** — основная документация плагина rhs_player
