import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rxdart/rxdart.dart';

/// Интервал повтора перемотки при удержании стрелки (как у кнопок перемотки).
const Duration _kSeekRepeatInterval = Duration(milliseconds: 300);

/// Цвета слайдера прогресса
const Color _activeColor = Color(0xFFF45E3F);
const Color _inactiveColor = Color(0xFF757B8A);
const Color _bufferedColor = Color(0xFFB0B4BF);
const Color _thumbFillUnfocused = Color(0xFFEFF1F5);

/// Голубовато-белое неоновое свечение при фокусе (как у кнопок).
void _paintFocusGlow(
  Canvas canvas,
  Offset center,
  double radius, {
  required double glowSpread1,
  required double glowBlur1,
  required double glowSpread2,
  required double glowBlur2,
}) {
  final glowPaint = Paint()
    ..color = const Color(0xFFB3E5FC).withValues(alpha: 0.95)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur1);
  canvas.drawCircle(center, radius + glowSpread1, glowPaint);
  final whiteGlowPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.6)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur2);
  canvas.drawCircle(center, radius + glowSpread2, whiteGlowPaint);
}

/// Трек с сегментом буфера перед ползунком (цвет B0B4BF).
class _ProgressTrackShape extends RoundedRectSliderTrackShape {
  final double bufferedValue;
  final Color bufferedColor;

  const _ProgressTrackShape({
    required this.bufferedValue,
    required this.bufferedColor,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = true,
    double additionalActiveTrackHeight = 2,
    required TextDirection textDirection,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 0;
    if (trackHeight <= 0) return;

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final trackRadius = Radius.circular(trackRect.height / 2);
    final isLTR = textDirection == TextDirection.ltr;

    final activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? _activeColor;
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? _inactiveColor;
    final bufferedPaint = Paint()..color = bufferedColor;

    final left = trackRect.left;
    final right = trackRect.right;
    final thumbX = thumbCenter.dx;
    final valueClamped = bufferedValue.clamp(0.0, 1.0);
    final bufferedX = isLTR
        ? left + trackRect.width * valueClamped
        : right - trackRect.width * valueClamped;

    void drawRRect(
      double fromX,
      double toX,
      Paint paint, {
      Radius? leftR,
      Radius? rightR,
    }) {
      if (fromX >= toX) return;
      final l = fromX < toX ? fromX : toX;
      final r = fromX < toX ? toX : fromX;
      context.canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          l,
          trackRect.top,
          r,
          trackRect.bottom,
          topLeft: leftR ?? trackRadius,
          bottomLeft: leftR ?? trackRadius,
          topRight: rightR ?? trackRadius,
          bottomRight: rightR ?? trackRadius,
        ),
        paint,
      );
    }

    // Сначала неактивный трек (757B8A) под ползунком до конца, затем буфер поверх.
    if (isLTR) {
      if (thumbX < right) {
        drawRRect(thumbX, right, inactivePaint, leftR: Radius.zero);
      }
      if (thumbX < bufferedX) {
        drawRRect(
          thumbX,
          bufferedX,
          bufferedPaint,
          leftR: Radius.zero,
          rightR: trackRadius,
        );
      }
      if (left < thumbX) {
        drawRRect(left, thumbX, activePaint, rightR: Radius.zero);
      }
    } else {
      if (left < thumbX) {
        drawRRect(left, thumbX, inactivePaint, rightR: Radius.zero);
      }
      if (bufferedX < thumbX) {
        drawRRect(
          bufferedX,
          thumbX,
          bufferedPaint,
          leftR: trackRadius,
          rightR: Radius.zero,
        );
      }
      if (thumbX < right) {
        drawRRect(thumbX, right, activePaint, leftR: Radius.zero);
      }
    }
  }
}

/// Ползунок: без фокуса — круг с бордером, с фокусом — заливка целиком и свечение.
class _ProgressThumbShape extends SliderComponentShape {
  final double radius;
  final double borderWidth;
  final Color borderColor;
  final Color fillColor;
  final bool isFocused;
  final double glowSpread1;
  final double glowBlur1;
  final double glowSpread2;
  final double glowBlur2;

