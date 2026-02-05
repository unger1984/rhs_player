import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';
import 'dart:async';

import 'package:rhs_player_example/shared/ui/theme/app_colors.dart';
import 'package:rhs_player_example/shared/ui/theme/app_durations.dart';
import 'package:rhs_player_example/shared/ui/theme/app_sizes.dart';
import 'package:rhs_player_example/shared/ui/theme/focus_decoration.dart';
import 'package:rxdart/rxdart.dart';

/// Трек с сегментом буфера перед ползунком.
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
      ..color = sliderTheme.activeTrackColor ?? AppColors.sliderActive;
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? AppColors.sliderInactive;
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

    // Сначала неактивный трек под ползунком до конца, затем буфер поверх
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
    this.glowSpread1 = AppSizes.focusGlowSpread1,
    this.glowBlur1 = AppSizes.focusGlowBlur1,
    this.glowSpread2 = AppSizes.focusGlowSpread2,
    this.glowBlur2 = AppSizes.focusGlowBlur2,
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
      paintFocusGlow(
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
  final void Function(Duration step) onSeekBackward;
  final void Function(Duration step) onSeekForward;
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
  Timer? _timerBackward;
  Timer? _timerForward;
  int _tickBackward = 0;
  int _tickForward = 0;

  void _startRepeatBackward() {
    _timerForward?.cancel();
    _timerForward = null;
    _tickBackward = 0;
    widget.onSeekBackward(AppDurations.seekStepForTick(0));
    _timerBackward = Timer.periodic(AppDurations.repeatInterval, (_) {
      if (!mounted) {
        _timerBackward?.cancel();
        return;
      }
      _tickBackward++;
      widget.onSeekBackward(AppDurations.seekStepForTick(_tickBackward));
    });
  }

  void _startRepeatForward() {
    _timerBackward?.cancel();
    _timerBackward = null;
    _tickForward = 0;
    widget.onSeekForward(AppDurations.seekStepForTick(0));
    _timerForward = Timer.periodic(AppDurations.repeatInterval, (_) {
      if (!mounted) {
        _timerForward?.cancel();
        return;
      }
      _tickForward++;
      widget.onSeekForward(AppDurations.seekStepForTick(_tickForward));
    });
  }

  void _stopRepeat() {
    _timerBackward?.cancel();
    _timerForward?.cancel();
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
              final trackHeight = hasFocus
                  ? AppSizes.sliderTrackFocused.h
                  : AppSizes.sliderTrackNormal.h;
              final thumbRadius = hasFocus
                  ? AppSizes.sliderThumbFocused.r
                  : AppSizes.sliderThumbNormal.r;
              final thumbShape = _ProgressThumbShape(
                radius: thumbRadius,
                borderWidth: hasFocus ? 0 : 2,
                borderColor: AppColors.sliderActive,
                fillColor: hasFocus
                    ? AppColors.sliderActive
                    : AppColors.sliderThumbFillUnfocused,
                isFocused: hasFocus,
                glowSpread1: AppSizes.focusGlowSpread1.r,
                glowBlur1: AppSizes.focusGlowBlur1.r,
                glowSpread2: AppSizes.focusGlowSpread2.r,
                glowBlur2: AppSizes.focusGlowBlur2.r,
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
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: trackHeight,
                      activeTrackColor: AppColors.sliderActive,
                      inactiveTrackColor: AppColors.sliderInactive,
                      trackShape: _ProgressTrackShape(
                        bufferedValue: bufferedValue,
                        bufferedColor: AppColors.sliderBuffered,
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
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours > 0
        ? duration.inHours.remainder(60).toString().padLeft(2, '0')
        : null;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${hours != null ? '$hours:' : ''}$minutes:$seconds';
  }
}
