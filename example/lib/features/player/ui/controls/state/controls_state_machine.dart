import 'dart:async';
import 'dart:developer' as developer;

import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/features/player/ui/controls/state/controls_event.dart';
import 'package:rhs_player_example/features/player/ui/controls/state/controls_state.dart';
import 'package:rhs_player_example/features/player/ui/controls/state/state_config.dart';

/// State Machine для управления состояниями контролов плеера.
///
/// Отвечает за:
/// 1. Управление состоянием (currentState)
/// 2. Обработку событий и переходы между состояниями (handleEvent)
/// 3. Управление таймерами (автоскрытие, слайдер перемотки)
/// 4. Валидацию переходов (через exhaustive switch на sealed classes)
/// 5. Логирование переходов для отладки
///
/// Использование:
/// ```dart
/// final machine = ControlsStateMachine(
///   config: StateConfig(autoHideDelay: Duration(seconds: 5)),
///   onStateChanged: (oldState, newState) {
///     setState(() {}); // обновить UI
///   },
/// );
///
/// machine.handleEvent(ShowControlsEvent());
/// ```
class ControlsStateMachine {
  /// Текущее состояние State Machine
  ControlsState _currentState;

  /// Конфигурация таймеров и поведения
  final StateConfig config;

  /// Callback, вызываемый при смене состояния.
  /// Используется для обновления UI через setState().
  void Function(ControlsState oldState, ControlsState newState)? onStateChanged;

  /// Таймер автоскрытия контролов (используется в ControlsVisiblePeekState)
  Timer? _autoHideTimer;

  /// Таймер скрытия слайдера после перемотки (используется в SeekingOverlayState)
  Timer? _seekingOverlayTimer;

  ControlsStateMachine({
    required this.config,
    this.onStateChanged,
    ControlsState? initialState,
  }) : _currentState = initialState ?? const ControlsVisiblePeekState() {
    // Запускаем таймеры для начального состояния
    _startTimersForState(_currentState);
    developer.log(
      'ControlsStateMachine initialized with state: $_currentState',
      name: 'ControlsStateMachine',
    );
  }

  /// Получить текущее состояние
  ControlsState get currentState => _currentState;

  // ==================== Обработка событий и переходы ====================

  /// Обработать событие и выполнить переход состояния (если необходимо).
  ///
  /// Логика:
  /// 1. Определить новое состояние через _transition() (exhaustive switch)
  /// 2. Если состояние изменилось - выполнить переход через _transitionTo()
  /// 3. Если нужен только сброс таймера (UserInteractionEvent) - сбросить таймер
  void handleEvent(ControlsEvent event) {
    developer.log(
      'Handle event: $event in state: $_currentState',
      name: 'ControlsStateMachine',
    );

    // Особый случай: UserInteractionEvent не меняет состояние, только сбрасывает таймер
    if (event is UserInteractionEvent) {
      if (_currentState is ControlsVisiblePeekState ||
          _currentState is ControlsVisibleExpandedState) {
        _resetAutoHideTimer();
      }
      return;
    }

    // Определить новое состояние на основе текущего состояния и события
    final newState = _transition(_currentState, event);

    if (newState != null) {
      // Если transition вернул то же состояние (например, SeekingOverlayState при повторной перемотке) -
      // это сигнал сбросить таймер, а не переходить
      if (newState.runtimeType == _currentState.runtimeType &&
          newState is SeekingOverlayState) {
        developer.log(
          'Reset timer for $newState',
          name: 'ControlsStateMachine',
        );
        _resetSeekingOverlayTimer();
        return;
      }

      // Выполнить переход в новое состояние
      if (newState != _currentState) {
        _transitionTo(newState);
      }
    } else {
      developer.log(
        'No transition for event: $event in state: $_currentState',
        name: 'ControlsStateMachine',
      );
    }
  }

