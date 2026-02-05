/// Размеры UI компонентов приложения.
/// Централизованное хранение всех размеров для консистентности дизайна.
abstract class AppSizes {
  // Кнопки управления
  static const double buttonNormal = 112; // Обычная круглая кнопка
  static const double buttonPlayPause = 136; // Кнопка play/pause (больше)
  static const double buttonBorderRadius =
      16; // Радиус скругления квадратных кнопок

  // Слайдер прогресса
  static const double sliderThumbNormal = 16; // Ползунок без фокуса
  static const double sliderThumbFocused = 20; // Ползунок с фокусом
  static const double sliderTrackNormal = 12; // Трек без фокуса
  static const double sliderTrackFocused = 16; // Трек с фокусом

  // Focus glow параметры
  static const double focusGlowSpread1 =
      4; // Внешнее распространение голубого свечения
  static const double focusGlowBlur1 = 20; // Размытие голубого свечения
  static const double focusGlowSpread2 =
      2; // Внешнее распространение белого свечения
  static const double focusGlowBlur2 = 12; // Размытие белого свечения
}
