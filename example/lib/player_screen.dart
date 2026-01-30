import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';
import 'widgets/player_controls.dart';

class PlayerScreen extends StatelessWidget {
  final bool isLive;
  const PlayerScreen({super.key, this.isLive = false});

  @override
  Widget build(BuildContext context) {
    return _PlayerScreenContent(isLive: isLive);
  }
}

class _PlayerScreenContent extends StatefulWidget {
  final bool isLive;
  const _PlayerScreenContent({required this.isLive});

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
        "https://user67561.nowcdn.co/done/widevine_playready/06bff34bc0fed90c578b72d72905680ae9b29e29/index.mpd",
        isLive: widget.isLive,
        drm: const RhsDrmConfig(type: RhsDrmType.widevine, licenseUrl: 'https://drm93075.nowdrm.co/widevine'),
      ),
      autoPlay: true,
      loop: false,
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
            child: Stack(
              children: [
                RhsPlayerView(controller: controller, boxFit: BoxFit.contain),
                // Используем StreamBuilder для отслеживания событий
                StreamBuilder<RhsNativeEvents?>(
                  stream: controller.eventsStream,
                  builder: (context, eventsSnapshot) {
                    // Показываем индикатор загрузки, если события еще не инициализированы
                    if (!eventsSnapshot.hasData || eventsSnapshot.data == null) {
                      return Container(
                        color: Colors.black,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text('Initializing player...', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      );
                    }

                    final events = eventsSnapshot.data!;
                    // Используем StreamBuilder для состояния воспроизведения и ошибок
                    return StreamBuilder<RhsPlaybackState>(
                      stream: controller.playbackStateStream,
                      builder: (context, stateSnapshot) {
                        return StreamBuilder<String?>(
                          stream: controller.errorStream,
                          builder: (context, errorSnapshot) {
                            return PlayerControls(
                              controller: controller,
                              state: stateSnapshot.data ?? events.state.value,
                              error: errorSnapshot.data ?? events.error.value,
                              formatDuration: _formatDuration,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
