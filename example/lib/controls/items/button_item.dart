import 'package:flutter/material.dart';
import 'package:rhs_player_example/control_button.dart';
import 'package:rhs_player_example/controls/core/focusable_item.dart';

/// Элемент - кнопка управления
class ButtonItem extends BaseFocusableItem {
  final Widget child;
  final VoidCallback onPressed;
  final double? buttonSize;
  final double? buttonBorderRadius;

  /// При удержании вызывать onPressed повторно до отпускания (для перемотки).
  final bool repeatWhileHeld;

  ButtonItem({
    required super.id,
    required this.child,
    required this.onPressed,
    super.focusNode,
    this.buttonSize,
    this.buttonBorderRadius,
    this.repeatWhileHeld = false,
  });

  @override
  Widget build(BuildContext context) {
    return ControlButton(
      focusNode: focusNode,
      onPressed: onPressed,
      repeatWhileHeld: repeatWhileHeld,
      size: buttonSize,
      borderRadius: buttonBorderRadius,
      child: child,
    );
  }
}
