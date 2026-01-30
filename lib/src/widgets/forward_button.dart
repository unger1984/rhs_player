import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

class ForwardButton extends StatelessWidget {
  final RhsPlaybackState state;
  final RhsPlayerController controller;

  const ForwardButton({super.key, required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
      onPressed: () {
        final newPosition = state.position + const Duration(seconds: 10);
        final maxPosition = state.duration;
        controller.seekTo(newPosition > maxPosition ? maxPosition : newPosition);
      },
    );
  }
}
