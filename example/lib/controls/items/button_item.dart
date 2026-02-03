import 'package:flutter/material.dart';
import 'package:rhs_player_example/control_button.dart';
import 'package:rhs_player_example/controls/core/focusable_item.dart';

/// Элемент - кнопка управления
class ButtonItem extends BaseFocusableItem {
  final Widget child;
  final VoidCallback onPressed;

  ButtonItem({
    required super.id,
    required this.child,
    required this.onPressed,
    super.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return ControlButton(
      focusNode: focusNode,
      onPressed: onPressed,
      child: child,
    );
  }
}
