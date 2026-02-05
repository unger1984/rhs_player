import 'package:rhs_player_example/features/player/ui/controls/state/controls_visibility_config.dart';

/// Состояния контролов плеера.
///
/// Используется sealed class для exhaustive checking - компилятор Dart проверит,
/// что все состояния обработаны в switch expressions.
///
/// Каждое состояние определяет:
/// - Конфигурацию видимости рядов (visibilityConfig)
/// - Поведение таймеров (управляется в ControlsStateMachine)
/// - Допустимые переходы в другие состояния (определены в ControlsStateMachine)
///
/// Всего 6 состояний:
/// 1. ControlsHiddenState - все скрыто
/// 2. SeekingOverlayState - только слайдер (перемотка)
/// 3. ControlsVisiblePeekState - все видно, карусель peek
/// 4. ControlsVisibleExpandedState - все видно, карусель развёрнута
/// 5. MenuOpenState - меню открыто
/// 6. ControlsVisiblePausedState - пауза (автоскрытие отключено)

sealed class ControlsState {
  const ControlsState();

  /// Конфигурация видимости рядов для текущего состояния.
  /// Используется в VideoControlsBuilder для условного рендеринга и анимаций.
  ControlsVisibilityConfig get visibilityConfig;
}

// ==================== Состояние: Все контролы скрыты ====================

/// Состояние "Контролы скрыты" (состояние А из документации).
///
/// Все ряды контролов уезжают за границу экрана через AnimatedSlide.
/// Фокус переводится на _rootFocusNode, элементы исключены из фокус-дерева.
///
/// **Переходы:**
/// - OK/Enter/стрелки вверх/вниз → ControlsVisiblePeekState
/// - Стрелки влево/вправо (перемотка) → SeekingOverlayState
///
/// **Таймеры:** нет
class ControlsHiddenState extends ControlsState {
  const ControlsHiddenState();

  @override
  ControlsVisibilityConfig get visibilityConfig =>
      ControlsVisibilityConfig.hidden;

  @override
  String toString() => 'ControlsHiddenState()';
}

// ==================== Состояние: Перемотка со скрытыми контролами ====================

/// Состояние "Перемотка со скрытыми контролами".
///
/// Показывается только ProgressSlider на 2 секунды для визуальной обратной связи.
/// Используется когда пользователь перематывает видео стрелками влево/вправо
/// при скрытых контролах.
///
/// **Переходы:**
/// - Таймер истёк (2 сек) → ControlsHiddenState
/// - OK/Enter/стрелки вверх/вниз → ControlsVisiblePeekState
/// - Повторная перемотка (влево/вправо) → остаёмся в SeekingOverlayState (сброс таймера)
///
/// **Таймеры:** seekingOverlayTimer (2 секунды)
class SeekingOverlayState extends ControlsState {
  const SeekingOverlayState();

  @override
  ControlsVisibilityConfig get visibilityConfig =>
      ControlsVisibilityConfig.seekingOverlay;

  @override
  String toString() => 'SeekingOverlayState()';
}

// ==================== Состояние: Контролы видны, карусель peek ====================

/// Состояние "Контролы видны, карусель peek" (состояние Б из документации).
///
/// Все ряды контролов видны на своих местах.
/// Карусель рекомендаций в режиме peek - высота 96.h, слегка выглядывает снизу.
/// Фокус доступен на всех элементах, кроме карусели.
///
/// Это основной режим взаимодействия с контролами.
///
/// **Переходы:**
/// - Таймер автоскрытия (5 сек) → ControlsHiddenState
/// - Фокус на carousel → ControlsVisibleExpandedState
/// - Открыто меню → MenuOpenState
/// - Плеер на паузе → ControlsVisiblePausedState
/// - Взаимодействие пользователя → остаёмся в ControlsVisiblePeekState (сброс таймера)
///
/// **Таймеры:** autoHideTimer (5 секунд)
///
/// **Исключения автоскрытия:**
/// - Плеер на паузе
/// - Открыто меню
/// - Фокус на карусели (в этом случае переход в ControlsVisibleExpandedState)
class ControlsVisiblePeekState extends ControlsState {
  const ControlsVisiblePeekState();

