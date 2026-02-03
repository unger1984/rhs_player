import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/control_button.dart';

/// Ряд кнопок управления воспроизведением
class ControlsRow extends StatelessWidget {
  final RhsPlayerController controller;
  final VoidCallback onSwitchSource;
  final FocusNode rewindFocusNode;
  final FocusNode playFocusNode;
  final FocusNode forwardFocusNode;
  final FocusNode switchFocusNode;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;

  const ControlsRow({
    super.key,
    required this.controller,
    required this.onSwitchSource,
    required this.rewindFocusNode,
    required this.playFocusNode,
    required this.forwardFocusNode,
    required this.switchFocusNode,
    required this.onSeekBackward,
    required this.onSeekForward,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RhsPlayerStatus>(
      stream: controller.playerStatusStream,
      builder: (context, snapshot) {
        final status = snapshot.data ?? const RhsPlayerStatusPaused();
        final isPlaying = status is RhsPlayerStatusPlaying;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ControlButton(
              focusNode: rewindFocusNode,
              onPressed: onSeekBackward,
              child: const Icon(Icons.replay_10, color: Colors.white, size: 48),
            ),
            const SizedBox(width: 40),
            ControlButton(
              focusNode: playFocusNode,
              onPressed: () {
                if (isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
              },
              child: Icon(
                isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.white,
                size: 64,
              ),
            ),
            const SizedBox(width: 40),
            ControlButton(
              focusNode: forwardFocusNode,
              onPressed: onSeekForward,
              child: const Icon(
                Icons.forward_10,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(width: 40),
            ControlButton(
              focusNode: switchFocusNode,
              onPressed: onSwitchSource,
              child: const Text(
                'Переключить',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
