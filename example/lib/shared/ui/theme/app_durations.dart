/// Длительности анимаций и таймеров приложения.
/// Централизованное хранение всех временных интервалов.
abstract class AppDurations {
  // Таймеры контролов
  static const controlsAutoHide = Duration(seconds: 5); // Автоскрытие контролов
  static const seekingOverlay = Duration(
    seconds: 2,
  ); // Отображение слайдера при перемотке

  // Интервалы повтора перемотки при удержании
  static const repeatInterval = Duration(
    milliseconds: 300,
  ); // Интервал между тиками перемотки
  /// Шаг перемотки по номеру тика: с удержанием растёт (10 → 20 → 30 … до 60 сек).
  static Duration seekStepForTick(int tick) {
    const base = 10;
    const maxSec = 60;
    const ticksPerLevel = 3;
    const increment = 10;
    final level = tick ~/ ticksPerLevel;
    final sec = (base + level * increment).clamp(base, maxSec);
    return Duration(seconds: sec);
  }

  // Анимации
  static const controlsAnimation = Duration(
    milliseconds: 300,
  ); // Анимация показа/скрытия контролов
}