  @override
  ControlsVisibilityConfig get visibilityConfig =>
      ControlsVisibilityConfig.visiblePeek;

  @override
  String toString() => 'ControlsVisiblePeekState()';
}

// ==================== Состояние: Контролы видны, карусель развёрнута ====================

/// Состояние "Контролы видны, карусель развёрнута" (состояние В из документации).
///
/// Все ряды контролов видны на своих местах.
/// Карусель рекомендаций полностью развёрнута - высота 320.h.
/// Фокус находится на карусели.
///
/// Автоскрытие ОТКЛЮЧЕНО - пока пользователь работает с каруселью, контролы остаются видимыми.
/// При попытке запуска таймера автоскрытия он сразу перезапускается.
///
/// **Переходы:**
/// - Фокус уходит с carousel → ControlsVisiblePeekState
/// - Клик мышью вне карусели → ControlsVisiblePeekState (+ фокус на play_pause_button)
/// - Открыто меню → MenuOpenState
/// - Плеер на паузе → ControlsVisiblePausedState
///
/// **Таймеры:** нет (автоскрытие отключено)
class ControlsVisibleExpandedState extends ControlsState {
  const ControlsVisibleExpandedState();

  @override
  ControlsVisibilityConfig get visibilityConfig =>
      ControlsVisibilityConfig.visibleExpanded;

  @override
  String toString() => 'ControlsVisibleExpandedState()';
}

// ==================== Состояние: Меню открыто ====================

/// Состояние "Меню открыто" (меню качества видео или выбора аудиодорожки).
///
/// Контролы остаются видимыми в той же конфигурации, что и до открытия меню
/// (peek или expanded - зависит от предыдущего состояния).
///
/// Автоскрытие ЗАБЛОКИРОВАНО - контролы не скрываются, пока меню открыто.
/// Фокус переводится на overlay меню (_overlayFocusNode).
///
/// **Переходы:**
/// - Меню закрыто → возврат в previousState (ControlsVisiblePeekState или ControlsVisibleExpandedState)
///
/// **Таймеры:** нет (автоскрытие заблокировано)
class MenuOpenState extends ControlsState {
  /// Состояние, из которого перешли в MenuOpenState.
  /// При закрытии меню возвращаемся в это состояние.
  final ControlsState previousState;

  const MenuOpenState({required this.previousState});

  /// Наследуем конфигурацию видимости от предыдущего состояния.
  /// Меню не меняет layout контролов, только блокирует автоскрытие и управляет фокусом.
  @override
  ControlsVisibilityConfig get visibilityConfig =>
      previousState.visibilityConfig;

  @override
  String toString() => 'MenuOpenState(previousState: $previousState)';
}

// ==================== Состояние: Плеер на паузе ====================

/// Состояние "Плеер на паузе".
///
/// Контролы видны в конфигурации peek (как в ControlsVisiblePeekState).
/// Автоскрытие ОТКЛЮЧЕНО - пока видео на паузе, контролы остаются видимыми.
///
/// Это удобно для пользователя: при паузе он может спокойно изучить контролы,
/// выбрать качество, переключить дорожку и т.д. без риска автоскрытия.
///
/// **Переходы:**
/// - Play (возобновление воспроизведения) → ControlsVisiblePeekState (+ запуск таймера автоскрытия)
/// - Открыто меню → MenuOpenState
/// - Фокус на carousel → ControlsVisibleExpandedState
///
/// **Таймеры:** нет (автоскрытие отключено)
class ControlsVisiblePausedState extends ControlsState {
  const ControlsVisiblePausedState();

  @override
  ControlsVisibilityConfig get visibilityConfig =>
      ControlsVisibilityConfig.visiblePeek;

  @override
  String toString() => 'ControlsVisiblePausedState()';
}
