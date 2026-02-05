/// Конфигурация параметров State Machine контролов плеера.
///
/// Содержит настройки таймеров и поведения автоскрытия контролов.
/// Эти параметры не влияют на логику переходов, но управляют временными интервалами.
library;

/// Конфигурация State Machine контролов
class StateConfig {
  /// Задержка перед автоматическим скрытием контролов.
  ///
  /// - null или Duration.zero = автоскрытие отключено
  /// - Обычно 5 секунд
  /// - Применяется только в состоянии ControlsVisiblePeekState
  /// - НЕ применяется когда плеер на паузе, открыто меню или фокус на карусели
  final Duration? autoHideDelay;

  /// Длительность показа слайдера при перемотке со скрытыми контролами.
  ///
  /// - Используется в состоянии SeekingOverlayState
  /// - После истечения таймера возврат в ControlsHiddenState
  /// - Обычно 2 секунды
  final Duration seekingOverlayDuration;

  const StateConfig({
    this.autoHideDelay = const Duration(seconds: 5),
    this.seekingOverlayDuration = const Duration(seconds: 2),
  });

  @override
  String toString() {
    return 'StateConfig('
        'autoHideDelay: $autoHideDelay, '
        'seekingOverlayDuration: $seekingOverlayDuration)';
  }
}
