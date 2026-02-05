import 'package:rhs_player/rhs_player.dart';

/// События для управления State Machine контролов плеера.
///
/// Используется sealed class для exhaustive checking - компилятор Dart проверит,
/// что все типы событий обработаны в switch expressions.
///
/// События делятся на категории:
/// - Пользовательские действия (показать/скрыть/переключить)
/// - Навигация и фокус
/// - Перемотка
/// - Взаимодействие
/// - Меню
/// - Таймеры
/// - Статус плеера

sealed class ControlsEvent {
  const ControlsEvent();
}

// ==================== Пользовательские действия ====================

/// Показать контролы (переход в ControlsVisiblePeekState).
///
/// Используется при:
/// - Нажатии OK/Enter/стрелок при скрытых контролах
/// - Клике мышью на видео
/// - Жестах на видео
class ShowControlsEvent extends ControlsEvent {
  /// Сбросить фокус на начальный элемент (play_pause_button) после показа контролов.
  /// Используется когда показываем контролы из приоритетного обработчика клавиш.
  final bool resetFocus;

  const ShowControlsEvent({this.resetFocus = false});

  @override
  String toString() => 'ShowControlsEvent(resetFocus: $resetFocus)';
}

/// Скрыть контролы (переход в ControlsHiddenState).
///
/// Используется при:
/// - Истечении таймера автоскрытия
/// - Явном запросе на скрытие (например, аппаратная кнопка Back)
class HideControlsEvent extends ControlsEvent {
  const HideControlsEvent();

  @override
  String toString() => 'HideControlsEvent()';
}

/// Переключить видимость контролов (toggle).
///
/// Используется при:
/// - Нажатии Info/Menu на пульте
/// - Двойном клике на видео
class ToggleControlsEvent extends ControlsEvent {
  const ToggleControlsEvent();

  @override
  String toString() => 'ToggleControlsEvent()';
}

// ==================== Навигация и фокус ====================

/// Изменился фокус на элементе контролов.
///
/// Используется для:
/// - Определения перехода в/из состояния ControlsVisibleExpandedState
///   (когда фокус на карусели или уходит с неё)
/// - Логирования и отладки фокуса
class FocusChangedEvent extends ControlsEvent {
  /// Id элемента, на котором сейчас фокус.
  /// null = фокус не на элементах контролов (например, на оверлее меню).
  final String? itemId;

  const FocusChangedEvent(this.itemId);

  @override
  String toString() => 'FocusChangedEvent(itemId: $itemId)';
}

// ==================== Перемотка ====================

/// Перемотка при скрытых контролах (стрелки влево/вправо).
///
/// Используется для перехода в SeekingOverlayState - показываем только слайдер
/// на 2 секунды для визуальной обратной связи о перемотке.
///
/// При повторных событиях SeekWhileHiddenEvent таймер сбрасывается.
class SeekWhileHiddenEvent extends ControlsEvent {
  const SeekWhileHiddenEvent();

  @override
  String toString() => 'SeekWhileHiddenEvent()';
}

// ==================== Взаимодействие ====================

/// Любое взаимодействие пользователя с контролами.
///
/// Используется для:
/// - Сброса таймера автоскрытия в ControlsVisiblePeekState
/// - Продления видимости контролов при активном использовании
///
/// Не вызывает переход состояния, только сбрасывает таймер.
class UserInteractionEvent extends ControlsEvent {
  const UserInteractionEvent();

  @override
  String toString() => 'UserInteractionEvent()';
}

// ==================== Меню ====================

/// Открыто меню (качества видео или выбора аудиодорожки).
///
/// Переход в MenuOpenState с сохранением предыдущего состояния.
/// Автоскрытие контролов блокируется, пока меню открыто.
class MenuOpenedEvent extends ControlsEvent {
  const MenuOpenedEvent();

  @override
  String toString() => 'MenuOpenedEvent()';
}

/// Меню закрыто.
///
/// Возврат в предыдущее состояние (ControlsVisiblePeekState или ControlsVisibleExpandedState).
/// Перезапуск таймера автоскрытия.
class MenuClosedEvent extends ControlsEvent {
  const MenuClosedEvent();

  @override
  String toString() => 'MenuClosedEvent()';
}

// ==================== Таймеры ====================

/// Истёк таймер автоскрытия контролов.
///
/// Переход из ControlsVisiblePeekState в ControlsHiddenState.
/// НЕ срабатывает если:
/// - Плеер на паузе
/// - Открыто меню
/// - Фокус на карусели (в этом случае таймер перезапускается)
class AutoHideTimerExpiredEvent extends ControlsEvent {
  const AutoHideTimerExpiredEvent();

  @override
  String toString() => 'AutoHideTimerExpiredEvent()';
}

/// Истёк таймер показа слайдера при перемотке.
///
/// Переход из SeekingOverlayState в ControlsHiddenState.
/// Слайдер автоматически скрывается через 2 секунды после последней перемотки.
class SeekingOverlayTimerExpiredEvent extends ControlsEvent {
  const SeekingOverlayTimerExpiredEvent();

  @override
  String toString() => 'SeekingOverlayTimerExpiredEvent()';
}

// ==================== Статус плеера ====================

/// Изменился статус плеера (playing/paused/loading/error).
///
/// Используется для:
/// - Перехода в ControlsVisiblePausedState при паузе (отключение автоскрытия)
/// - Возврата из ControlsVisiblePausedState при возобновлении воспроизведения
class PlayerStatusChangedEvent extends ControlsEvent {
  final RhsPlayerStatus status;

  const PlayerStatusChangedEvent(this.status);

  @override
  String toString() => 'PlayerStatusChangedEvent(status: $status)';
}
