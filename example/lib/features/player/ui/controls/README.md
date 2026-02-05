# Система управления видео плеером

Архитектура управления видео плеером с поддержкой Android TV пульта, мыши и клавиатуры.

## Оглавление

- [Основные концепции](#основные-концепции)
- [Архитектура](#архитектура)
- [State Machine](#state-machine)
- [Items (элементы)](#items-элементы)
- [Rows (ряды)](#rows-ряды)
- [Пример использования](#пример-использования)
- [Расширяемость](#расширяемость)

## Основные концепции

### Два ключевых паттерна

**1. State Machine** для управления состояниями контролов:
- Централизованное управление видимостью контролов
- Автоскрытие, паузы, меню, перемотка
- Type-safe переходы через sealed classes

**2. Chain of Responsibility** для навигации:
- Каждый элемент решает, как обрабатывать клавиши
- Если элемент не обработал - передает NavigationManager для навигации фокусом
- Гибкое поведение разных элементов (слайдер, кнопки, меню)

### Примеры различного поведения

- **Слайдер прогресса**: стрелки влево/вправо = перемотка на 10 сек
- **Ряд кнопок**: стрелки влево/вправо = переход между кнопками  
- **Карусель рекомендаций**: стрелки влево/вправо = прокрутка карусели
- **Меню качества**: стрелки вверх/вниз = выбор варианта в меню

## Архитектура

```
VideoControls (StatefulWidget)
├── ControlsStateMachine        # Управление состояниями (скрыто/видно/меню/пауза)
├── NavigationManager           # Навигация фокусом между элементами (Chain of Responsibility)
└── VideoControlsBuilder        # Декларативное построение UI контролов
    ├── TopBarRow               # Ряд 0: кнопка "Назад" + саундтрек
    ├── FullWidthRow            # Ряд 1: слайдер прогресса
    ├── ThreeZoneButtonRow      # Ряд 2: кнопки управления (избранное | play/rewind | качество)
    └── RecommendedCarouselRow  # Ряд 3: карусель рекомендаций (peek/expanded)
```

### Core компоненты

#### `KeyHandlingResult`
Результат обработки клавиши элементом:
- `handled` - клавиша обработана, не передавать дальше
- `notHandled` - клавиша не обработана, передать навигационному менеджеру для навигации фокусом

#### `FocusableItem`
Базовый интерфейс для любого элемента с фокусом:
- `id` - уникальный идентификатор
- `focusNode` - FocusNode для управления фокусом
- `handleKey(KeyEvent)` - обработка клавиши (Chain of Responsibility)
- `build(BuildContext)` - построение виджета

#### `ControlRow`
Абстрактный ряд элементов управления:
- `id` - уникальный идентификатор ряда
- `index` - индекс ряда (для сортировки и навигации вверх/вниз)
- `items` - список фокусируемых элементов
- `build(BuildContext)` - построение виджета ряда

## State Machine

**Централизованное управление состояниями контролов** вместо булевых флагов.

### Зачем State Machine?

**До (булевы флаги):**
```dart
bool _controlsVisible = true;
bool _seekingOverlayVisible = false;
bool _isMenuOpen = false;

// Сложная логика с множеством if-условий
if (_controlsVisible && !_isMenuOpen && ...) {
  // запустить автоскрытие
}
```

**После (State Machine):**
```dart
final state = _stateMachine.currentState;

if (state is ControlsVisiblePeekState) {
  // State Machine сам управляет таймерами и переходами
}
```

### 6 состояний контролов

1. **ControlsHiddenState** — все скрыто
2. **SeekingOverlayState** — только слайдер (перемотка при скрытых контролах)
3. **ControlsVisiblePeekState** — все видно, карусель peek (основной режим)
4. **ControlsVisibleExpandedState** — все видно, карусель развёрнута
5. **MenuOpenState** — меню открыто (автоскрытие заблокировано)
6. **ControlsVisiblePausedState** — пауза (автоскрытие отключено)

### События State Machine

- **ShowControlsEvent** — показать контролы
- **HideControlsEvent** — скрыть контролы
- **ToggleControlsEvent** — переключить видимость
- **SeekWhileHiddenEvent** — перемотка при скрытых контролах
- **UserInteractionEvent** — сброс таймера автоскрытия
- **FocusChangedEvent** — изменился фокус (для карусели)
- **MenuOpenedEvent / MenuClosedEvent** — блокировка автоскрытия
- **PlayerStatusChangedEvent** — изменился статус плеера (play/pause)
- **AutoHideTimerExpiredEvent** — истёк таймер автоскрытия
- **SeekingOverlayTimerExpiredEvent** — истёк таймер слайдера

**Аппаратная кнопка Back** (через `registerBackHandler`): при **ControlsVisibleExpandedState** — сворачивание карусели в peek (`FocusChangedEvent(null)`); при остальных видимых состояниях — `HideControlsEvent`; при скрытых контролах обработчик возвращает `false`, страница показывает подсказку «Назад ещё раз» и по второму нажатию выходит.

### Конфигурация видимости

Каждое состояние возвращает `ControlsVisibilityConfig`:

```dart
class ControlsVisibilityConfig {
  final bool showTopBar;              // Верхняя панель
  final bool showProgressSlider;      // Слайдер прогресса
  final bool showControlButtons;      // Кнопки управления
  final bool showCarousel;            // Карусель рекомендаций
  final CarouselMode carouselMode;    // hidden/peek/expanded
  final bool excludeFromFocus;        // Исключить из фокус-дерева
  final double topBarSlideOffset;     // Смещение для AnimatedSlide (-1.0 = скрыто вверху)
  final double bottomControlsSlideOffset; // Смещение для AnimatedSlide (1.0 = скрыто внизу)
}
```

**VideoControlsBuilder** использует эту конфигурацию для условного рендеринга и анимаций.

### Подробнее

См. [state/README.md](state/README.md) — полная документация State Machine с диаграммами переходов.

## Items (элементы)

Все элементы наследуют `FocusableItem` и получают автоматическое управление `FocusNode`.

### `ButtonItem`

Простая кнопка с автоматической обработкой Enter/Select.

```dart
ButtonItem(
  id: 'play_button',
  onPressed: () => controller.play(),
  child: Icon(Icons.play_arrow),
)
```

### `ProgressSliderItem`

Слайдер прогресса с кастомной обработкой стрелок для перемотки.

```dart
ProgressSliderItem(
  id: 'progress_slider',
  controller: controller,
  onSeekBackward: () => _seekBackward(),
  onSeekForward: () => _seekForward(),
)
```

**Особенности:**
- Стрелки влево/вправо = перемотка (возвращает `handled`)
- Остальные клавиши = навигация (возвращает `notHandled`)

### `QualitySelectorItem`

Селектор качества видео (кнопка-пилюля + выпадающее меню).

```dart
QualitySelectorItem(
  controller: controller,
  focusNode: focusNode,
  onRegisterOverlayFocus: (node) => _overlayFocusNode = node,
  onMenuOpened: () => _stateMachine.handleEvent(MenuOpenedEvent()),
  onMenuClosed: () => _stateMachine.handleEvent(MenuClosedEvent()),
)
```

**Особенности:**
- Открывает меню поверх контролов
- Фокус переводится на меню (через `onRegisterOverlayFocus`)
- Блокирует автоскрытие контролов через `MenuOpenedEvent`

### `SoundtrackSelectorItem`

Селектор аудиодорожки (аналогично `QualitySelectorItem`).

```dart
SoundtrackSelectorItem(
  controller: controller,
  focusNode: focusNode,
  onRegisterOverlayFocus: (node) => _overlayFocusNode = node,
  onMenuOpened: () => _stateMachine.handleEvent(MenuOpenedEvent()),
  onMenuClosed: () => _stateMachine.handleEvent(MenuClosedEvent()),
)
```

### `CustomWidgetItem`

Кастомный виджет с гибкой обработкой клавиш.

```dart
CustomWidgetItem(
  id: 'custom_widget',
  builder: (focusNode) => YourWidget(focusNode: focusNode),
  keyHandler: (event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      // Ваша логика
      return KeyHandlingResult.handled;
    }
    return KeyHandlingResult.notHandled;
  },
)
```

**Использование:**
- Карусель рекомендаций (`RecommendedCarouselRow`) обёрнута в `CustomWidgetItem`
- Позволяет создавать элементы с уникальным поведением

## Rows (ряды)

Все ряды наследуют `ControlRow` и имеют `index` для сортировки (навигация вверх/вниз).

### `TopBarRow`

Верхняя панель с фиксированной высотой и цветом фона.

```dart
TopBarRow(
  id: 'top_bar',
  index: 0,
  leftItems: [backButton],
  rightItems: [soundtrackSelector],
  height: 124,
  backgroundColor: Color(0xFF201B2E),
  horizontalPadding: 120,
  title: 'Название фильма', // опционально
)
```

**Использование:**
- Кнопка "Назад" (слева)
- Селектор аудиодорожки (справа)
- Опциональный заголовок видео

### `FullWidthRow`

Ряд с одним элементом на всю ширину.

```dart
FullWidthRow(
  id: 'slider_row',
  index: 1,
  items: [progressSlider],
  padding: EdgeInsets.symmetric(horizontal: 120),
)
```

**Использование:**
- Слайдер прогресса

### `ThreeZoneButtonRow`

Ряд с тремя зонами: слева | по центру | справа.

```dart
ThreeZoneButtonRow(
  id: 'control_buttons',
  index: 2,
  leftItems: [favoriteButton],
  centerItems: [rewindButton, playPauseButton, forwardButton],
  rightItems: [qualitySelector],
  spacing: 40,
  horizontalPadding: 120,
)
```

**Использование:**
- Избранное (слева)
- Основные кнопки управления (по центру)
- Селектор качества (справа)

**Особенности:**
- Навигация между зонами автоматическая
- Каждая зона может быть пустой (`[]`)

### `HorizontalButtonRow`

Простой ряд с горизонтальным расположением элементов.

```dart
HorizontalButtonRow(
  id: 'buttons_row',
  index: 1,
  items: [button1, button2, button3],
  alignment: MainAxisAlignment.center,
  spacing: 40,
)
```

**Использование:**
- Когда не нужна трёхзонная структура
- Простые горизонтальные списки кнопок

### `RecommendedCarouselRow`

Карусель "Рекомендуем посмотреть" с анимацией высоты.

```dart
RecommendedCarouselRow(
  key: _carouselRowKey, // для определения кликов вне карусели
  id: 'recommended_row',
  index: 3,
  carouselItems: [
    RecommendedCarouselItem(
      title: 'Фильм 1',
      image: Image.asset('path/to/preview.jpg'),
      mediaSource: RhsMediaSource(...),
    ),
    // ...
  ],
  onItemSelected: (index) => print('Выбран элемент $index'),
  onItemActivated: (item) => _playMedia(item.mediaSource),
  initialScrollIndex: 0,
)
```

**Особенности:**
- Режим **peek** (96.h): слегка выглядывает снизу, недоступна для фокуса
- Режим **expanded** (320.h): полностью развёрнута при фокусе
- Фокус всегда на крайнем левом слайде
- Стрелки влево/вправо = прокрутка карусели
- Enter = активация элемента (`onItemActivated`)

**Анимация:**
- Переход peek ↔ expanded через `AnimatedSize` (300ms)
- State Machine контролирует режим через `FocusChangedEvent`

## Navigation

**NavigationManager** управляет навигацией фокусом (Chain of Responsibility):

- Автоматическая сортировка рядов по `index`
- Обработка клавиш:
  1. Сначала элемент (`item.handleKey()`)
  2. Если `notHandled` → навигация фокусом
- Навигация **вверх/вниз** между рядами
- Навигация **влево/вправо** внутри ряда

**Пример цепочки:**
```
User: нажимает стрелку вправо
  ↓
ProgressSliderItem.handleKey() → handled (перемотка на 10 сек)
  ↓
NavigationManager: не вызывается

User: нажимает стрелку вниз на слайдере
  ↓
ProgressSliderItem.handleKey() → notHandled
  ↓
NavigationManager: переводит фокус на следующий ряд (кнопки)
```

## Builder

**VideoControlsBuilder** декларативно строит UI контролов:

```dart
VideoControlsBuilder(
  rows: [
    TopBarRow(...),
    FullWidthRow(...),
    ThreeZoneButtonRow(...),
    RecommendedCarouselRow(...),
  ],
  controlsVisible: state.visibilityConfig.excludeFromFocus == false,
  visibilityConfig: state.visibilityConfig,
  overlayBackgroundColor: Colors.black.withAlpha(128),
  onFocusChanged: (itemId) => _stateMachine.handleEvent(FocusChangedEvent(itemId)),
  initialFocusItemId: 'play_pause_button',
)
```

**Особенности:**
- Использует `ControlsVisibilityConfig` для условного рендеринга
- `AnimatedSlide` для плавного скрытия/показа рядов
- `ExcludeFocus` для исключения скрытых элементов из фокус-дерева
- Регистрирует колбэки навигации (`NavCallbacks`) для внешнего управления фокусом

## Пример использования

Полный пример с State Machine:

```dart
class VideoControls extends StatefulWidget {
  final RhsPlayerController controller;
  final VoidCallback onSwitchSource;
  final List<RecommendedCarouselItem> recommendedItems;
  final Duration? autoHideDelay;

  const VideoControls({
    super.key,
    required this.controller,
    required this.onSwitchSource,
    required this.recommendedItems,
    this.autoHideDelay = const Duration(seconds: 5),
  });

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  late final ControlsStateMachine _stateMachine;
  NavCallbacks? _nav;
  FocusNode? _overlayFocusNode;

  @override
  void initState() {
    super.initState();
    
    // Инициализация State Machine
    _stateMachine = ControlsStateMachine(
      config: StateConfig(
        autoHideDelay: widget.autoHideDelay,
        seekingOverlayDuration: const Duration(seconds: 2),
      ),
      initialState: const ControlsVisiblePeekState(),
      onStateChanged: (oldState, newState) {
        if (mounted) {
          setState(() {});
          _handleStateTransition(oldState, newState);
        }
      },
    );

    // Подписка на статус плеера
    widget.controller.addStatusListener((status) {
      _stateMachine.handleEvent(PlayerStatusChangedEvent(status));
    });
  }

  @override
  void dispose() {
    _stateMachine.dispose();
    super.dispose();
  }

  void _handleStateTransition(ControlsState oldState, ControlsState newState) {
    // Обработка переходов между состояниями
    if (newState is ControlsHiddenState) {
      // Убрать фокус с контролов
      _nav?.unfocusAll();
    } else if (oldState is ControlsHiddenState) {
      // Вернуть фокус на play/pause кнопку
      _nav?.requestFocus('play_pause_button');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _stateMachine.currentState;
    final config = state.visibilityConfig;

    return VideoControlsBuilder(
      rows: [
        // Ряд 0: Верхняя панель
        TopBarRow(
          id: 'top_bar',
          index: 0,
          leftItems: [
            ButtonItem(
              id: 'back_button',
              onPressed: () => Navigator.of(context).pop(),
              child: Icon(Icons.arrow_back),
            ),
          ],
          rightItems: [
            SoundtrackSelectorItem(
              controller: widget.controller,
              focusNode: FocusNode(),
              onRegisterOverlayFocus: (node) => _overlayFocusNode = node,
              onMenuOpened: () => _stateMachine.handleEvent(MenuOpenedEvent()),
              onMenuClosed: () => _stateMachine.handleEvent(MenuClosedEvent()),
            ),
          ],
        ),

        // Ряд 1: Слайдер прогресса
        FullWidthRow(
          id: 'progress_row',
          index: 1,
          items: [
            ProgressSliderItem(
              id: 'progress_slider',
              controller: widget.controller,
              onSeekBackward: () => _seekBy(-10),
              onSeekForward: () => _seekBy(10),
            ),
          ],
        ),

        // Ряд 2: Кнопки управления (три зоны)
        ThreeZoneButtonRow(
          id: 'control_buttons',
          index: 2,
          leftItems: [
            ButtonItem(
              id: 'favorite_button',
              onPressed: () => print('Добавить в избранное'),
              child: Icon(Icons.favorite_border),
            ),
          ],
          centerItems: [
            ButtonItem(
              id: 'rewind_button',
              onPressed: () => _seekBy(-10),
              child: Icon(Icons.replay_10),
            ),
            PlayPauseButton(
              id: 'play_pause_button',
              controller: widget.controller,
            ),
            ButtonItem(
              id: 'forward_button',
              onPressed: () => _seekBy(10),
              child: Icon(Icons.forward_10),
            ),
          ],
          rightItems: [
            QualitySelectorItem(
              controller: widget.controller,
              focusNode: FocusNode(),
              onRegisterOverlayFocus: (node) => _overlayFocusNode = node,
              onMenuOpened: () => _stateMachine.handleEvent(MenuOpenedEvent()),
              onMenuClosed: () => _stateMachine.handleEvent(MenuClosedEvent()),
            ),
          ],
        ),

        // Ряд 3: Карусель рекомендаций
        RecommendedCarouselRow(
          id: 'recommended_row',
          index: 3,
          carouselItems: widget.recommendedItems,
          onItemActivated: (item) {
            if (item.mediaSource != null) {
              widget.controller.setMediaSource(item.mediaSource!);
            }
          },
        ),
      ],
      controlsVisible: !config.excludeFromFocus,
      visibilityConfig: config,
      onFocusChanged: (itemId) => _stateMachine.handleEvent(FocusChangedEvent(itemId)),
      initialFocusItemId: 'play_pause_button',
      onNavCallbacksRegistered: (callbacks) => _nav = callbacks,
    );
  }

  void _seekBy(int seconds) {
    final currentPosition = widget.controller.position;
    final newPosition = currentPosition + Duration(seconds: seconds);
    widget.controller.seekTo(newPosition);
  }
}
```

## Преимущества архитектуры

### 1. Type-safe State Machine
- Sealed classes для состояний и событий
- Exhaustive checking — компилятор проверяет все case
- Централизованная логика переходов
- Отсутствие булевых флагов и race conditions

### 2. Декларативность
- Вся структура контролов описывается через список рядов
- Конфигурация видимости отделена от логики
- Легко читать и понимать структуру UI

### 3. Расширяемость
- Новые Items/Rows без изменения существующего кода
- Новые состояния через sealed classes (exhaustive checking)
- Новые ряды через `ControlsVisibilityConfig`

### 4. SOLID принципы
- **Single Responsibility**: каждый класс имеет одну ответственность
- **Open/Closed**: открыт для расширения, закрыт для модификации
- **Liskov Substitution**: все элементы взаимозаменяемы через `FocusableItem`
- **Interface Segregation**: минимальные интерфейсы
- **Dependency Inversion**: зависимость от абстракций

### 5. Автоматическое управление ресурсами
- FocusNode создаются/удаляются автоматически в Items
- Таймеры управляются State Machine
- Нет утечек памяти

### 6. Гибкая обработка клавиш
- Chain of Responsibility — каждый элемент обрабатывает клавиши по-своему
- Слайдер: стрелки = перемотка
- Кнопки: стрелки = навигация
- Карусель: стрелки = прокрутка

## Сравнение с императивным подходом

### Было (императивный код)
```dart
// Ручное управление FocusNode
late final FocusNode _playButtonFocusNode;
late final FocusNode _pauseButtonFocusNode;
// ... еще 10 FocusNode

@override
void initState() {
  _playButtonFocusNode = FocusNode();
  _pauseButtonFocusNode = FocusNode();
  // ... еще 10 инициализаций
}

@override
void dispose() {
  _playButtonFocusNode.dispose();
  _pauseButtonFocusNode.dispose();
  // ... еще 10 dispose
}

// Булевы флаги вместо State Machine
bool _controlsVisible = true;
bool _seekingOverlayVisible = false;
bool _isMenuOpen = false;

// Сложная логика с условиями
if (_controlsVisible && !_isMenuOpen && !_isPaused) {
  _startAutoHideTimer();
}

// Жесткая навигационная логика
KeyEventResult _handleArrowRight(FocusNode currentFocus) {
  if (currentFocus == _playButtonFocusNode) {
    _pauseButtonFocusNode.requestFocus();
    return KeyEventResult.handled;
  } else if (currentFocus == _pauseButtonFocusNode) {
    _nextButtonFocusNode.requestFocus();
    return KeyEventResult.handled;
  }
  // ... еще 20 if-else
}
```

### Стало (декларативный код + State Machine)
```dart
// State Machine управляет состояниями
final _stateMachine = ControlsStateMachine(
  config: StateConfig(autoHideDelay: Duration(seconds: 5)),
  onStateChanged: (old, new) => setState(() {}),
);

// Декларативное описание UI
VideoControlsBuilder(
  rows: [
    ThreeZoneButtonRow(
      id: 'buttons',
      index: 0,
      centerItems: [
        ButtonItem(id: 'play', onPressed: play, child: Icon(Icons.play)),
        ButtonItem(id: 'pause', onPressed: pause, child: Icon(Icons.pause)),
        ButtonItem(id: 'next', onPressed: next, child: Icon(Icons.next)),
      ],
    ),
  ],
  controlsVisible: !_stateMachine.currentState.visibilityConfig.excludeFromFocus,
  visibilityConfig: _stateMachine.currentState.visibilityConfig,
)

// FocusNode создаются автоматически
// Навигация между кнопками автоматическая
// Таймеры управляются State Machine
```

## Расширяемость

### Добавление нового Item

Создайте класс, наследующий `FocusableItem`:

```dart
class VolumeSliderItem implements FocusableItem {
  @override
  final String id;
  
  @override
  final FocusNode focusNode;
  
  final ValueNotifier<double> volumeNotifier;
  final double step;

  VolumeSliderItem({
    required this.id,
    required this.volumeNotifier,
    this.step = 0.1,
    FocusNode? focusNode,
  }) : focusNode = focusNode ?? FocusNode();

  @override
  KeyHandlingResult handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyHandlingResult.notHandled;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _changeVolume(step);
        return KeyHandlingResult.handled;

      case LogicalKeyboardKey.arrowDown:
        _changeVolume(-step);
        return KeyHandlingResult.handled;

      default:
        return KeyHandlingResult.notHandled;
    }
  }

  void _changeVolume(double delta) {
    final newVolume = (volumeNotifier.value + delta).clamp(0.0, 1.0);
    volumeNotifier.value = newVolume;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      child: ValueListenableBuilder<double>(
        valueListenable: volumeNotifier,
        builder: (context, volume, _) {
          return VolumeSlider(volume: volume);
        },
      ),
    );
  }
}
```

### Добавление нового Row

Создайте класс, наследующий `ControlRow`:

```dart
class GridRow extends BaseControlRow {
  final int crossAxisCount;
  final double spacing;

  GridRow({
    required super.id,
    required super.index,
    required super.items,
    this.crossAxisCount = 3,
    this.spacing = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      children: items.map((item) => item.build(context)).toList(),
    );
  }
}
```

### Добавление нового состояния

См. [state/README.md](state/README.md#расширяемость) — раздел "Добавление нового состояния".

**Краткая инструкция:**
1. Создать класс состояния в `controls_state.dart`
2. Определить `visibilityConfig`
3. Создать события в `controls_event.dart`
4. Добавить переходы в `ControlsStateMachine._transition()`

**Exhaustive checking** гарантирует, что компилятор проверит все case.

### Добавление нового ряда контролов с управлением видимостью

**Шаг 1:** Обновить `ControlsVisibilityConfig`:

```dart
class ControlsVisibilityConfig {
  final bool showSubtitlesRow; // <-- новое поле
  
  const ControlsVisibilityConfig({
    // ... остальные поля
    required this.showSubtitlesRow,
  });
  
  // Обновить все preset конфигурации
  static const visiblePeek = ControlsVisibilityConfig(
    // ...
    showSubtitlesRow: true,
  );
}
```

**Шаг 2:** Добавить условный рендеринг в `VideoControlsBuilder`:

```dart
if (config.showSubtitlesRow)
  widget.rows[N].build(context),
```

**Готово!** State Machine остаётся без изменений.

## Отладка

### Логирование переходов State Machine

Все переходы логируются через `dart:developer`:

```
ControlsStateMachine: Handle event: ShowControlsEvent() in state: ControlsHiddenState()
ControlsStateMachine: Transition: ControlsHiddenState() → ControlsVisiblePeekState()
ControlsStateMachine: Auto-hide timer started (5s)
```

Для просмотра логов используйте DevTools или фильтр по имени `ControlsStateMachine`.

### Логирование навигации

NavigationManager также логирует события:

```
NavigationManager: Arrow right -> Next item in row
NavigationManager: Arrow down -> Next row (index: 1 → 2)
```

## Производительность

- ✅ Минимальный overhead благодаря эффективной навигации
- ✅ Автоматическое управление памятью (FocusNode, таймеры)
- ✅ Ленивое создание виджетов
- ✅ Оптимизированная обработка событий клавиатуры
- ✅ AnimatedSlide для плавных анимаций без пересборки дерева

## См. также

- [state/README.md](state/README.md) — полная документация State Machine
- [builder/video_controls_builder.dart](builder/video_controls_builder.dart) — реализация билдера
- [navigation/navigation_manager.dart](navigation/navigation_manager.dart) — реализация навигации
