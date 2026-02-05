# State Machine для контролов плеера

Система управления состояниями контролов видеоплеера с использованием паттерна State Machine.

## Оглавление

- [Архитектура](#архитектура)
- [Файлы](#файлы)
- [Состояния](#состояния)
- [События](#события)
- [Переходы](#переходы)
- [Использование](#использование)
- [Расширяемость](#расширяемость)

## Архитектура

State Machine централизует управление состояниями контролов, заменяя набор булевых флагов на явную модель состояний с типобезопасными переходами.

### Преимущества

1. **Явная модель**: все состояния и переходы описаны явно в коде
2. **Type-safety**: exhaustive checking sealed классов — компилятор проверит все case
3. **Централизация**: вся логика переходов и таймеров в одном месте
4. **Расширяемость**: добавление новых состояний/рядов не размазывает логику
5. **Отладка**: логирование переходов, понятная трасса изменений состояния

### До и после

**До (булевы флаги):**

```dart
bool _controlsVisible = true;
bool _seekingOverlayVisible = false;
bool _isMenuOpen = false;

if (_controlsVisible && !_isMenuOpen && getFocusedId() != 'carousel') {
  // логика автоскрытия
}
```

**После (State Machine):**

```dart
final state = _stateMachine.currentState;

if (state is ControlsVisiblePeekState) {
  // логика автоскрытия
}
```

## Файлы

```
state/
├── controls_state.dart              # 6 состояний (sealed class)
├── controls_event.dart              # События для переходов (sealed class)
├── controls_state_machine.dart      # Логика переходов + таймеры
├── controls_visibility_config.dart  # Конфигурация видимости рядов
├── state_config.dart                # Конфигурация таймеров
└── README.md                        # Эта документация
```

## Состояния

Всего 6 состояний контролов:

### 1. ControlsHiddenState

Все контролы скрыты за границами экрана.

- **Видимость**: `ControlsVisibilityConfig.hidden`
- **Таймеры**: нет
- **Переходы**:
  - OK/Enter/стрелки → `ControlsVisiblePeekState`
  - Стрелки влево/вправо → `SeekingOverlayState`

### 2. SeekingOverlayState

Показан только слайдер прогресса (перемотка со скрытыми контролами).

- **Видимость**: `ControlsVisibilityConfig.seekingOverlay` (только слайдер)
- **Таймеры**: автоскрытие слайдера через 2 секунды
- **Переходы**:
  - Таймер истёк → `ControlsHiddenState`
  - OK/Enter/стрелки вверх/вниз → `ControlsVisiblePeekState`
  - Повторная перемотка → остаёмся в `SeekingOverlayState` (сброс таймера)

### 3. ControlsVisiblePeekState

Все контролы видны, карусель в режиме peek (96.h).

- **Видимость**: `ControlsVisibilityConfig.visiblePeek`
- **Таймеры**: автоскрытие через 5 секунд
- **Переходы**:
  - Таймер истёк → `ControlsHiddenState`
  - Фокус на карусель → `ControlsVisibleExpandedState`
  - Открыто меню → `MenuOpenState`
  - Плеер на паузе → `ControlsVisiblePausedState`

### 4. ControlsVisibleExpandedState

Все контролы видны, карусель развёрнута (320.h).

- **Видимость**: `ControlsVisibilityConfig.visibleExpanded`
- **Таймеры**: автоскрытие ОТКЛЮЧЕНО
- **Переходы**:
  - Фокус уходит с карусели → `ControlsVisiblePeekState`
  - Открыто меню → `MenuOpenState`
  - Плеер на паузе → `ControlsVisiblePausedState`

### 5. MenuOpenState

Меню качества/саундтрека открыто.

- **Видимость**: наследует от предыдущего состояния
- **Таймеры**: автоскрытие ЗАБЛОКИРОВАНО
- **Переходы**:
  - Меню закрыто → возврат в `previousState`

### 6. ControlsVisiblePausedState

Плеер на паузе, контролы остаются видимыми.

- **Видимость**: `ControlsVisibilityConfig.visiblePeek`
- **Таймеры**: автоскрытие ОТКЛЮЧЕНО
- **Переходы**:
  - Play → `ControlsVisiblePeekState`

## События

События делятся на категории:

### Пользовательские действия

- `ShowControlsEvent(resetFocus: bool)` — показать контролы
- `HideControlsEvent()` — скрыть контролы
- `ToggleControlsEvent()` — переключить видимость

### Навигация и фокус

- `FocusChangedEvent(itemId: String?)` — изменился фокус

### Перемотка

- `SeekWhileHiddenEvent()` — перемотка при скрытых контролах

### Взаимодействие

- `UserInteractionEvent()` — любое взаимодействие (сброс таймера)

### Меню

- `MenuOpenedEvent()` — меню открыто
- `MenuClosedEvent()` — меню закрыто

### Таймеры

- `AutoHideTimerExpiredEvent()` — истёк таймер автоскрытия
- `SeekingOverlayTimerExpiredEvent()` — истёк таймер слайдера

### Статус плеера

- `PlayerStatusChangedEvent(status: RhsPlayerStatus)` — изменился статус

## Переходы

Диаграмма переходов между состояниями:

```
[init] → ControlsVisiblePeek

ControlsHidden ──seek(arrows)───────→ SeekingOverlay
               ←──timer expired──────
               
ControlsHidden ──show(OK/arrows)────→ ControlsVisiblePeek

SeekingOverlay ──show──────────────→ ControlsVisiblePeek

ControlsVisiblePeek ──auto-hide──────→ ControlsHidden
                    ──focus carousel→ ControlsVisibleExpanded
                    ──menu opened───→ MenuOpen
                    ──player paused─→ ControlsVisiblePaused

ControlsVisibleExpanded ──focus off───→ ControlsVisiblePeek
                        ──menu opened─→ MenuOpen
                        ──paused──────→ ControlsVisiblePaused

MenuOpen ──menu closed──→ [previousState]

ControlsVisiblePaused ──play→ ControlsVisiblePeek
```

## Использование

### Инициализация

```dart
final _stateMachine = ControlsStateMachine(
  config: StateConfig(
    autoHideDelay: Duration(seconds: 5),
    seekingOverlayDuration: Duration(seconds: 2),
  ),
  initialState: ControlsVisiblePeekState(),
  onStateChanged: (oldState, newState) {
    setState(() {}); // обновить UI
  },
);
```

### Отправка событий

```dart
// Показать контролы
_stateMachine.handleEvent(ShowControlsEvent(resetFocus: true));

// Скрыть контролы
_stateMachine.handleEvent(HideControlsEvent());

// Перемотка при скрытых контролах
_stateMachine.handleEvent(SeekWhileHiddenEvent());

// Изменился фокус
_stateMachine.handleEvent(FocusChangedEvent('play_pause_button'));

// Изменился статус плеера
_stateMachine.handleEvent(PlayerStatusChangedEvent(status));
```

### Получение текущего состояния

```dart
final state = _stateMachine.currentState;
final config = state.visibilityConfig;

// Проверка состояния
if (state is ControlsHiddenState) {
  // логика для скрытых контролов
}

// Использование конфигурации видимости
VideoControlsBuilder(
  controlsVisible: !config.excludeFromFocus,
  showProgressSlider: config.showProgressSlider,
  // ...
);
```

### Очистка

```dart
@override
void dispose() {
  _stateMachine.dispose(); // отменяет таймеры
  super.dispose();
}
```

## Расширяемость

### Добавление нового ряда контролов

Пример: добавляем ряд с субтитрами (SubtitlesRow).

**Шаг 1**: Обновить `ControlsVisibilityConfig`:

```dart
class ControlsVisibilityConfig {
  final bool showSubtitlesRow; // <-- новое поле
  
  const ControlsVisibilityConfig({
    // ... остальные поля
    required this.showSubtitlesRow,
  });
  
  // Обновить preset конфигурации
  static const visiblePeek = ControlsVisibilityConfig(
    // ... остальные значения
    showSubtitlesRow: true, // <-- значение для каждой конфигурации
  );
}
```

**Шаг 2**: Добавить условный рендеринг в `VideoControlsBuilder`:

```dart
if (config.showSubtitlesRow)
  widget.rows[N].build(context),
```

**Готово!** State Machine остаётся без изменений.

### Добавление нового состояния

Пример: добавляем состояние "Ускоренная перемотка" (FastForwardingState).

**Шаг 1**: Создать класс состояния в `controls_state.dart`:

```dart
class FastForwardingState extends ControlsState {
  const FastForwardingState();
  
  @override
  ControlsVisibilityConfig get visibilityConfig => 
      ControlsVisibilityConfig(
        showTopBar: false,
        showProgressSlider: true,
        showControlButtons: false,
        showCarousel: false,
        carouselMode: CarouselMode.hidden,
        excludeFromFocus: true,
        topBarSlideOffset: -1.0,
        bottomControlsSlideOffset: 1.0,
      );
}
```

**Шаг 2**: Создать события в `controls_event.dart`:

```dart
class StartFastForwardEvent extends ControlsEvent {
  const StartFastForwardEvent();
}

class StopFastForwardEvent extends ControlsEvent {
  const StopFastForwardEvent();
}
```

**Шаг 3**: Добавить переходы в `ControlsStateMachine._transition()`:

```dart
// Переходы из ControlsHiddenState
(ControlsHiddenState(), StartFastForwardEvent()) =>
  FastForwardingState(),

// Переходы из FastForwardingState
(FastForwardingState(), StopFastForwardEvent()) =>
  ControlsHiddenState(),
```

Компилятор Dart проверит exhaustive checking для sealed классов.

## Отладка

Все переходы логируются через `dart:developer`:

```
ControlsStateMachine: Handle event: ShowControlsEvent(resetFocus: true) in state: ControlsHiddenState()
ControlsStateMachine: Transition: ControlsHiddenState() → ControlsVisiblePeekState()
ControlsStateMachine: Auto-hide timer started (5s)
```

Для просмотра логов используйте DevTools или фильтр по имени `ControlsStateMachine`.
