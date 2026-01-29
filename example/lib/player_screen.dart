import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

class PlayerScreen extends StatefulWidget {
  final bool isLive;
  final bool autoFullscreen;
  const PlayerScreen({super.key, this.isLive = false, this.autoFullscreen = true});

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
      RhsMediaSource(
        "https://user67561.nowcdn.co/done/widevine_playready/06bff34bc0fed90c578b72d72905680ae9b29e29/index.mpd",
        isLive: widget.isLive,
        drm: const RhsDrmConfig(type: RhsDrmType.widevine, licenseUrl: 'https://drm93075.nowdrm.co/widevine'),
      ),
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
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: RhsModernPlayer(
            controller: controller,
            autoFullscreen: widget.autoFullscreen,
            autoHideAfter: const Duration(seconds: 10),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
