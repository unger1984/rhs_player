import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player/rhs_player.dart';

class PlayerControls extends StatefulWidget {
  final RhsPlayerController controller;
  final RhsPlaybackState state;
  final String? error;
  final String Function(Duration) formatDuration;
  final bool isFullscreen;

  const PlayerControls({
    super.key,
    required this.controller,
    required this.state,
    this.error,
    required this.formatDuration,
    this.isFullscreen = false,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    // Не запускаем таймер сразу - контролы должны быть видны при инициализации
    // Таймер запустится после первого взаимодействия
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.error == null) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsTemporarily() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _startHideTimer();
  }

  void _hideControls() {
    if (_showControls && widget.error == null) {
      setState(() => _showControls = false);
    }
  }

  void _toggleFullscreen(BuildContext context) {
    if (widget.isFullscreen) {
      // Выход из fullscreen
      Navigator.of(context).pop();
    } else {
      // Вход в fullscreen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FullscreenPlayerPage(controller: widget.controller, formatDuration: widget.formatDuration),
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Всегда показываем оверлей при ошибке, иначе только если контролы видимы
    final shouldShow = _showControls || widget.error != null;

    return Stack(
      children: [
        // Основной оверлей с контролами
        if (shouldShow)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hideControls,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Индикатор буферизации
                  if (widget.state.isBuffering)
                    const Expanded(
                      child: Center(
                        child: BufferingIndicator(),
                      ),
                    ),

                  // Сообщение об ошибке
                  if (widget.error != null) ErrorDisplay(error: widget.error!, controller: widget.controller),

                  // Контролы воспроизведения
                  if (_showControls && widget.error == null && !widget.state.isBuffering)
                    Expanded(
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (_) => _startHideTimer(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ProgressBar(
                              state: widget.state,
                              controller: widget.controller,
                              formatDuration: widget.formatDuration,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  QualityButton(controller: widget.controller),
                                  const SizedBox(width: 8),
                                  AudioTrackButton(controller: widget.controller),
                                  const Spacer(),
                                  RewindButton(
                                    state: widget.state,
                                    controller: widget.controller,
                                  ),
                                  const SizedBox(width: 24),
                                  PlayPauseButton(controller: widget.controller),
                                  const SizedBox(width: 24),
                                  ForwardButton(
                                    state: widget.state,
                                    controller: widget.controller,
                                  ),
                                  const Spacer(),
                                  FullscreenButton(
                                    isFullscreen: widget.isFullscreen,
                                    onPressed: () => _toggleFullscreen(context),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        // GestureDetector для показа контролов при клике, когда они скрыты
        if (!shouldShow)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _showControlsTemporarily,
              child: Container(color: Colors.transparent),
            ),
          ),
      ],
    );
  }
}

/// Полноэкранная страница воспроизведения
class _FullscreenPlayerPage extends StatefulWidget {
  final RhsPlayerController controller;
  final String Function(Duration) formatDuration;

  const _FullscreenPlayerPage({required this.controller, required this.formatDuration});

  @override
  State<_FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<_FullscreenPlayerPage> {
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
            StreamBuilder<RhsNativeEvents?>(
              stream: widget.controller.eventsStream,
              builder: (context, eventsSnapshot) {
                if (!eventsSnapshot.hasData || eventsSnapshot.data == null) {
                  return const SizedBox.shrink();
                }

                final events = eventsSnapshot.data!;
                return StreamBuilder<RhsPlaybackState>(
                  stream: widget.controller.playbackStateStream,
                  builder: (context, stateSnapshot) {
                    return StreamBuilder<String?>(
                      stream: widget.controller.errorStream,
                      builder: (context, errorSnapshot) {
                        return PlayerControls(
                          controller: widget.controller,
                          state: stateSnapshot.data ?? events.state.value,
                          error: errorSnapshot.data ?? events.error.value,
                          formatDuration: widget.formatDuration,
                          isFullscreen: true,
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
