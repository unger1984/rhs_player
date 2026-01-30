import 'package:flutter/material.dart';

import '../theme/player_style.dart';

class FullscreenButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isFullscreen;

  const FullscreenButton({super.key, this.onPressed, this.isFullscreen = false});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
        color: Colors.white,
        size: PlayerStyle.iconButtonSize,
      ),
      onPressed: onPressed,
    );
  }
}
