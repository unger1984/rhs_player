# План реализации анимированного скрытия контролов

## Архитектура решения

Контролы разделены на две группы:

- **Верхняя группа**: `TopBarRow` (index: 0)
- **Нижняя группа**: `ProgressSlider`, `ThreeZoneButtonRow`, `RecommendedCarouselRow` (index: 1-3)

При скрытии:

- Верхняя группа уезжает вверх (offset по Y отрицательный)
- Нижняя группа уезжает вниз (offset по Y положительный)

При показе - обратная анимация с выездом из-за границ экрана.

## Этап 1: Добавить состояние видимости в VideoControls

**Файл**: `example/lib/video_controls.dart`

Добавить в `_VideoControlsState`:

- `bool _controlsVisible = true` - флаг видимости контролов
- `Timer? _hideTimer` - таймер автоскрытия (опционально, для будущего)
- Методы `_showControls()` и `_hideControls()` для управления видимостью
- Передавать `_controlsVisible` в `VideoControlsBuilder` через новый параметр

**Зачем**: Централизованное управление состоянием видимости контролов.

## Этап 2: Обернуть ряды в AnimatedSlide виджеты

**Файл**: `example/lib/controls/builder/video_controls_builder.dart`

Модифицировать `VideoControlsBuilder`:

- Добавить параметр `bool controlsVisible` (по умолчанию `true`)
- В методе `build()` обернуть рендеринг рядов:
  - **TopBarRow** (первый ряд, index 0): обернуть в `AnimatedSlide` с `offset: Offset(0, controlsVisible ? 0 : -1)` и `duration: Duration(milliseconds: 300)`
  - **Нижние ряды** (index 1+): обернуть всю группу в `AnimatedSlide` с `offset: Offset(0, controlsVisible ? 0 : 1)` и `duration: Duration(milliseconds: 300)`

**Детали реализации**:

```dart
// В build() метод VideoControlsBuilder
Column(
  mainAxisAlignment: MainAxisAlignment.start,
  crossAxisAlignment: widget.crossAxisAlignment,
  children: [
    if (widget.rows.isNotEmpty) ...[
      // Верхняя группа (TopBarRow) - уезжает вверх
      AnimatedSlide(
        offset: Offset(0, widget.controlsVisible ? 0 : -1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: widget.rows.first.build(context),
      ),
      const Spacer(),
      // Нижняя группа - уезжает вниз
      AnimatedSlide(
        offset: Offset(0, widget.controlsVisible ? 0 : 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: widget.crossAxisAlignment,
          children: [
            for (var i = 1; i < widget.rows.length; i++) ...[
              if (i > 1) SizedBox(height: widget.spacing.h),
              widget.rows[i].build(context),
            ],
          ],
        ),
      ),
    ],
  ],
)
```

**Зачем**: `AnimatedSlide` автоматически анимирует смещение виджетов. Offset(-1) означает смещение на 100% высоты виджета вверх, Offset(1) - вниз.

## Этап 3: Добавить триггеры показа/скрытия

**Файл**: `example/lib/video_controls.dart`

Варианты триггеров (выбрать один или комбинацию):

### Вариант A: По таймеру (автоскрытие)

- При инициализации запустить таймер на 5 секунд
- После истечения вызвать `_hideControls()`
- При любом взаимодействии (клавиша, движение мыши) вызвать `_showControls()` и перезапустить таймер

### Вариант B: По клавише (например, Info/Menu на пульте)

- Добавить обработчик `KeyDownEvent` для `LogicalKeyboardKey.info` или другой клавиши
- Toggle состояние `_controlsVisible`

### Вариант C: При воспроизведении

- Слушать `controller.playerStatusStream`
- Скрывать контролы через 3-5 секунд после начала воспроизведения
- Показывать при паузе

**Рекомендация**: Начать с варианта B (клавиша) для тестирования, затем добавить вариант A (автоскрытие).

## Этап 4: Обработка фокуса при скрытых контролах

**Файл**: `example/lib/controls/builder/video_controls_builder.dart`

Проблема: когда контролы скрыты, фокус все еще может быть на элементах, что вызовет проблемы навигации.

Решение:

- При скрытии контролов (`controlsVisible = false`) убрать фокус с элементов управления
- Можно использовать `FocusScope.of(context).unfocus()` или перевести фокус на корневой `_rootFocusNode`
- При показе контролов восстановить фокус на последний активный элемент через `_navigationManager.requestFocusOnId()`

**Детали**:

- Добавить `didUpdateWidget()` проверку изменения `widget.controlsVisible`
- Если изменился с `true` на `false`: сохранить текущий `_navigationManager.getFocusedItemId()` и снять фокус
- Если изменился с `false` на `true`: восстановить фокус через `requestFocusOnId()`

## Этап 5: Тестирование и доработка

1. Запустить пример: `cd example && fvm flutter run`
2. Проверить плавность анимации (300ms с `Curves.easeInOut`)
3. Проверить, что TopBarRow полностью уезжает за верхнюю границу
4. Проверить, что нижние ряды полностью уезжают за нижнюю границу
5. Проверить навигацию фокуса при скрытых/показанных контролах
6. При необходимости скорректировать:
   - Длительность анимации (можно увеличить до 400-500ms для более плавного эффекта)
   - Кривую анимации (попробовать `Curves.easeInOutCubic` для более "кинематографичного" эффекта)
   - Offset значения (если виджеты не полностью скрываются)

## Технические детали

### AnimatedSlide

- Использует `Transform.translate` под капотом
- Offset в относительных единицах (1.0 = 100% размера виджета)
- Автоматически обрабатывает анимацию при изменении offset
- Не требует AnimationController (implicit animation)

### Альтернативный подход (если AnimatedSlide не подойдет)

Если потребуется больше контроля, можно использовать:

- `AnimatedPositioned` внутри `Stack`
- Явный `AnimationController` с `SlideTransition`
- `AnimatedContainer` с `Transform`

Но для данной задачи `AnimatedSlide` - оптимальное решение по соотношению простота/функциональность.

## Файлы для изменения

1. `example/lib/video_controls.dart` - добавить состояние и логику управления
2. `example/lib/controls/builder/video_controls_builder.dart` - обернуть ряды в AnimatedSlide
3. Опционально: `example/lib/player_screen.dart` - если нужно управлять видимостью извне

## Команды для проверки

```bash
# Форматирование
fvm dart format .

# Анализ
fvm flutter analyze .

# Запуск примера
cd example && fvm flutter run
```

## TODO

- [ ] Добавить состояние видимости (\_controlsVisible, \_hideTimer) и методы управления в VideoControls
- [ ] Обернуть TopBarRow и нижние ряды в AnimatedSlide виджеты в VideoControlsBuilder
- [ ] Добавить триггеры показа/скрытия контролов (клавиша или таймер)
- [ ] Реализовать сохранение/восстановление фокуса при скрытии/показе контролов
- [ ] Протестировать анимацию и доработать параметры (duration, curve, offset)
