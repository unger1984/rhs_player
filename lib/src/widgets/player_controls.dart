import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player/rhs_player.dart';

import '../utils/player_utils.dart';
import 'fullscreen_player_page.dart';

/// Количество фокусируемых контролов: progressBar, quality, audio, rewind, playPause, forward, fullscreen.
const int _focusCount = 7;

class PlayerControls extends StatefulWidget {
  final RhsPlayerController controller;
  final RhsPlaybackState state;
  final String Function(Duration)? formatDuration;
  final Duration? controlsHideAfter;
  final bool isFullscreen;
  final int? initialFocusIndex; // 0-6: progressBar, quality, audio, rewind, playPause, forward, fullscreen

  const PlayerControls({
    super.key,
    required this.controller,
    required this.state,
    this.formatDuration,
    this.controlsHideAfter = const Duration(seconds: 5),
    this.isFullscreen = false,
    this.initialFocusIndex,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _initialHideTimerStarted = false;
  bool _videoEnded = false;

  final FocusNode _rootFocusNode = FocusNode();
  late final List<FocusNode> _focusNodes = List.generate(
    _focusCount,
    (_) => FocusNode(),
  );
  int? _lastFocusedIndex;

  Timer? _seekTimer;
  bool _isSeeking = false;
  int _seekCount = 0;

  bool get _isVideoEnded =>
      widget.state.duration > Duration.zero &&
      widget.state.position >= widget.state.duration;

  @override
  void initState() {
    super.initState();
    if (widget.state.isPlaying && widget.controlsHideAfter != null) {
      _initialHideTimerStarted = true;
      _startHideTimer();
    }
    for (final node in _focusNodes) {
      node.addListener(_onFocusChange);
    }
    if (widget.initialFocusIndex != null) {
      Future.microtask(() => _setFocusByIndex(widget.initialFocusIndex!));
    }
  }

  void _onFocusChange() {
    for (var i = 0; i < _focusNodes.length; i++) {
      if (_focusNodes[i].hasFocus) {
        _lastFocusedIndex = i;
        return;
      }
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
    _seekTimer?.cancel();
    for (final node in _focusNodes) {
      node.removeListener(_onFocusChange);
      node.dispose();
    }
    _rootFocusNode.dispose();
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

  void _showControlsTemporarily({LogicalKeyboardKey? triggeredByKey}) {
    if (!_showControls) {
      setState(() => _showControls = true);
      if (triggeredByKey != null) {
        Future.microtask(() {
          final idx = _lastFocusedIndex;
          if (idx != null &&
              idx >= 0 &&
              idx < _focusNodes.length &&
              _focusNodes[idx].canRequestFocus) {
            _focusNodes[idx].requestFocus();
          } else {
            _setInitialFocus(triggeredByKey);
          }
        });
      }
    }
    _startHideTimer();
  }

  bool _hasAnyFocus() => _focusNodes.any((n) => n.hasFocus);

  void _setInitialFocus(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) {
      _focusNodes[4].requestFocus();
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      _focusNodes[1].requestFocus();
    } else if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _focusNodes[4].requestFocus();
    }
  }

  void _clearVisualFocus() {
    for (final n in _focusNodes) {
      n.unfocus();
    }
  }

  int? _getCurrentFocusIndex() {
    for (var i = 0; i < _focusNodes.length; i++) {
      if (_focusNodes[i].hasFocus || _lastFocusedIndex == i) {
        return i;
      }
    }
    return _lastFocusedIndex;
  }

  void _setFocusByIndex(int index) {
    if (index >= 0 && index < _focusNodes.length) {
      _focusNodes[index].requestFocus();
      _lastFocusedIndex = index;
    }
  }

  void _hideControls() {
    if (_videoEnded) return;
    if (_showControls && widget.state.error == null) {
      setState(() => _showControls = false);
    }
  }
  
  /// [direction] 1 — вперёд, -1 — назад.
  void _seek(int direction, {bool continuous = false}) {
    if (!continuous) {
      final delta = Duration(seconds: 10 * direction);
      final newPosition = widget.state.position + delta;
      final clamped = newPosition < Duration.zero
          ? Duration.zero
          : (newPosition > widget.state.duration
              ? widget.state.duration
              : newPosition);
      widget.controller.seekTo(clamped);
    } else {
      if (!_isSeeking) {
        _isSeeking = true;
        _seekCount = 0;
      }
      _seekCount++;
      final amount = _seekCount <= 3
          ? 1
          : (_seekCount <= 6 ? 2 : (_seekCount <= 10 ? 3 : (_seekCount <= 15 ? 5 : 10)));
      final delta = Duration(seconds: amount * direction);
      final newPosition = widget.state.position + delta;
      final clamped = newPosition < Duration.zero
          ? Duration.zero
          : (newPosition > widget.state.duration
              ? widget.state.duration
              : newPosition);
      widget.controller.seekTo(clamped);
      _seekTimer?.cancel();
      _seekTimer = Timer(const Duration(milliseconds: 200), () {
        if (_isSeeking) {
          _seek(direction, continuous: true);
        }
      });
    }
  }

  void _stopSeeking() {
    _isSeeking = false;
    _seekCount = 0;
    _seekTimer?.cancel();
  }
  
  void _togglePlayPause() {
    if (widget.state.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    _startHideTimer();
  }

  void _toggleFullscreen(BuildContext context) {
    if (widget.isFullscreen) {
      Navigator.of(context).pop(_getCurrentFocusIndex());
    } else {
      final focusIndex = _getCurrentFocusIndex();
      Navigator.of(context).push<int?>(
        MaterialPageRoute(
          builder: (_) => FullscreenPlayerPage(
            controller: widget.controller,
            formatDuration: widget.formatDuration ?? defaultFormatDuration,
            controlsHideAfter: widget.controlsHideAfter,
            initialFocusIndex: focusIndex,
          ),
          fullscreenDialog: true,
        ),
      ).then((returnedFocusIndex) {
        if (returnedFocusIndex != null) {
          Future.microtask(() => _setFocusByIndex(returnedFocusIndex));
        }
      });
    }
  }
  

  KeyEventResult _handleKeyWhenControlsHidden(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seek(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seek(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _showControlsTemporarily(triggeredByKey: event.logicalKey);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleKeyOnProgressBar(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _seek(-1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seek(1);
        return KeyEventResult.handled;
      }
    } else if (event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _seek(-1, continuous: true);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seek(1, continuous: true);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleKeyNavigation(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_focusNodes[1].hasFocus || _focusNodes[2].hasFocus ||
          _focusNodes[3].hasFocus || _focusNodes[4].hasFocus ||
          _focusNodes[5].hasFocus || _focusNodes[6].hasFocus) {
        _focusNodes[0].requestFocus();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_focusNodes[0].hasFocus) {
        _focusNodes[4].requestFocus();
        return KeyEventResult.handled;
      }
      if (_focusNodes[1].hasFocus || _focusNodes[2].hasFocus ||
          _focusNodes[3].hasFocus || _focusNodes[4].hasFocus ||
          _focusNodes[5].hasFocus || _focusNodes[6].hasFocus) {
        _hideControls();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleKeyRowNavigation(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      for (var i = 1; i < _focusNodes.length; i++) {
        if (_focusNodes[i].hasFocus) {
          _focusNodes[i - 1].requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      for (var i = 0; i < _focusNodes.length - 1; i++) {
        if (_focusNodes[i].hasFocus) {
          _focusNodes[i + 1].requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final shouldShow = _showControls || widget.state.error != null;

    return Focus(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if ((event is KeyDownEvent || event is KeyRepeatEvent) && _showControls) {
          _startHideTimer();
        }
        if (!_showControls && widget.state.error == null) {
          return _handleKeyWhenControlsHidden(event);
        }
        if (_showControls) {
          if (event is KeyDownEvent && !_hasAnyFocus()) {
            _setInitialFocus(event.logicalKey);
            return KeyEventResult.handled;
          }
          if (_focusNodes[0].hasFocus) {
            final r = _handleKeyOnProgressBar(event);
            if (r == KeyEventResult.handled) return r;
          }
          final nav = _handleKeyNavigation(event);
          if (nav == KeyEventResult.handled) return nav;
          final row = _handleKeyRowNavigation(event);
          if (row == KeyEventResult.handled) return row;
        }
        if (event is KeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _stopSeeking();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
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
                            onPointerDown: (_) {
                              _startHideTimer();
                              _clearVisualFocus(); // Сбрасываем визуальный фокус при клике мыши
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Прогресс-бар с фокусом
                                FocusableControlButton(
                                  focusNode: _focusNodes[0],
                                  autofocus: false,
                                  onPressed: () {},
                                  onLongPressStart: () {
                                    // Длительное нажатие на прогресс-баре можно использовать для навигации
                                  },
                                  child: ProgressBar(
                                    state: widget.state,
                                    controller: widget.controller,
                                    formatDuration: widget.formatDuration ?? defaultFormatDuration,
                                    onInteraction: _startHideTimer,
                                  ),
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
                                              focusNode: _focusNodes[1],
                                            ),
                                            const SizedBox(width: 8),
                                            AudioTrackButton(
                                              controller: widget.controller,
                                              onInteraction: _startHideTimer,
                                              focusNode: _focusNodes[2],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          FocusableControlButton(
                                            focusNode: _focusNodes[3],
                                            onPressed: () {
                                              _seek(-1);
                                              _startHideTimer();
                                            },
                                            child: RewindButton(
                                              state: widget.state,
                                              controller: widget.controller,
                                              onInteraction: _startHideTimer,
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          FocusableControlButton(
                                            focusNode: _focusNodes[4],
                                            onPressed: _togglePlayPause,
                                            child: PlayPauseButton(
                                              controller: widget.controller,
                                              state: widget.state,
                                              onInteraction: _startHideTimer,
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          FocusableControlButton(
                                            focusNode: _focusNodes[5],
                                            onPressed: () {
                                              _seek(1);
                                              _startHideTimer();
                                            },
                                            child: ForwardButton(
                                              state: widget.state,
                                              controller: widget.controller,
                                              onInteraction: _startHideTimer,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            FocusableControlButton(
                                              focusNode: _focusNodes[6],
                                              onPressed: () {
                                                _startHideTimer();
                                                _toggleFullscreen(context);
                                              },
                                              child: FullscreenButton(
                                                isFullscreen: widget.isFullscreen,
                                                onPressed: null,
                                              ),
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
                onTap: () {
                  // Показываем контролы без установки фокуса (клик мыши)
                  _showControlsTemporarily();
                },
                child: Container(color: Colors.transparent),
              ),
            ),
        ],
      ),
    );
  }
}
