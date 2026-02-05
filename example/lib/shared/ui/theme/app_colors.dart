import 'package:flutter/material.dart';

/// Палитра цветов приложения.
/// Централизованное хранение всех цветов для упрощения изменения дизайна.
abstract class AppColors {
  // Цвета кнопок управления
  static const buttonBgNormal = Color(0xFF201B2E); // Grey/800
  static const buttonBgHover = Color(0xFF2A303C); // Grey/700
  static const buttonBgPressed = Color(0xFF0C0D1D); // Grey/900
  static const iconPressed = Color(0xFF201B2E); // Grey/800

  // Цвета кнопки play/pause
  static const playPauseNormal = Color(0xFFDF3F1E); // Red/600
  static const playPauseHover = Color(0xFFF45E3F); // Red/500
  static const playPausePressed = Color(0xFFBD3418); // Red/700

  // Цвета слайдера прогресса
  static const sliderActive = Color(0xFFF45E3F); // Red/500
  static const sliderInactive = Color(0xFF757B8A); // Grey/500
  static const sliderBuffered = Color(0xFFB0B4BF); // Grey/400
  static const sliderThumbFillUnfocused = Color(0xFFEFF1F5); // Grey/100

  // Focus glow (голубовато-белое неоновое свечение)
  static const focusGlowBlue = Color(0xFFB3E5FC);

  // Прочее
  static const backgroundDark = Color(0xFF2A303C); // Grey/700
}
