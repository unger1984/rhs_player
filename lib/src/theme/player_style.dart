import 'package:flutter/material.dart';

/// Константы стилей виджетов плеера.
abstract final class PlayerStyle {
  PlayerStyle._();

  /// Цвет фона выпадающего меню.
  static const Color menuBackground = Color(0xFF1F1F1F);

  /// Длительность анимации фокуса/контейнера (мс).
  static const int focusAnimationMs = 150;

  /// Радиус скругления кнопок и рамки фокуса.
  static const double focusBorderRadius = 8;

  /// Размер иконки кнопок перемотки и fullscreen.
  static const double iconButtonSize = 32;

  /// Размер иконки Play/Pause.
  static const double playPauseIconSize = 64;

  /// Горизонтальный отступ прогресс-бара (как у Slider).
  static const double progressBarHorizontalPadding = 24.0;

  /// Высота области прогресс-бара.
  static const double progressBarHeight = 48;

  /// Толщина дорожки прогресс-бара.
  static const double progressTrackHeight = 2;

  /// Радиус ползунка слайдера.
  static const double sliderThumbRadius = 6;

  /// Радиус оверлея ползунка.
  static const double sliderOverlayRadius = 12;
}
