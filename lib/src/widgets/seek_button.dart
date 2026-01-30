import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

import '../theme/player_style.dart';

/// Кнопка перемотки вперёд или назад.
/// [seconds] — величина перемотки в секундах: отрицательная назад, положительная вперёд.
class SeekButton extends StatelessWidget {
  final int seconds;
  final RhsPlaybackState state;
  final RhsPlayerController controller;
  final VoidCallback? onInteraction;

  const SeekButton({
    super.key,
    required this.seconds,
    required this.state,
    required this.controller,
    this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final isForward = seconds > 0;
    return IconButton(
      icon: Icon(
        isForward ? Icons.forward_10 : Icons.replay_10,
        color: Colors.white,
        size: PlayerStyle.iconButtonSize,
      ),
      onPressed: () {
        onInteraction?.call();
        final newPosition = state.position + Duration(seconds: seconds);
        final clamped = newPosition < Duration.zero
            ? Duration.zero
            : (newPosition > state.duration ? state.duration : newPosition);
        controller.seekTo(clamped);
      },
    );
  }
}
