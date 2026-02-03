# Система управления видео с Chain of Responsibility

Новая архитектура для управления видео плеером с поддержкой Android TV пульта.

## Основные концепции

### Chain of Responsibility для обработки клавиш

Каждый элемент управления сам решает, как обрабатывать клавиши пульта. Если элемент не обрабатывает событие - передает управление дальше по цепочке (навигация фокусом).

**Преимущества:**
- ✅ **Гибкость**: разные элементы могут по-разному реагировать на одни и те же клавиши
- ✅ **Инкапсуляция**: логика обработки клавиш находится внутри элемента
- ✅ **Расширяемость**: легко добавлять новые типы элементов с уникальным поведением
- ✅ **Переиспользуемость**: элементы независимы и самодостаточны

### Примеры различного поведения

- **Слайдер прогресса**: стрелки влево/вправо = перемотка на 10 сек
- **Ряд кнопок**: стрелки влево/вправо = переход между кнопками
- **Регулятор громкости**: стрелки вверх/вниз = изменение громкости
- **Список субтитров**: стрелки вверх/вниз = прокрутка списка

## Архитектура

### Core компоненты

#### `KeyHandlingResult`
Результат обработки клавиши элементом:
- `handled` - клавиша обработана, не передавать дальше
- `notHandled` - клавиша не обработана, передать навигационному менеджеру
- `handledWithNavigation` - клавиша обработана, но также нужна навигация

#### `FocusableItem`
Базовый интерфейс для любого элемента с фокусом:
- `id` - уникальный идентификатор
- `focusNode` - FocusNode для управления фокусом
- `handleKey()` - обработка клавиши (Chain of Responsibility)
- `build()` - построение виджета
- `dispose()` - очистка ресурсов

#### `ControlRow`
Абстрактный ряд элементов управления:
- `id` - уникальный идентификатор ряда
- `index` - индекс ряда (для определения порядка)
- `items` - список фокусируемых элементов
- `build()` - построение виджета ряда

### Items (элементы)

#### `ButtonItem`
Кнопка управления с автоматической обработкой Enter/Select.

```dart
ButtonItem(
  id: 'play_button',
  onPressed: () => controller.play(),
  child: Icon(Icons.play_arrow),
)
```

#### `ProgressSliderItem`
Слайдер прогресса с кастомной обработкой стрелок влево/вправо для перемотки.

```dart
ProgressSliderItem(
  id: 'progress_slider',
  controller: controller,
  onSeekBackward: () => controller.seekTo(...),
  onSeekForward: () => controller.seekTo(...),
)
```

#### `CustomWidgetItem`
Кастомный виджет с возможностью кастомной обработки клавиш.

```dart
CustomWidgetItem(
  id: 'custom_widget',
  builder: (focusNode) => YourWidget(focusNode: focusNode),
  keyHandler: (event) {
    // Ваша логика обработки клавиш
    return KeyHandlingResult.handled;
  },
)
```

### Rows (ряды)

#### `HorizontalButtonRow`
Ряд с горизонтальным расположением элементов.

```dart
HorizontalButtonRow(
  id: 'buttons_row',
  index: 1,
  items: [button1, button2, button3],
  alignment: MainAxisAlignment.center,
  spacing: 40,
)
```

#### `FullWidthRow`
Ряд с одним элементом на всю ширину.

```dart
FullWidthRow(
  id: 'slider_row',
  index: 0,
  items: [progressSlider],
  padding: EdgeInsets.symmetric(horizontal: 20),
)
```

### Navigation

#### `NavigationManager`
Менеджер навигации между элементами управления:
- Автоматическая сортировка рядов по индексу
- Обработка клавиш с Chain of Responsibility
- Навигация вверх/вниз между рядами
- Навигация влево/вправо внутри ряда

### Builder

#### `VideoControlsBuilder`
Билдер для декларативного построения системы управления.

```dart
VideoControlsBuilder(
  rows: [
    FullWidthRow(...),
    HorizontalButtonRow(...),
  ],
  backgroundColor: Colors.black.withAlpha(128),
  spacing: 20,
)
```

