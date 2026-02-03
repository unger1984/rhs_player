import 'dart:async';

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

/// Цвет фона: без фокуса и при фокусе — Grey/800
const Color _kButtonBgNormal = Color(0xFF201B2E);

/// Цвет фона при наведении (hover) — Grey/700
const Color _kButtonBgHover = Color(0xFF2A303C);

/// Цвет фона при нажатии — Grey/900
const Color _kButtonBgPressed = Color(0xFF0C0D1D);

/// Цвет иконки при нажатии (Gray/800)
const Color _kIconPressed = Color(0xFF201B2E);

/// Интервал повтора при удержании кнопки (перемотка и т.п.)
const Duration _kRepeatInterval = Duration(milliseconds: 300);

/// Универсальная кнопка для Android TV (круглая 112x112 или квадратная с радиусом).
/// При фокусе и нажатии — неоновая обводка как на макете.
/// Если [repeatWhileHeld] true — при удержании [onPressed] вызывается повторно до отпускания.
class ControlButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final FocusNode focusNode;
  final bool enabled;

  /// При удержании кнопки вызывать onPressed повторно до отпускания.
  final bool repeatWhileHeld;

  /// Размер стороны. По умолчанию 112 — круглая кнопка.
  final double? size;

  /// Радиус скругления. Если задан — кнопка квадратная с закруглёнными краями.
  final double? borderRadius;

  const ControlButton({
    super.key,
    required this.onPressed,
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

  double get _size => (widget.size ?? 112).r;
  double? get _borderRadius =>
      widget.borderRadius != null ? (widget.borderRadius!).r : null;

  void _startRepeat() {
    _repeatTimer?.cancel();
    if (!widget.repeatWhileHeld || !widget.enabled) return;
    widget.onPressed();
    _repeatTimer = Timer.periodic(_kRepeatInterval, (_) {
      if (!mounted || !widget.enabled) {
        _repeatTimer?.cancel();
        return;
      }
      widget.onPressed();
    });
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
              widget.onPressed();
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
            setState(() => _pressed = true);
            if (widget.repeatWhileHeld) {
              _startRepeat();
            } else {
              widget.onPressed();
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
              : (widget.enabled ? widget.onPressed : null),
          child: Builder(
            builder: (context) {
              final focused = Focus.of(context).hasFocus;
              final showGlow = (focused || _pressed) && widget.enabled;
              final bgColor = !widget.enabled
                  ? _kButtonBgNormal
                  : _pressed
                  ? _kButtonBgPressed
                  : _hovered
                  ? _kButtonBgHover
                  : _kButtonBgNormal;
              final iconColor = !widget.enabled
                  ? Colors.white38
                  : _pressed
                  ? _kIconPressed
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
                  boxShadow: showGlow ? _focusGlow() : null,
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
