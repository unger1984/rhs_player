import 'package:flutter/material.dart';
import 'package:rhs_player_example/features/player/ui/controls/core/focusable_item.dart';
import 'package:rhs_player_example/features/player/ui/controls/widgets/control_button.dart';

/// Элемент - кнопка управления
class ButtonItem extends BaseFocusableItem {
  final Widget child;
  final VoidCallback? onPressed;

  /// При удержании (repeatWhileHeld) вызывается с растущим шагом перемотки.
  final void Function(Duration step)? onPressedWithStep;
  final double? buttonSize;
  final double? buttonBorderRadius;

  /// При удержании вызывать повтор с растущим шагом (onPressedWithStep) или onPressed.
  final bool repeatWhileHeld;

  ButtonItem({
    required super.id,
    required this.child,
    this.onPressed,
    this.onPressedWithStep,
    super.focusNode,
    this.buttonSize,
    this.buttonBorderRadius,
    this.repeatWhileHeld = false,
  }) : assert(onPressed != null || onPressedWithStep != null);

  @override
  Widget build(BuildContext context) {
    return ControlButton(
      focusNode: focusNode,
      onPressed: onPressed,
      onPressedWithStep: onPressedWithStep,
      repeatWhileHeld: repeatWhileHeld,
      size: buttonSize,
      borderRadius: buttonBorderRadius,
      child: child,
    );
  }
}
