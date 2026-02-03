import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/controls/builder/video_controls_builder.dart';
import 'package:rhs_player_example/controls/core/focusable_item.dart';
import 'package:rhs_player_example/controls/core/key_handling_result.dart';
import 'package:rhs_player_example/progress_slider.dart';

/// Элемент - слайдер прогресса с кастомной обработкой стрелок
class ProgressSliderItem extends BaseFocusableItem {
  final RhsPlayerController controller;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;

  ProgressSliderItem({
    required super.id,
    required this.controller,
    required this.onSeekBackward,
    required this.onSeekForward,
    super.focusNode,
  });

  @override
  KeyHandlingResult handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyHandlingResult.notHandled;

    // Слайдер обрабатывает стрелки влево/вправо для перемотки
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        onSeekBackward();
        return KeyHandlingResult.handled;

      case LogicalKeyboardKey.arrowRight:
        onSeekForward();
        return KeyHandlingResult.handled;

      // Стрелки вверх/вниз передаем для навигации
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowDown:
        return KeyHandlingResult.notHandled;

      default:
        return KeyHandlingResult.notHandled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = VideoControlsNavigation.maybeOf(context);
    return ProgressSlider(
      controller: controller,
      focusNode: focusNode,
      onSeekBackward: onSeekBackward,
      onSeekForward: onSeekForward,
      onNavigateUp: nav?.onNavigateUp,
      onNavigateDown: nav?.onNavigateDown,
    );
  }
}
