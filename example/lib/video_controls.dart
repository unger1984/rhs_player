import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/controls/builder/video_controls_builder.dart';
import 'package:rhs_player_example/controls/items/button_item.dart';
import 'package:rhs_player_example/controls/items/progress_slider_item.dart';
import 'package:rhs_player_example/controls/rows/full_width_row.dart';
import 'package:rhs_player_example/controls/rows/horizontal_button_row.dart';

/// Виджет управления видео с поддержкой Android TV пульта
/// Использует новую систему навигации с Chain of Responsibility паттерном
class VideoControls extends StatelessWidget {
  final RhsPlayerController controller;
  final VoidCallback onSwitchSource;

  const VideoControls({
    super.key,
    required this.controller,
    required this.onSwitchSource,
  });

  @override
  Widget build(BuildContext context) {
    return VideoControlsBuilder(
      rows: [
        // Ряд 0: Слайдер прогресса
        FullWidthRow(
          id: 'progress_row',
          index: 0,
          items: [
            ProgressSliderItem(
              id: 'progress_slider',
              controller: controller,
              onSeekBackward: _seekBackward,
              onSeekForward: _seekForward,
            ),
          ],
        ),

        // Ряд 1: Кнопки управления
        HorizontalButtonRow(
          id: 'control_buttons_row',
          index: 1,
          items: [
            ButtonItem(
              id: 'rewind_button',
              onPressed: _seekBackward,
              child: const Icon(Icons.replay_10, color: Colors.white, size: 32),
            ),
            ButtonItem(
              id: 'play_pause_button',
              onPressed: _togglePlayPause,
              child: StreamBuilder<RhsPlayerStatus>(
                stream: controller.playerStatusStream,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data is RhsPlayerStatusPlaying;
                  return Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  );
                },
              ),
            ),
            ButtonItem(
              id: 'forward_button',
              onPressed: _seekForward,
              child: const Icon(
                Icons.forward_10,
                color: Colors.white,
                size: 32,
              ),
            ),
            ButtonItem(
              id: 'switch_source_button',
              onPressed: onSwitchSource,
              child: const Icon(
                Icons.swap_horiz,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _seekBackward() {
    final newPosition =
        controller.currentPosition - const Duration(seconds: 10);
    controller.seekTo(
      newPosition > Duration.zero ? newPosition : Duration.zero,
    );
  }

  void _seekForward() {
    final newPosition =
        controller.currentPosition + const Duration(seconds: 10);
    final duration = controller.currentPositionData.duration;
    controller.seekTo(newPosition < duration ? newPosition : duration);
  }

  void _togglePlayPause() {
    if (controller.currentPlayerStatus is RhsPlayerStatusPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }
}
