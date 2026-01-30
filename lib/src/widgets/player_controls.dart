import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player/rhs_player.dart';

String _defaultFormatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class PlayerControls extends StatefulWidget {
  final RhsPlayerController controller;
  final RhsPlaybackState state;
  final String Function(Duration)? formatDuration;
  final Duration? controlsHideAfter;
  final bool isFullscreen;

  const PlayerControls({
    super.key,
    required this.controller,
    required this.state,
    this.formatDuration,
    this.controlsHideAfter = const Duration(seconds: 5),
    this.isFullscreen = false,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _initialHideTimerStarted = false;
  bool _videoEnded = false;

  bool get _isVideoEnded => widget.state.duration > Duration.zero && widget.state.position >= widget.state.duration;

  @override
  void initState() {
    super.initState();
    if (widget.state.isPlaying && widget.controlsHideAfter != null) {
      _initialHideTimerStarted = true;
      _startHideTimer();
    }
  }

  @override
  void didUpdateWidget(covariant PlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isVideoEnded && !_videoEnded) {
      _videoEnded = true;
      _hideControlsTimer?.cancel();
      if (mounted) setState(() => _showControls = true);
      return;
    }
    if (_videoEnded && widget.state.isPlaying && widget.state.position < widget.state.duration) {
      _videoEnded = false;
    }
    if (!_initialHideTimerStarted &&
        !oldWidget.state.isPlaying &&
        widget.state.isPlaying &&
        widget.controlsHideAfter != null) {
      _initialHideTimerStarted = true;
      _startHideTimer();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    if (_videoEnded) return;
    final delay = widget.controlsHideAfter;
    if (delay == null) return;
    _hideControlsTimer = Timer(delay, () {
      if (mounted && widget.state.error == null) {
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
    if (_videoEnded) return;
    if (_showControls && widget.state.error == null) {
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
          builder: (_) => _FullscreenPlayerPage(
            controller: widget.controller,
            formatDuration: widget.formatDuration ?? _defaultFormatDuration,
            controlsHideAfter: widget.controlsHideAfter,
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Всегда показываем оверлей при ошибке, иначе только если контролы видимы
    final shouldShow = _showControls || widget.state.error != null;

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
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Сообщение об ошибке
                      if (widget.state.error != null)
                        ErrorDisplay(error: widget.state.error!, controller: widget.controller),

                      // Контролы воспроизведения (показываем и при буферизации, чтобы не пропадали при перемотке)
                      if (_showControls && widget.state.error == null)
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
                                  formatDuration: widget.formatDuration ?? _defaultFormatDuration,
                                  onInteraction: _startHideTimer,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          children: [
                                            QualityButton(
                                              controller: widget.controller,
                                              onInteraction: _startHideTimer,
                                            ),
                                            const SizedBox(width: 8),
                                            AudioTrackButton(
                                              controller: widget.controller,
                                              onInteraction: _startHideTimer,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          RewindButton(
                                            state: widget.state,
                                            controller: widget.controller,
                                            onInteraction: _startHideTimer,
                                          ),
                                          const SizedBox(width: 24),
                                          PlayPauseButton(
                                            controller: widget.controller,
                                            state: widget.state,
                                            onInteraction: _startHideTimer,
                                          ),
                                          const SizedBox(width: 24),
                                          ForwardButton(
                                            state: widget.state,
                                            controller: widget.controller,
                                            onInteraction: _startHideTimer,
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            FullscreenButton(
                                              isFullscreen: widget.isFullscreen,
                                              onPressed: () {
                                                _startHideTimer();
                                                _toggleFullscreen(context);
                                              },
                                            ),
                                          ],
                                        ),
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
                  // Индикатор буферизации по центру плеера
                  if (widget.state.isBuffering) const Positioned.fill(child: Center(child: BufferingIndicator())),
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
  final Duration? controlsHideAfter;

  const _FullscreenPlayerPage({
    required this.controller,
    required this.formatDuration,
    required this.controlsHideAfter,
  });

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
                    return PlayerControls(
                      controller: widget.controller,
                      state: stateSnapshot.data ?? events.state.value,
                      formatDuration: widget.formatDuration,
                      controlsHideAfter: widget.controlsHideAfter,
                      isFullscreen: true,
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
