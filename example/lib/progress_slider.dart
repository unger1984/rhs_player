import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player/rhs_player.dart';

/// Слайдер прогресса воспроизведения с поддержкой перемотки клавишами
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
    return StreamBuilder<RhsPositionData>(
      stream: controller.positionDataStream,
      builder: (context, snapshot) {
        final positionData =
            snapshot.data ??
            const RhsPositionData(Duration.zero, Duration.zero);
        final position = positionData.position;
        final duration = positionData.duration;

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
              return Container(
                decoration: hasFocus
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.8),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      )
                    : null,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        _formatDuration(position),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    Expanded(
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
                        activeColor: Colors.blue,
                        inactiveColor: Colors.white.withAlpha(77),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Text(
                        _formatDuration(duration),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
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
