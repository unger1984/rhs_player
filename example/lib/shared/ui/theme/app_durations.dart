/// Длительности анимаций и таймеров приложения.
/// Централизованное хранение всех временных интервалов.
abstract class AppDurations {
  // Таймеры контролов
  static const controlsAutoHide = Duration(seconds: 5); // Автоскрытие контролов
  static const seekingOverlay = Duration(
    seconds: 2,
  ); // Отображение слайдера при перемотке

  // Интервалы повтора
  static const repeatInterval = Duration(
    milliseconds: 300,
  ); // Повтор при удержании кнопки

  // Анимации
  static const controlsAnimation = Duration(
    milliseconds: 300,
  ); // Анимация показа/скрытия контролов
}
