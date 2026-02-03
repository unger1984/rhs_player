import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlayerScreenContent();
  }
}

class _PlayerScreenContent extends StatefulWidget {
  const _PlayerScreenContent();

  @override
  State<_PlayerScreenContent> createState() => _PlayerScreenContentState();
}

class _PlayerScreenContentState extends State<_PlayerScreenContent> {
  late RhsPlayerController controller;

  @override
  void initState() {
    super.initState();
    // ВАЖНО: DRM (Widevine) может не работать на эмуляторе!
    // Для тестирования на эмуляторе используйте видео без DRM, например:
    // RhsMediaSource("https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
    controller = RhsPlayerController.single(
      RhsMediaSource(
        "https://user67561.nowcdn.co/done/widevine_playready/7c6be93192a4888f3491f46fee3dbcb57c77bd08/index.mpd",
        drm: const RhsDrmConfig(
          type: RhsDrmType.widevine,
          licenseUrl: 'https://drm93075.nowdrm.co/widevine',
        ),
      ),
      autoPlay: true,
      loop: false,
    );

    controller.addStatusListener((status) {
      if (status is RhsPlayerStatusError) {
        print('EVENT PLAYER ERROR: ${status.message}');
      } else {
        print('EVENT PLAYER STATUS: $status');
      }
    });

    controller.addPositionDataListener((data) {
      print('EVENT POSITION DATA: ${data.position} / ${data.duration}');
    });

    controller.addBufferedPositionListener((position) {
      print('EVENT BUFFERED: $position');
    });

    controller.addVideoTracksListener((tracks) {
      final trackLabels = tracks.map((t) => t.displayLabel).join(', ');
      print('EVENT VIDEO TRACKS: [$trackLabels]');
    });

    controller.addAudioTracksListener((tracks) {
      final trackLabels = tracks.map((t) => t.label).join(', ');
      print('EVENT AUDIO TRACKS: [$trackLabels]');
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: RhsPlayerView(
            controller: controller,
            boxFit: BoxFit.contain,
            overlay: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                ElevatedButton(onPressed: () {}, child: Text('Переключить')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
