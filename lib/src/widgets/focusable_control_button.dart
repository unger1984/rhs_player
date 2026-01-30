import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/player_style.dart';

/// Кнопка управления с поддержкой фокуса для Android TV
class FocusableControlButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  const FocusableControlButton({
    super.key,
    required this.child,
    this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  @override
  State<FocusableControlButton> createState() => _FocusableControlButtonState();
}

class _FocusableControlButtonState extends State<FocusableControlButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        onLongPressStart: widget.onLongPressStart != null
            ? (_) => widget.onLongPressStart?.call()
            : null,
        onLongPressEnd: widget.onLongPressEnd != null
            ? (_) => widget.onLongPressEnd?.call()
            : null,
        child: AnimatedContainer(
          duration: Duration(milliseconds: PlayerStyle.focusAnimationMs),
          decoration: BoxDecoration(
            border: _isFocused
                ? Border.all(color: Colors.white, width: 2)
                : null,
            borderRadius: BorderRadius.circular(PlayerStyle.focusBorderRadius),
            color: _isFocused
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
          ),
          padding: const EdgeInsets.all(8),
          child: widget.child,
        ),
      ),
    );
  }
}