  /// Определить новое состояние на основе текущего состояния и события.
  ///
  /// Использует exhaustive switch на sealed classes - компилятор проверит,
  /// что все комбинации состояний и событий обработаны.
  ///
  /// Возвращает:
  /// - ControlsState - новое состояние для перехода
  /// - null - переход невозможен/не требуется
  ControlsState? _transition(ControlsState current, ControlsEvent event) {
    // Exhaustive switch на tuple (текущее состояние, событие)
    return switch ((current, event)) {
      // ==================== Переходы из ControlsHiddenState ====================

      // Показать контролы при взаимодействии
      (ControlsHiddenState(), ShowControlsEvent()) =>
        const ControlsVisiblePeekState(),

      // Начать перемотку - показать только слайдер
      (ControlsHiddenState(), SeekWhileHiddenEvent()) =>
        const SeekingOverlayState(),

      // ==================== Переходы из SeekingOverlayState ====================

      // Таймер истёк - скрыть слайдер
      (SeekingOverlayState(), SeekingOverlayTimerExpiredEvent()) =>
        const ControlsHiddenState(),

      // Показать полные контролы при взаимодействии
      (SeekingOverlayState(), ShowControlsEvent()) =>
        const ControlsVisiblePeekState(),

      // Повторная перемотка - сбросить таймер (возвращаем то же состояние)
      (SeekingOverlayState(), SeekWhileHiddenEvent()) =>
        const SeekingOverlayState(),

      // ==================== Переходы из ControlsVisiblePeekState ====================

      // Таймер автоскрытия истёк - скрыть контролы
      (ControlsVisiblePeekState(), AutoHideTimerExpiredEvent()) =>
        const ControlsHiddenState(),

      // Фокус на карусель - развернуть карусель
      (
        ControlsVisiblePeekState(),
        FocusChangedEvent(itemId: 'recommended_row_carousel'),
      ) =>
        const ControlsVisibleExpandedState(),

      // Открыто меню - заблокировать автоскрытие
      (ControlsVisiblePeekState(), MenuOpenedEvent()) => MenuOpenState(
        previousState: current,
      ),

      // Плеер на паузе - отключить автоскрытие
      (
        ControlsVisiblePeekState(),
        PlayerStatusChangedEvent(status: RhsPlayerStatusPaused()),
      ) =>
        const ControlsVisiblePausedState(),

      // Скрыть контролы по запросу
      (ControlsVisiblePeekState(), HideControlsEvent()) =>
        const ControlsHiddenState(),

      // Переключить видимость (скрыть)
      (ControlsVisiblePeekState(), ToggleControlsEvent()) =>
        const ControlsHiddenState(),

      // ==================== Переходы из ControlsVisibleExpandedState ====================

      // Фокус ушёл с карусели - свернуть карусель
      (ControlsVisibleExpandedState(), FocusChangedEvent(:final itemId))
          when itemId != 'recommended_row_carousel' =>
        const ControlsVisiblePeekState(),

      // Открыто меню - заблокировать автоскрытие
      (ControlsVisibleExpandedState(), MenuOpenedEvent()) => MenuOpenState(
        previousState: current,
      ),

      // Плеер на паузе - отключить автоскрытие
      (
        ControlsVisibleExpandedState(),
        PlayerStatusChangedEvent(status: RhsPlayerStatusPaused()),
      ) =>
        const ControlsVisiblePausedState(),

      // Скрыть контролы по запросу
      (ControlsVisibleExpandedState(), HideControlsEvent()) =>
        const ControlsHiddenState(),

      // Переключить видимость (скрыть)
      (ControlsVisibleExpandedState(), ToggleControlsEvent()) =>
        const ControlsHiddenState(),

      // ==================== Переходы из MenuOpenState ====================

      // Меню закрыто - вернуться в предыдущее состояние
      (MenuOpenState(:final previousState), MenuClosedEvent()) => previousState,

      // ==================== Переходы из ControlsVisiblePausedState ====================

      // Плеер возобновил воспроизведение - запустить автоскрытие
      (
        ControlsVisiblePausedState(),
        PlayerStatusChangedEvent(
          status: RhsPlayerStatusPlaying() || RhsPlayerStatusLoading(),
        ),
      ) =>
        const ControlsVisiblePeekState(),

      // Фокус на карусель - развернуть карусель (даже на паузе)
      (
        ControlsVisiblePausedState(),
        FocusChangedEvent(itemId: 'recommended_row_carousel'),
      ) =>
        const ControlsVisibleExpandedState(),

      // Открыто меню
      (ControlsVisiblePausedState(), MenuOpenedEvent()) => MenuOpenState(
        previousState: current,
      ),

      // Скрыть контролы по запросу
      (ControlsVisiblePausedState(), HideControlsEvent()) =>
        const ControlsHiddenState(),

      // Переключить видимость (скрыть)
      (ControlsVisiblePausedState(), ToggleControlsEvent()) =>
        const ControlsHiddenState(),

      // ==================== Неприменимые/игнорируемые события ====================

      // Все остальные комбинации - переход не требуется
      _ => null,
    };
  }

