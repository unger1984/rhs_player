import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Кнопка управления для Android TV с поддержкой фокуса
class ControlButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final FocusNode focusNode;

  const ControlButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;

          return GestureDetector(
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: focused ? Colors.blue.withAlpha(51) : null,
                border: focused
                    ? Border.all(color: Colors.blue, width: 3)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
