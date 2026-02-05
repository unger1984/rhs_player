import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Голубовато-белое неоновое свечение при фокусе/нажатии (обводка как на макете)
List<BoxShadow> _focusGlow() => [
  BoxShadow(
    color: const Color(0xFFB3E5FC).withValues(alpha: 0.95),
    blurRadius: 20.r,
    spreadRadius: 4.r,
  ),
  BoxShadow(
    color: Colors.white.withValues(alpha: 0.6),
    blurRadius: 12.r,
    spreadRadius: 2.r,
  ),
];

/// Круглая кнопка Play/Pause 136x136: red/600 (обычное, фокус), red/500 (hover), red/700 (нажатие).
/// При фокусе и нажатии — неоновая обводка.
class PlayPauseControlButton extends StatefulWidget {
  final FocusNode focusNode;
  final bool isPlaying;
  final VoidCallback onPressed;

  const PlayPauseControlButton({
    super.key,
    required this.focusNode,
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  State<PlayPauseControlButton> createState() => _PlayPauseControlButtonState();
}

class _PlayPauseControlButtonState extends State<PlayPauseControlButton> {
  bool _pressed = false;
  bool _hovered = false;

  Color get _backgroundColor {
    if (_pressed) return Color(0xFFBD3418);
    if (_hovered) return Color(0xFFF45E3F);
    return Color(0xFFDF3F1E);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (event is KeyDownEvent) {
            setState(() => _pressed = true);
            widget.onPressed();
            return KeyEventResult.handled;
          }
          if (event is KeyUpEvent) {
            setState(() => _pressed = false);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) {
            widget.focusNode.requestFocus();
            setState(() => _pressed = true);
          },
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: Builder(
            builder: (context) {
              final focused = Focus.of(context).hasFocus;
              final showGlow = focused || _pressed;
              final iconColor = _pressed ? Colors.white70 : Colors.white;

              return Container(
                width: 136.w,
                height: 136.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _backgroundColor,
                  boxShadow: showGlow ? _focusGlow() : null,
                ),
                child: Center(
                  child: SizedBox(
                    width: 72.w,
                    height: 72.h,
                    child: ImageIcon(
                      AssetImage(
                        widget.isPlaying
                            ? 'assets/controls/pause.png'
                            : 'assets/controls/play.png',
                      ),
                      color: iconColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
