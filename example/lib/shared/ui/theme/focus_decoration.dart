import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player_example/shared/ui/theme/app_colors.dart';
import 'package:rhs_player_example/shared/ui/theme/app_sizes.dart';

/// Голубовато-белое неоновое свечение при фокусе (как на макете).
/// Единая реализация для всех компонентов вместо дублирования в 4 файлах.
List<BoxShadow> buildFocusGlow() {
  return [
    BoxShadow(
      color: AppColors.focusGlowBlue.withValues(alpha: 0.95),
      blurRadius: AppSizes.focusGlowBlur1.r,
      spreadRadius: AppSizes.focusGlowSpread1.r,
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.6),
      blurRadius: AppSizes.focusGlowBlur2.r,
      spreadRadius: AppSizes.focusGlowSpread2.r,
    ),
  ];
}

/// Рисование focus glow на Canvas (для progress_slider).
/// Используется в custom painters где нельзя применить BoxShadow.
void paintFocusGlow(
  Canvas canvas,
  Offset center,
  double radius, {
  double? glowSpread1,
  double? glowBlur1,
  double? glowSpread2,
  double? glowBlur2,
}) {
  final spread1 = glowSpread1 ?? AppSizes.focusGlowSpread1;
  final blur1 = glowBlur1 ?? AppSizes.focusGlowBlur1;
  final spread2 = glowSpread2 ?? AppSizes.focusGlowSpread2;
  final blur2 = glowBlur2 ?? AppSizes.focusGlowBlur2;

  // Внешнее голубое свечение
  final glowPaint = Paint()
    ..color = AppColors.focusGlowBlue.withValues(alpha: 0.95)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur1);
  canvas.drawCircle(center, radius + spread1, glowPaint);

  // Внутреннее белое свечение
  final whiteGlowPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.6)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur2);
  canvas.drawCircle(center, radius + spread2, whiteGlowPaint);
}
