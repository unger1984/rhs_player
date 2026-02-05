import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player_example/shared/ui/theme/app_colors.dart';
import 'package:rhs_player_example/shared/ui/theme/app_sizes.dart';
import 'package:rhs_player_example/shared/ui/theme/focus_decoration.dart';

/// Круглая кнопка Play/Pause 136x136: red/600 (обычное, фокус), red/500 (hover), red/700 (нажатие).
/// При фокусе и нажатии — неоновая обводка.
class PlayPauseButton extends StatefulWidget {
  final FocusNode focusNode;
  final bool isPlaying;
  final VoidCallback onPressed;

  const PlayPauseButton({
    super.key,
    required this.focusNode,
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton> {
  bool _pressed = false;
  bool _hovered = false;

  Color get _backgroundColor {
    if (_pressed) return AppColors.playPausePressed;
    if (_hovered) return AppColors.playPauseHover;
    return AppColors.playPauseNormal;
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
                width: AppSizes.buttonPlayPause.w,
                height: AppSizes.buttonPlayPause.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _backgroundColor,
                  boxShadow: showGlow ? buildFocusGlow() : null,
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
