import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

import 'seek_button.dart';

/// Кнопка перемотки на 10 секунд назад.
class RewindButton extends StatelessWidget {
  final RhsPlaybackState state;
  final RhsPlayerController controller;
  final VoidCallback? onInteraction;

  const RewindButton({
    super.key,
    required this.state,
    required this.controller,
    this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return SeekButton(
      seconds: -10,
      state: state,
      controller: controller,
      onInteraction: onInteraction,
    );
  }
}