  const _ProgressThumbShape({
    required this.radius,
    required this.borderWidth,
    required this.borderColor,
    required this.fillColor,
    this.isFocused = false,
    this.glowSpread1 = 4,
    this.glowBlur1 = 20,
    this.glowSpread2 = 2,
    this.glowBlur2 = 12,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(radius, radius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    if (isFocused) {
      _paintFocusGlow(
        canvas,
        center,
        radius,
        glowSpread1: glowSpread1,
        glowBlur1: glowBlur1,
        glowSpread2: glowSpread2,
        glowBlur2: glowBlur2,
      );
    }
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);
    if (borderWidth > 0) {
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawCircle(center, radius - borderWidth / 2, borderPaint);
    }
  }
}

/// Слайдер прогресса воспроизведения с поддержкой перемотки клавишами.
/// Трек: 12.h без фокуса, 16.h с фокусом. Ползунок: 16.r с бордером без фокуса, 40.r заливка с фокусом.
/// Влево/вправо — перемотка (при удержании — непрерывная), вверх/вниз — переход фокуса на другой ряд.
class ProgressSlider extends StatefulWidget {
  final RhsPlayerController controller;
  final FocusNode focusNode;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;

  const ProgressSlider({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSeekBackward,
    required this.onSeekForward,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  @override
  State<ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends State<ProgressSlider> {
  Timer? _repeatTimer;

  void _startRepeatBackward() {
    _repeatTimer?.cancel();
    widget.onSeekBackward();
    _repeatTimer = Timer.periodic(_kSeekRepeatInterval, (_) {
      if (!mounted) {
        _repeatTimer?.cancel();
        return;
      }
      widget.onSeekBackward();
    });
  }

  void _startRepeatForward() {
    _repeatTimer?.cancel();
    widget.onSeekForward();
    _repeatTimer = Timer.periodic(_kSeekRepeatInterval, (_) {
      if (!mounted) {
        _repeatTimer?.cancel();
        return;
      }
      widget.onSeekForward();
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
    final progressStream =
        Rx.combineLatest2<
          RhsPositionData,
          Duration,
          ({RhsPositionData position, Duration buffered})
        >(
          widget.controller.positionDataStream,
          widget.controller.bufferedPositionStream,
          (p, b) => (position: p, buffered: b),
        );
    return StreamBuilder<({RhsPositionData position, Duration buffered})>(
      stream: progressStream,
      builder: (context, snapshot) {
        final positionData =
            snapshot.data?.position ??
            const RhsPositionData(Duration.zero, Duration.zero);
        final position = positionData.position;
        final duration = positionData.duration;
        final buffered = snapshot.data?.buffered ?? Duration.zero;
        final bufferedValue = duration.inMilliseconds > 0
            ? (buffered.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              )
            : 0.0;

        return Focus(
          focusNode: widget.focusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              switch (event.logicalKey) {
                case LogicalKeyboardKey.arrowLeft:
                  _startRepeatBackward();
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowRight:
                  _startRepeatForward();
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowUp:
                  final up = widget.onNavigateUp;
                  if (up != null) {
                    up();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                case LogicalKeyboardKey.arrowDown:
                  final down = widget.onNavigateDown;
                  if (down != null) {
                    down();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                default:
                  return KeyEventResult.ignored;
              }
            }
            if (event is KeyUpEvent) {
              switch (event.logicalKey) {
                case LogicalKeyboardKey.arrowLeft:
                case LogicalKeyboardKey.arrowRight:
                  _stopRepeat();
                  return KeyEventResult.handled;
                default:
                  return KeyEventResult.ignored;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Builder(
            builder: (context) {
              final hasFocus = Focus.of(context).hasFocus;
              final trackHeight = hasFocus ? 16.h : 12.h;
              final thumbRadius = hasFocus ? 20.r : 16.r;
              final thumbShape = _ProgressThumbShape(
                radius: thumbRadius,
                borderWidth: hasFocus ? 0 : 2,
                borderColor: _activeColor,
                fillColor: hasFocus ? _activeColor : _thumbFillUnfocused,
                isFocused: hasFocus,
                glowSpread1: 4.r,
                glowBlur1: 20.r,
                glowSpread2: 2.r,
                glowBlur2: 12.r,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: 16.w, bottom: 4.h),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style: TextStyle(color: Colors.white, fontSize: 24.sp),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: trackHeight,
                        activeTrackColor: _activeColor,
                        inactiveTrackColor: _inactiveColor,
                        trackShape: _ProgressTrackShape(
                          bufferedValue: bufferedValue,
                          bufferedColor: _bufferedColor,
                        ),
                        thumbShape: thumbShape,
                        overlayShape: RoundSliderOverlayShape(
                          overlayRadius: thumbRadius,
                        ),
                      ),
                      child: Slider(
                        value: position.inMilliseconds.toDouble().clamp(
                          0.0,
                          duration.inMilliseconds.toDouble(),
                        ),
                        min: 0.0,
                        max: duration.inMilliseconds.toDouble(),
                        onChanged: (value) {
                          widget.controller.seekTo(
                            Duration(milliseconds: value.toInt()),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
