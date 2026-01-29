import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player/rhs_player.dart';
import 'widgets/player_controls_overlay.dart';

class PlayerScreen extends StatefulWidget {
  final bool isLive;
  final bool autoFullscreen;
  const PlayerScreen({super.key, this.isLive = false, this.autoFullscreen = true});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late RhsPlayerController controller;
  final List<VoidCallback> _listenerRemovers = [];
  Timer? _checkEventsTimer;
  RhsNativeEvents? _events;

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

    // Добавляем слушатели событий
    _listenerRemovers.add(
      controller.addProgressListener((position) {
        final minutes = position.inMinutes;
        final seconds = position.inSeconds.remainder(60);
        print('[Progress] Position: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}');
      }),
    );

    _listenerRemovers.add(
      controller.addBufferingListener((isBuffering) {
        print('[Buffering] Is buffering: $isBuffering');
      }),
    );

    _listenerRemovers.add(
      controller.addPlaybackStateListener((state) {
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

    _listenerRemovers.add(
      controller.addErrorListener((error) {
        if (error != null) {
          print('[Error] $error');
        } else {
          print('[Error] Error cleared');
        }
      }),
    );

    // Отслеживаем появление событий
    _checkEvents();
  }

  void _checkEvents() {
    // Проверяем события периодически, пока они не появятся
    _checkEventsTimer?.cancel();
    _checkEventsTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final events = controller.events;
      if (events != null && _events != events) {
        timer.cancel();
        _checkEventsTimer = null;
        if (mounted) {
          setState(() {
            _events = events;
          });
          print('[PlayerScreen] Events initialized!');
        }
      } else if (!mounted) {
        timer.cancel();
        _checkEventsTimer = null;
      }
    });
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
    _checkEventsTimer?.cancel();
    // Удаляем все слушатели
    for (final remover in _listenerRemovers) {
      remover();
    }
    _listenerRemovers.clear();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Используем сохраненное значение событий или текущее
    final events = _events ?? controller.events;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                RhsPlayerView(controller: controller, boxFit: BoxFit.contain),
                // Показываем индикатор загрузки, если события еще не инициализированы
                if (events == null)
                  Container(
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
                  ),
                if (events != null)
                  ValueListenableBuilder<RhsPlaybackState>(
                    valueListenable: events.state,
                    builder: (context, state, _) {
                      return ValueListenableBuilder<String?>(
                        valueListenable: events.error,
                        builder: (context, error, __) {
                          return PlayerControlsOverlay(
                            controller: controller,
                            state: state,
                            error: error,
                            formatDuration: _formatDuration,
                            onFullscreen: () => _enterFullscreen(context),
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
class _FullscreenPlayerPage extends StatefulWidget {
  final RhsPlayerController controller;

  const _FullscreenPlayerPage({required this.controller});

  @override
  State<_FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<_FullscreenPlayerPage> {
  Timer? _checkEventsTimer;
  RhsNativeEvents? _events;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _events = widget.controller.events;
    _checkEvents();
  }

  @override
  void dispose() {
    _checkEventsTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _checkEvents() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final events = widget.controller.events;
      if (events != null && _events != events) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _events = events;
          });
        }
      } else if (!mounted) {
        timer.cancel();
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final events = _events ?? widget.controller.events;

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
            if (events != null)
              ValueListenableBuilder<RhsPlaybackState>(
                valueListenable: events.state,
                builder: (context, state, _) {
                  return ValueListenableBuilder<String?>(
                    valueListenable: events.error,
                    builder: (context, error, __) {
                      return PlayerControlsOverlay(
                        controller: widget.controller,
                        state: state,
                        error: error,
                        formatDuration: _formatDuration,
                        onFullscreen: () => Navigator.of(context).pop(),
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
