import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player/rhs_player.dart';
import 'widgets/player_controls_overlay.dart';

class PlayerScreen extends StatelessWidget {
  final bool isLive;
  final bool autoFullscreen;
  const PlayerScreen({super.key, this.isLive = false, this.autoFullscreen = true});

  @override
  Widget build(BuildContext context) {
    return _PlayerScreenContent(isLive: isLive, autoFullscreen: autoFullscreen);
  }
}

class _PlayerScreenContent extends StatefulWidget {
  final bool isLive;
  final bool autoFullscreen;
  const _PlayerScreenContent({required this.isLive, required this.autoFullscreen});

  @override
  State<_PlayerScreenContent> createState() => _PlayerScreenContentState();
}

class _PlayerScreenContentState extends State<_PlayerScreenContent> {
  late RhsPlayerController controller;
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    print('[PlayerScreen] Initializing controller...');
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
    print('[PlayerScreen] Controller created, events: ${controller.events}');

    // Подписываемся на события через Streams
    _subscriptions.add(
      controller.progressStream.listen((position) {
        final minutes = position.inMinutes;
        final seconds = position.inSeconds.remainder(60);
        print('[Progress] Position: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}');
      }),
    );

    _subscriptions.add(
      controller.bufferingStream.listen((isBuffering) {
        print('[Buffering] Is buffering: $isBuffering');
      }),
    );

    _subscriptions.add(
      controller.playbackStateStream.listen((state) {
        final minutes = state.position.inMinutes;
        final seconds = state.position.inSeconds.remainder(60);
        final durationMinutes = state.duration.inMinutes;
        final durationSeconds = state.duration.inSeconds.remainder(60);
        print(
          '[Playback State] Playing: ${state.isPlaying}, '
          'Buffering: ${state.isBuffering}, '
          'Position: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}, '
          'Duration: ${durationMinutes.toString().padLeft(2, '0')}:${durationSeconds.toString().padLeft(2, '0')}',
        );
      }),
    );

    _subscriptions.add(
      controller.errorStream.listen((error) {
        if (error != null) {
          print('[Error] $error');
        } else {
          print('[Error] Error cleared');
        }
      }),
    );
  }

  void _enterFullscreen(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _FullscreenPlayerPage(controller: controller), fullscreenDialog: true));
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
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
                            return PlayerControlsOverlay(
                              controller: controller,
                              state: stateSnapshot.data ?? events.state.value,
                              error: errorSnapshot.data ?? events.error.value,
                              formatDuration: _formatDuration,
                              onFullscreen: () => _enterFullscreen(context),
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

/// Полноэкранная страница для воспроизведения видео
class _FullscreenPlayerPage extends StatelessWidget {
  final RhsPlayerController controller;

  const _FullscreenPlayerPage({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _FullscreenPlayerPageContent(controller: controller);
  }
}

class _FullscreenPlayerPageContent extends StatefulWidget {
  final RhsPlayerController controller;

  const _FullscreenPlayerPageContent({required this.controller});

  @override
  State<_FullscreenPlayerPageContent> createState() => _FullscreenPlayerPageContentState();
}

class _FullscreenPlayerPageContentState extends State<_FullscreenPlayerPageContent> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: Stack(
          children: [
            RhsPlayerView(controller: widget.controller, boxFit: BoxFit.contain),
            // Используем StreamBuilder для отслеживания событий
            StreamBuilder<RhsNativeEvents?>(
              stream: widget.controller.eventsStream,
              builder: (context, eventsSnapshot) {
                if (!eventsSnapshot.hasData || eventsSnapshot.data == null) {
                  return const SizedBox.shrink();
                }

                final events = eventsSnapshot.data!;
                // Используем StreamBuilder для состояния воспроизведения и ошибок
                return StreamBuilder<RhsPlaybackState>(
                  stream: widget.controller.playbackStateStream,
                  builder: (context, stateSnapshot) {
                    return StreamBuilder<String?>(
                      stream: widget.controller.errorStream,
                      builder: (context, errorSnapshot) {
                        return PlayerControlsOverlay(
                          controller: widget.controller,
                          state: stateSnapshot.data ?? events.state.value,
                          error: errorSnapshot.data ?? events.error.value,
                          formatDuration: _formatDuration,
                          onFullscreen: () => Navigator.of(context).pop(),
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
    );
  }
}
