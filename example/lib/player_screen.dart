import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  final bool isLive;
  final bool autoFullscreen;
  const PlayerScreen({super.key, required this.url, this.isLive = false, this.autoFullscreen = false});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late RhsNativePlayerController controller;
  final ValueNotifier<BoxFit> boxFitNotifier = ValueNotifier(BoxFit.contain);

  @override
  void initState() {
    super.initState();
    controller = RhsNativePlayerController.single(
      RhsMediaSource(widget.url, isLive: widget.isLive),
      autoPlay: true,
      loop: false,
    );
  }

  @override
  void dispose() {
    boxFitNotifier.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Player Screen')),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: RhsModernPlayer(
            controller: controller,
            autoFullscreen: widget.autoFullscreen,
            overlay: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_circle_fill, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'RHS Player',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                if (widget.isLive) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
