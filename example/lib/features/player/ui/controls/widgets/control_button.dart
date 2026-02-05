import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player_example/shared/ui/theme/app_colors.dart';
import 'package:rhs_player_example/shared/ui/theme/app_durations.dart';
import 'package:rhs_player_example/shared/ui/theme/app_sizes.dart';
import 'package:rhs_player_example/shared/ui/theme/focus_decoration.dart';

/// Универсальная кнопка для Android TV (круглая 112x112 или квадратная с радиусом).
/// При фокусе и нажатии — неоновая обводка как на макете.
/// Если [repeatWhileHeld] true — при удержании вызывается повтор с растущим шагом ([onPressedWithStep]) или [onPressed].
class ControlButton extends StatefulWidget {
  /// Разовый клик. Обязателен, если [onPressedWithStep] не задан.
  final VoidCallback? onPressed;

  /// При удержании (repeatWhileHeld) вызывается с растущим шагом перемотки.
  final void Function(Duration step)? onPressedWithStep;
  final Widget child;
  final FocusNode focusNode;
  final bool enabled;

  /// При удержании кнопки вызывать повтор с растущим шагом (onPressedWithStep) или onPressed.
  final bool repeatWhileHeld;

  /// Размер стороны. По умолчанию AppSizes.buttonNormal — круглая кнопка.
  final double? size;

  /// Радиус скругления. Если задан — кнопка квадратная с закруглёнными краями.
  final double? borderRadius;

  const ControlButton({
    super.key,
    this.onPressed,
    this.onPressedWithStep,
    required this.child,
    required this.focusNode,
    this.enabled = true,
    this.repeatWhileHeld = false,
    this.size,
    this.borderRadius,
  });

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  bool _pressed = false;
  bool _hovered = false;
  Timer? _repeatTimer;
  int _repeatTick = 0;

  double get _size => (widget.size ?? AppSizes.buttonNormal).r;
  double? get _borderRadius =>
      widget.borderRadius != null ? (widget.borderRadius!).r : null;

  void _startRepeat() {
    _repeatTimer?.cancel();
    if (!widget.repeatWhileHeld || !widget.enabled) return;
    if (widget.onPressedWithStep != null) {
      _repeatTick = 0;
      widget.onPressedWithStep!(AppDurations.seekStepForTick(0));
      _repeatTimer = Timer.periodic(AppDurations.repeatInterval, (_) {
        if (!mounted || !widget.enabled) {
          _repeatTimer?.cancel();
          return;
        }
        _repeatTick++;
        widget.onPressedWithStep!(AppDurations.seekStepForTick(_repeatTick));
      });
    } else {
      widget.onPressed?.call();
      _repeatTimer = Timer.periodic(AppDurations.repeatInterval, (_) {
        if (!mounted || !widget.enabled) {
          _repeatTimer?.cancel();
          return;
        }
        widget.onPressed?.call();
      });
    }
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (!widget.enabled) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (event is KeyDownEvent) {
            setState(() => _pressed = true);
            if (widget.repeatWhileHeld) {
              _startRepeat();
            } else {
              if (widget.onPressedWithStep != null) {
                widget.onPressedWithStep!(const Duration(seconds: 10));
              } else {
                widget.onPressed?.call();
              }
            }
            return KeyEventResult.handled;
          }
          if (event is KeyUpEvent) {
            setState(() => _pressed = false);
            _stopRepeat();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: (_) {
            if (!widget.enabled) return;
            widget.focusNode.requestFocus();
            setState(() => _pressed = true);
            if (widget.repeatWhileHeld) {
              _startRepeat();
            } else {
              if (widget.onPressedWithStep != null) {
                widget.onPressedWithStep!(const Duration(seconds: 10));
              } else {
                widget.onPressed?.call();
              }
            }
          },
          onTapUp: (_) {
            setState(() => _pressed = false);
            _stopRepeat();
          },
          onTapCancel: () {
            setState(() => _pressed = false);
            _stopRepeat();
          },
          onTap: widget.repeatWhileHeld
              ? null
              : (widget.enabled
                    ? (widget.onPressed ??
                          () => widget.onPressedWithStep?.call(
                            const Duration(seconds: 10),
                          ))
                    : null),
          child: Builder(
            builder: (context) {
              final focused = Focus.of(context).hasFocus;
              final showGlow = (focused || _pressed) && widget.enabled;
              final bgColor = !widget.enabled
                  ? AppColors.buttonBgNormal
                  : _pressed
                  ? AppColors.buttonBgPressed
                  : _hovered
                  ? AppColors.buttonBgHover
                  : AppColors.buttonBgNormal;
              final iconColor = !widget.enabled
                  ? Colors.white38
                  : _pressed
                  ? AppColors.iconPressed
                  : Colors.white;

              return Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: _borderRadius == null
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: _borderRadius != null
                      ? BorderRadius.circular(_borderRadius!)
                      : null,
                  color: bgColor,
                  boxShadow: showGlow ? buildFocusGlow() : null,
                ),
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(color: iconColor, size: 32.r),
                    child: widget.child,
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
