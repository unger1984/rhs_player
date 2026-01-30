import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

class RewindButton extends StatelessWidget {
  final RhsPlaybackState state;
  final RhsPlayerController controller;

  const RewindButton({super.key, required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
      onPressed: () {
        final newPosition = state.position - const Duration(seconds: 10);
        controller.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
      },
    );
  }
}
