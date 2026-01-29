import 'package:flutter/material.dart';

class FullscreenButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isFullscreen;

  const FullscreenButton({super.key, required this.onPressed, this.isFullscreen = false});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 32),
      onPressed: onPressed,
    );
  }
}
