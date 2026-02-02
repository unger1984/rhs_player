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
        "https://user67561.nowcdn.co/done/widevine_playready/864281dc477081737d51b28121d94230aad77ebc/index.mpd",
        drm: const RhsDrmConfig(type: RhsDrmType.widevine, licenseUrl: 'https://drm93075.nowdrm.co/widevine'),
      ),
      autoPlay: true,
      loop: false,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: RhsPlayerView(
              controller: controller,
              boxFit: BoxFit.contain,
              overlay: StreamBuilder<RhsNativeEvents?>(
                stream: controller.eventsStream,
                builder: (context, eventsSnapshot) {
                  if (!eventsSnapshot.hasData || eventsSnapshot.data == null) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }

                  return StreamBuilder<RhsPlaybackState>(
                    stream: controller.playbackStateStream,
                    initialData: controller.currentPlaybackState,
                    builder: (context, stateSnapshot) {
                      final state = stateSnapshot.data!;
                      // Пока медиа не загружено (duration == 0), показываем загрузку
                      if (state.duration == Duration.zero && state.error == null) {
                        return Container(
                          color: Colors.black,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [CircularProgressIndicator(color: Colors.white)],
                            ),
                          ),
                        );
                      }
                      return PlayerControls(controller: controller, state: state);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
