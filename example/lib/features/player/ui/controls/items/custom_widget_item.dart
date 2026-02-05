import 'package:flutter/material.dart';
import 'package:rhs_player_example/features/player/ui/controls/core/focusable_item.dart';
import 'package:rhs_player_example/features/player/ui/controls/core/key_handling_result.dart';

/// Элемент - кастомный виджет с возможностью кастомной обработки клавиш
class CustomWidgetItem extends BaseFocusableItem {
  final Widget Function(FocusNode focusNode) builder;
  final KeyHandlingResult Function(KeyEvent event)? keyHandler;

  CustomWidgetItem({
    required super.id,
    required this.builder,
    this.keyHandler,
    super.focusNode,
  });

  @override
  KeyHandlingResult handleKey(KeyEvent event) {
    if (keyHandler != null) {
      return keyHandler!(event);
    }
    return super.handleKey(event);
  }

  @override
  Widget build(BuildContext context) {
    return builder(focusNode);
  }
}