  /// Выполнить переход в новое состояние.
  ///
  /// Действия при переходе:
  /// 1. Отменить все активные таймеры
  /// 2. Установить новое состояние
  /// 3. Запустить таймеры для нового состояния
  /// 4. Уведомить слушателей через onStateChanged
  /// 5. Логировать переход
  void _transitionTo(ControlsState newState) {
    final oldState = _currentState;

    developer.log(
      'Transition: $oldState → $newState',
      name: 'ControlsStateMachine',
    );

    // Отменить все таймеры перед переходом
    _cancelAllTimers();

    // Установить новое состояние
    _currentState = newState;

    // Запустить таймеры для нового состояния
    _startTimersForState(newState);

    // Уведомить слушателей
    onStateChanged?.call(oldState, newState);
  }

  // ==================== Управление таймерами ====================

  /// Запустить таймеры для данного состояния (если требуется).
  void _startTimersForState(ControlsState state) {
    switch (state) {
      // SeekingOverlayState: таймер скрытия слайдера (2 сек)
      case SeekingOverlayState():
        _startSeekingOverlayTimer();

      // ControlsVisiblePeekState: таймер автоскрытия (5 сек)
      case ControlsVisiblePeekState():
        _startAutoHideTimer();

      // Остальные состояния: таймеры не требуются
      case ControlsHiddenState():
      case ControlsVisibleExpandedState():
      case MenuOpenState():
      case ControlsVisiblePausedState():
        break;
    }
  }

  /// Запустить таймер автоскрытия контролов.
  void _startAutoHideTimer() {
    final delay = config.autoHideDelay;
    if (delay == null || delay == Duration.zero) {
      developer.log(
        'Auto-hide disabled (delay is null or zero)',
        name: 'ControlsStateMachine',
      );
      return;
    }

    _autoHideTimer = Timer(delay, () {
      developer.log('Auto-hide timer expired', name: 'ControlsStateMachine');
      handleEvent(const AutoHideTimerExpiredEvent());
    });

    developer.log(
      'Auto-hide timer started (${delay.inSeconds}s)',
      name: 'ControlsStateMachine',
    );
  }

  /// Сбросить таймер автоскрытия (отменить и запустить заново).
  void _resetAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    _startAutoHideTimer();
    developer.log('Auto-hide timer reset', name: 'ControlsStateMachine');
  }

  /// Запустить таймер скрытия слайдера перемотки.
  void _startSeekingOverlayTimer() {
    _seekingOverlayTimer = Timer(config.seekingOverlayDuration, () {
      developer.log(
        'Seeking overlay timer expired',
        name: 'ControlsStateMachine',
      );
      handleEvent(const SeekingOverlayTimerExpiredEvent());
    });

    developer.log(
      'Seeking overlay timer started (${config.seekingOverlayDuration.inSeconds}s)',
      name: 'ControlsStateMachine',
    );
  }

  /// Сбросить таймер слайдера перемотки (отменить и запустить заново).
  void _resetSeekingOverlayTimer() {
    _seekingOverlayTimer?.cancel();
    _seekingOverlayTimer = null;
    _startSeekingOverlayTimer();
    developer.log('Seeking overlay timer reset', name: 'ControlsStateMachine');
  }

  /// Отменить все активные таймеры.
  void _cancelAllTimers() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    _seekingOverlayTimer?.cancel();
    _seekingOverlayTimer = null;
  }

  // ==================== Очистка ресурсов ====================

  /// Освободить ресурсы (отменить таймеры).
  /// Вызывать в dispose() виджета.
  void dispose() {
    developer.log(
      'ControlsStateMachine disposed',
      name: 'ControlsStateMachine',
    );
    _cancelAllTimers();
  }
}