## Пример использования

```dart
class VideoControlsV2 extends StatelessWidget {
  final RhsPlayerController controller;
  final VoidCallback onSwitchSource;

  const VideoControlsV2({
    super.key,
    required this.controller,
    required this.onSwitchSource,
  });

  @override
  Widget build(BuildContext context) {
    return VideoControlsBuilder(
      rows: [
        // Ряд 0: Слайдер прогресса
        FullWidthRow(
          id: 'progress_row',
          index: 0,
          items: [
            ProgressSliderItem(
              id: 'progress_slider',
              controller: controller,
              onSeekBackward: _seekBackward,
              onSeekForward: _seekForward,
            ),
          ],
        ),

        // Ряд 1: Кнопки управления
        HorizontalButtonRow(
          id: 'control_buttons_row',
          index: 1,
          items: [
            ButtonItem(
              id: 'rewind_button',
              onPressed: _seekBackward,
              child: Icon(Icons.replay_10),
            ),
            ButtonItem(
              id: 'play_pause_button',
              onPressed: _togglePlayPause,
              child: Icon(Icons.play_arrow),
            ),
            ButtonItem(
              id: 'forward_button',
              onPressed: _seekForward,
              child: Icon(Icons.forward_10),
            ),
          ],
        ),
      ],
    );
  }

  void _seekBackward() {
    // Логика перемотки назад
  }

  void _seekForward() {
    // Логика перемотки вперед
  }

  void _togglePlayPause() {
    // Логика play/pause
  }
}
```

## Преимущества новой архитектуры

### 1. Декларативность
Вся структура управления описывается декларативно через список рядов и элементов.

### 2. Расширяемость
Легко добавлять новые элементы и ряды без изменения существующего кода.

### 3. SOLID принципы
- **Single Responsibility**: каждый класс имеет одну ответственность
- **Open/Closed**: открыт для расширения, закрыт для модификации
- **Liskov Substitution**: все элементы взаимозаменяемы
- **Interface Segregation**: минимальные интерфейсы
- **Dependency Inversion**: зависимость от абстракций

### 4. Автоматическое управление ресурсами
FocusNode создаются и удаляются автоматически.

### 5. Гибкая обработка клавиш
Каждый элемент может иметь свою логику обработки клавиш.

## Сравнение со старой реализацией

### Старая реализация
```dart
// Нужно создать FocusNode для каждой кнопки
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

### Новая реализация
```dart
VideoControlsBuilder(
  rows: [
    HorizontalButtonRow(
      id: 'buttons',
      index: 0,
      items: [
        ButtonItem(id: 'play', onPressed: play, child: Icon(Icons.play)),
        ButtonItem(id: 'pause', onPressed: pause, child: Icon(Icons.pause)),
        ButtonItem(id: 'next', onPressed: next, child: Icon(Icons.next)),
      ],
    ),
  ],
)
```

## Добавление новых элементов

### Создание кастомного элемента

```dart
class VolumeSliderItem extends BaseFocusableItem {
  final ValueNotifier<double> volumeNotifier;
  final double step;

  VolumeSliderItem({
    required super.id,
    required this.volumeNotifier,
    this.step = 0.1,
    super.focusNode,
  });

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
          return YourVolumeWidget(volume: volume);
        },
      ),
    );
  }
}
```

### Создание кастомного ряда

```dart
class GridRow extends BaseControlRow {
  final int crossAxisCount;

  GridRow({
    required super.id,
    required super.index,
    required super.items,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: crossAxisCount,
      children: items.map((item) => item.build(context)).toList(),
    );
  }
}
```

## Миграция со старой системы

1. Замените `VideoControls` на `VideoControlsV2`
2. Удалите все ручные `FocusNode` из state
3. Удалите методы навигации (`_handleArrowLeft`, `_handleArrowRight`, и т.д.)
4. Опишите структуру управления декларативно через `VideoControlsBuilder`

## Производительность

- Минимальный overhead благодаря эффективной навигации
- Автоматическое управление памятью
- Ленивое создание виджетов
- Оптимизированная обработка событий клавиатуры
