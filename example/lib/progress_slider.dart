import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rxdart/rxdart.dart';

/// Цвета слайдера прогресса
const Color _activeColor = Color(0xFFF45E3F);
const Color _inactiveColor = Color(0xFF757B8A);
const Color _bufferedColor = Color(0xFFB0B4BF);
const Color _thumbFillUnfocused = Color(0xFFEFF1F5);

/// Голубовато-белое неоновое свечение при фокусе (как у кнопок).
void _paintFocusGlow(Canvas canvas, Offset center, double radius) {
  final glowPaint = Paint()
    ..color = const Color(0xFFB3E5FC).withValues(alpha: 0.95)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
  canvas.drawCircle(center, radius + 4, glowPaint);
  final whiteGlowPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.6)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  canvas.drawCircle(center, radius + 2, whiteGlowPaint);
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

    if (isLTR) {
      if (bufferedX < right) {
        drawRRect(bufferedX, right, inactivePaint, leftR: Radius.zero);
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
      if (left < bufferedX) {
        drawRRect(left, bufferedX, inactivePaint, rightR: Radius.zero);
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

  const _ProgressThumbShape({
    required this.radius,
    required this.borderWidth,
    required this.borderColor,
    required this.fillColor,
    this.isFocused = false,
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
      _paintFocusGlow(canvas, center, radius);
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
class ProgressSlider extends StatelessWidget {
  final RhsPlayerController controller;
  final FocusNode focusNode;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;

  const ProgressSlider({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSeekBackward,
    required this.onSeekForward,
  });

  @override
  Widget build(BuildContext context) {
    final progressStream =
        Rx.combineLatest2<
          RhsPositionData,
          Duration,
          ({RhsPositionData position, Duration buffered})
        >(
          controller.positionDataStream,
          controller.bufferedPositionStream,
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
          focusNode: focusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                onSeekBackward();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                onSeekForward();
                return KeyEventResult.handled;
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
                        style: const TextStyle(color: Colors.white),
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
                          controller.seekTo(
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
