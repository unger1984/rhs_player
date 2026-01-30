import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';
import 'quality_button.dart';
import 'audio_track_button.dart';
import 'rewind_button.dart';
import 'play_pause_button.dart';
import 'forward_button.dart';
import 'fullscreen_button.dart';
import 'progress_bar.dart';
import 'buffering_indicator.dart';
import 'error_display.dart';

class PlayerControlsOverlay extends StatefulWidget {
  final RhsPlayerController controller;
  final RhsPlaybackState state;
  final String? error;
  final String Function(Duration) formatDuration;
  final VoidCallback? onFullscreen;

  const PlayerControlsOverlay({
    super.key,
    required this.controller,
    required this.state,
    this.error,
    required this.formatDuration,
    this.onFullscreen,
  });

  @override
  State<PlayerControlsOverlay> createState() => _PlayerControlsOverlayState();
}

class _PlayerControlsOverlayState extends State<PlayerControlsOverlay> {
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
                  if (widget.state.isBuffering) const BufferingIndicator(),

                  // Сообщение об ошибке
                  if (widget.error != null) ErrorDisplay(error: widget.error!, controller: widget.controller),

                  // Контролы воспроизведения
                  if (_showControls && widget.error == null)
                    Expanded(
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
                                QualityButton(controller: widget.controller, onControlsShow: _showControlsTemporarily),
                                const SizedBox(width: 8),
                                AudioTrackButton(
                                  controller: widget.controller,
                                  onControlsShow: _showControlsTemporarily,
                                ),
                                const Spacer(),
                                RewindButton(
                                  state: widget.state,
                                  controller: widget.controller,
                                  onControlsShow: _showControlsTemporarily,
                                ),
                                const SizedBox(width: 24),
                                PlayPauseButton(
                                  controller: widget.controller,
                                  onControlsShow: _showControlsTemporarily,
                                ),
                                const SizedBox(width: 24),
                                ForwardButton(
                                  state: widget.state,
                                  controller: widget.controller,
                                  onControlsShow: _showControlsTemporarily,
                                ),
                                const Spacer(),
                                if (widget.onFullscreen != null) FullscreenButton(onPressed: widget.onFullscreen!),
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
