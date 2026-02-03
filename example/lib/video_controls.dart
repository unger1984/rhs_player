import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/play_pause_control_button.dart';
import 'package:rhs_player_example/controls/builder/video_controls_builder.dart';
import 'package:rhs_player_example/controls/core/key_handling_result.dart';
import 'package:rhs_player_example/controls/items/button_item.dart';
import 'package:rhs_player_example/controls/items/custom_widget_item.dart';
import 'package:rhs_player_example/controls/items/progress_slider_item.dart';
import 'package:rhs_player_example/controls/rows/full_width_row.dart';
import 'package:rhs_player_example/controls/rows/three_zone_button_row.dart';
import 'package:rhs_player_example/controls/rows/top_bar_row.dart';

/// Виджет управления видео с поддержкой Android TV пульта
/// Использует новую систему навигации с Chain of Responsibility паттерном
class VideoControls extends StatelessWidget {
  final RhsPlayerController controller;
  final VoidCallback onSwitchSource;
  final VoidCallback? onFavoritePressed;

  const VideoControls({
    super.key,
    required this.controller,
    required this.onSwitchSource,
    this.onFavoritePressed,
  });

  @override
  Widget build(BuildContext context) {
    return VideoControlsBuilder(
      initialFocusId: 'play_pause_button',
      rows: [
        TopBarRow(
          id: 'top_bar_row',
          index: 0,
          height: 124,
          backgroundColor: const Color(0xCC201B2E),
          leftPadding: 120,
          title: 'Тут будет название фильма',
          items: [
            ButtonItem(
              id: 'back_button',
              onPressed: () => Navigator.of(context).pop(),
              buttonSize: 76,
              buttonBorderRadius: 16,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(left: 5.w),
                  child: Icon(Icons.arrow_back_ios, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        FullWidthRow(
          id: 'progress_row',
          index: 1,
          items: [
            ProgressSliderItem(
              id: 'progress_slider',
              controller: controller,
              onSeekBackward: _seekBackward,
              onSeekForward: _seekForward,
            ),
          ],
        ),
        ThreeZoneButtonRow(
          id: 'control_buttons_row',
          index: 2,
          spacing: 32.w,
          leftItems: [
            ButtonItem(
              id: 'favorite_button',
              onPressed: onFavoritePressed ?? () {},
              child: Center(
                child: SizedBox(
                  width: 56.w,
                  height: 56.h,
                  child: ImageIcon(AssetImage('assets/controls/like.png')),
                ),
              ),
            ),
          ],
          centerItems: [
            ButtonItem(
              id: 'rewind_button',
              onPressed: _seekBackward,
              repeatWhileHeld: true,
              child: Center(
                child: SizedBox(
                  width: 56.w,
                  height: 56.h,
                  child: ImageIcon(AssetImage('assets/controls/rewind_L.png')),
                ),
              ),
            ),
            CustomWidgetItem(
              id: 'play_pause_button',
              keyHandler: (event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter)) {
                  _togglePlayPause();
                  return KeyHandlingResult.handled;
                }
                return KeyHandlingResult.notHandled;
              },
              builder: (focusNode) => StreamBuilder<RhsPlayerStatus>(
                stream: controller.playerStatusStream,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data is RhsPlayerStatusPlaying;
                  return PlayPauseControlButton(
                    focusNode: focusNode,
                    isPlaying: isPlaying,
                    onPressed: _togglePlayPause,
                  );
                },
              ),
            ),
            ButtonItem(
              id: 'forward_button',
              onPressed: _seekForward,
              repeatWhileHeld: true,
              child: Center(
                child: SizedBox(
                  width: 56.w,
                  height: 56.h,
                  child: ImageIcon(AssetImage('assets/controls/rewind_R.png')),
                ),
              ),
            ),
          ],
          rightItems: [
            ButtonItem(
              id: 'switch_source_button',
              onPressed: () {
                VideoControlsNavigation.maybeOf(
                  context,
                )?.scheduleFocusRestore('switch_source_button');
                onSwitchSource();
              },
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
