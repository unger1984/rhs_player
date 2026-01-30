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
  
  // FocusNodes для навигации
  final FocusNode _rootFocusNode = FocusNode();
  final FocusNode _progressBarFocusNode = FocusNode();
  final FocusNode _qualityFocusNode = FocusNode();
  final FocusNode _audioFocusNode = FocusNode();
  final FocusNode _rewindFocusNode = FocusNode();
  final FocusNode _playPauseFocusNode = FocusNode();
  final FocusNode _forwardFocusNode = FocusNode();
  final FocusNode _fullscreenFocusNode = FocusNode();
  
  // GlobalKeys для доступа к виджетам QualityButton и AudioTrackButton
  final GlobalKey _qualityButtonKey = GlobalKey();
  final GlobalKey _audioButtonKey = GlobalKey();
  
  Timer? _seekTimer;
  bool _isSeeking = false;
  int _seekCount = 0; // Счетчик для ускорения перемотки
  FocusNode? _lastFocusedNode; // Сохраняем последний сфокусированный узел

  bool get _isVideoEnded => widget.state.duration > Duration.zero && widget.state.position >= widget.state.duration;

  @override
  void initState() {
    super.initState();
    if (widget.state.isPlaying && widget.controlsHideAfter != null) {
      _initialHideTimerStarted = true;
      _startHideTimer();
    }
    
    // Добавляем слушатели фокуса для сохранения последнего фокуса
    _progressBarFocusNode.addListener(_onFocusChange);
    _qualityFocusNode.addListener(_onFocusChange);
    _audioFocusNode.addListener(_onFocusChange);
    _rewindFocusNode.addListener(_onFocusChange);
    _playPauseFocusNode.addListener(_onFocusChange);
    _forwardFocusNode.addListener(_onFocusChange);
    _fullscreenFocusNode.addListener(_onFocusChange);
    
    // Восстанавливаем фокус из переданного индекса
    if (widget.initialFocusIndex != null) {
      Future.microtask(() => _setFocusByIndex(widget.initialFocusIndex!));
    }
  }
  
  void _onFocusChange() {
    // Сохраняем узел, который получил фокус
    if (_progressBarFocusNode.hasFocus) {
      _lastFocusedNode = _progressBarFocusNode;
    } else if (_qualityFocusNode.hasFocus) {
      _lastFocusedNode = _qualityFocusNode;
    } else if (_audioFocusNode.hasFocus) {
      _lastFocusedNode = _audioFocusNode;
    } else if (_rewindFocusNode.hasFocus) {
      _lastFocusedNode = _rewindFocusNode;
    } else if (_playPauseFocusNode.hasFocus) {
      _lastFocusedNode = _playPauseFocusNode;
    } else if (_forwardFocusNode.hasFocus) {
      _lastFocusedNode = _forwardFocusNode;
    } else if (_fullscreenFocusNode.hasFocus) {
      _lastFocusedNode = _fullscreenFocusNode;
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
    
    // Удаляем слушатели перед dispose
    _progressBarFocusNode.removeListener(_onFocusChange);
    _qualityFocusNode.removeListener(_onFocusChange);
    _audioFocusNode.removeListener(_onFocusChange);
    _rewindFocusNode.removeListener(_onFocusChange);
    _playPauseFocusNode.removeListener(_onFocusChange);
    _forwardFocusNode.removeListener(_onFocusChange);
    _fullscreenFocusNode.removeListener(_onFocusChange);
    
    _rootFocusNode.dispose();
    _progressBarFocusNode.dispose();
    _qualityFocusNode.dispose();
    _audioFocusNode.dispose();
    _rewindFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _forwardFocusNode.dispose();
    _fullscreenFocusNode.dispose();
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
      // Если контролы показаны с пульта
      if (triggeredByKey != null) {
        Future.microtask(() {
          // Восстанавливаем последний фокус или устанавливаем новый
          if (_lastFocusedNode != null && _lastFocusedNode!.canRequestFocus) {
            _lastFocusedNode!.requestFocus();
          } else {
            _setInitialFocus(triggeredByKey);
          }
        });
      }
    }
    _startHideTimer();
  }
  
  // Проверяем, есть ли фокус на каком-либо контроле
  bool _hasAnyFocus() {
    return _progressBarFocusNode.hasFocus ||
        _qualityFocusNode.hasFocus ||
        _audioFocusNode.hasFocus ||
        _rewindFocusNode.hasFocus ||
        _playPauseFocusNode.hasFocus ||
        _forwardFocusNode.hasFocus ||
        _fullscreenFocusNode.hasFocus;
  }
  
  // Устанавливаем фокус в зависимости от нажатой клавиши
  void _setInitialFocus(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) {
      // При нажатии вверх выбираем кнопки в нижнем ряду (Play/Pause)
      _playPauseFocusNode.requestFocus();
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      _qualityFocusNode.requestFocus();
    } else if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _playPauseFocusNode.requestFocus();
    }
  }
  
  // Сбрасываем визуальный фокус (при клике мыши), но сохраняем _lastFocusedNode
  void _clearVisualFocus() {
    _progressBarFocusNode.unfocus();
    _qualityFocusNode.unfocus();
    _audioFocusNode.unfocus();
    _rewindFocusNode.unfocus();
    _playPauseFocusNode.unfocus();
    _forwardFocusNode.unfocus();
    _fullscreenFocusNode.unfocus();
    // _lastFocusedNode НЕ сбрасываем - он восстановится при следующем нажатии на пульт
  }
  
  // Получаем индекс текущего фокуса (для передачи в fullscreen)
  int? _getCurrentFocusIndex() {
    if (_progressBarFocusNode.hasFocus || _lastFocusedNode == _progressBarFocusNode) return 0;
    if (_qualityFocusNode.hasFocus || _lastFocusedNode == _qualityFocusNode) return 1;
    if (_audioFocusNode.hasFocus || _lastFocusedNode == _audioFocusNode) return 2;
    if (_rewindFocusNode.hasFocus || _lastFocusedNode == _rewindFocusNode) return 3;
    if (_playPauseFocusNode.hasFocus || _lastFocusedNode == _playPauseFocusNode) return 4;
    if (_forwardFocusNode.hasFocus || _lastFocusedNode == _forwardFocusNode) return 5;
    if (_fullscreenFocusNode.hasFocus || _lastFocusedNode == _fullscreenFocusNode) return 6;
    return null;
  }
  
  // Устанавливаем фокус по индексу
  void _setFocusByIndex(int index) {
    switch (index) {
      case 0:
        _progressBarFocusNode.requestFocus();
        _lastFocusedNode = _progressBarFocusNode;
        break;
      case 1:
        _qualityFocusNode.requestFocus();
        _lastFocusedNode = _qualityFocusNode;
        break;
      case 2:
        _audioFocusNode.requestFocus();
        _lastFocusedNode = _audioFocusNode;
        break;
      case 3:
        _rewindFocusNode.requestFocus();
        _lastFocusedNode = _rewindFocusNode;
        break;
      case 4:
        _playPauseFocusNode.requestFocus();
        _lastFocusedNode = _playPauseFocusNode;
        break;
      case 5:
        _forwardFocusNode.requestFocus();
        _lastFocusedNode = _forwardFocusNode;
        break;
      case 6:
        _fullscreenFocusNode.requestFocus();
        _lastFocusedNode = _fullscreenFocusNode;
        break;
    }
  }

  void _hideControls() {
    if (_videoEnded) return;
    if (_showControls && widget.state.error == null) {
      setState(() => _showControls = false);
    }
  }
  
  void _seekForward({bool continuous = false}) {
    if (!continuous) {
      // Обычная перемотка на 10 секунд
      final newPosition = widget.state.position + const Duration(seconds: 10);
      final maxPosition = widget.state.duration;
      widget.controller.seekTo(
        newPosition > maxPosition ? maxPosition : newPosition,
      );
    } else {
      // Непрерывная перемотка с ускорением
      if (!_isSeeking) {
        _isSeeking = true;
        _seekCount = 0;
      }
      
      _seekCount++;
      
      // Ускорение: начинаем с 1 секунды, затем 2, 3, 5, 10 секунд
      final seekAmount = _seekCount <= 3 ? 1 : (_seekCount <= 6 ? 2 : (_seekCount <= 10 ? 3 : (_seekCount <= 15 ? 5 : 10)));
      final newPosition = widget.state.position + Duration(seconds: seekAmount);
      final maxPosition = widget.state.duration;
      widget.controller.seekTo(
        newPosition > maxPosition ? maxPosition : newPosition,
      );
      
      // Интервал между перемотками
      _seekTimer?.cancel();
      _seekTimer = Timer(const Duration(milliseconds: 200), () {
        if (_isSeeking) {
          _seekForward(continuous: true);
        }
      });
    }
  }

  void _seekBackward({bool continuous = false}) {
    if (!continuous) {
      // Обычная перемотка на 10 секунд
      final newPosition = widget.state.position - const Duration(seconds: 10);
      widget.controller.seekTo(
        newPosition < Duration.zero ? Duration.zero : newPosition,
      );
    } else {
      // Непрерывная перемотка с ускорением
      if (!_isSeeking) {
        _isSeeking = true;
        _seekCount = 0;
      }
      
      _seekCount++;
      
      // Ускорение: начинаем с 1 секунды, затем 2, 3, 5, 10 секунд
      final seekAmount = _seekCount <= 3 ? 1 : (_seekCount <= 6 ? 2 : (_seekCount <= 10 ? 3 : (_seekCount <= 15 ? 5 : 10)));
      final newPosition = widget.state.position - Duration(seconds: seekAmount);
      widget.controller.seekTo(
        newPosition < Duration.zero ? Duration.zero : newPosition,
      );
      
      // Интервал между перемотками
      _seekTimer?.cancel();
      _seekTimer = Timer(const Duration(milliseconds: 200), () {
        if (_isSeeking) {
          _seekBackward(continuous: true);
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
      // Выход из fullscreen
      Navigator.of(context).pop(_getCurrentFocusIndex());
    } else {
      // Вход в fullscreen - передаем текущий индекс фокуса
      final focusIndex = _getCurrentFocusIndex();
      Navigator.of(context).push<int?>(
        MaterialPageRoute(
          builder: (_) => _FullscreenPlayerPage(
            controller: widget.controller,
            formatDuration: widget.formatDuration ?? _defaultFormatDuration,
            controlsHideAfter: widget.controlsHideAfter,
            initialFocusIndex: focusIndex,
          ),
          fullscreenDialog: true,
        ),
      ).then((returnedFocusIndex) {
        // Восстанавливаем фокус при возврате из fullscreen
        if (returnedFocusIndex != null) {
          Future.microtask(() => _setFocusByIndex(returnedFocusIndex));
        }
      });
    }
  }
  

  @override
  Widget build(BuildContext context) {
    // Всегда показываем оверлей при ошибке, иначе только если контролы видимы
    final shouldShow = _showControls || widget.state.error != null;

    return Focus(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        // Сбрасываем таймер скрытия при любом нажатии клавиши (включая повторы)
        if ((event is KeyDownEvent || event is KeyRepeatEvent) && _showControls) {
          _startHideTimer();
        }
        
        // Обработка клавиш когда контролы скрыты
        if (!_showControls && widget.state.error == null) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _seekBackward();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _seekForward();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) {
              // Показываем контролы и передаем информацию о клавише для установки фокуса
              _showControlsTemporarily(triggeredByKey: event.logicalKey);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        }
        
        // Обработка клавиш когда контролы видны
        if (_showControls) {
          // Если контролы видны, но фокуса нет - устанавливаем его
          if (event is KeyDownEvent && !_hasAnyFocus()) {
            _setInitialFocus(event.logicalKey);
            return KeyEventResult.handled;
          }
          
          // Если фокус на прогресс-баре и нажали влево/вправо - перемотка
          if (_progressBarFocusNode.hasFocus) {
            if (event is KeyDownEvent) {
              // Первое нажатие - обычная перемотка на 10 секунд
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _seekBackward();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _seekForward();
                return KeyEventResult.handled;
              }
            } else if (event is KeyRepeatEvent) {
              // Удержание - непрерывная перемотка с ускорением
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _seekBackward(continuous: true);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _seekForward(continuous: true);
                return KeyEventResult.handled;
              }
            }
          }
          
          // Навигация вверх/вниз между рядами
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              // С нижнего ряда на прогресс-бар
              if (_qualityFocusNode.hasFocus || _audioFocusNode.hasFocus ||
                  _rewindFocusNode.hasFocus || _playPauseFocusNode.hasFocus ||
                  _forwardFocusNode.hasFocus || _fullscreenFocusNode.hasFocus) {
                _progressBarFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              // С прогресс-бара на нижний ряд (центральная кнопка)
              if (_progressBarFocusNode.hasFocus) {
                _playPauseFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              // С нижнего ряда вниз - скрыть контролы
              if (_qualityFocusNode.hasFocus || _audioFocusNode.hasFocus ||
                  _rewindFocusNode.hasFocus || _playPauseFocusNode.hasFocus ||
                  _forwardFocusNode.hasFocus || _fullscreenFocusNode.hasFocus) {
                _hideControls();
                return KeyEventResult.handled;
              }
            }
          }
          
          // Навигация по нижнему ряду (ручное управление)
          if (event is KeyDownEvent) {
            // Порядок кнопок: Quality -> Audio -> Rewind -> PlayPause -> Forward -> Fullscreen
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              if (_audioFocusNode.hasFocus) {
                _qualityFocusNode.requestFocus();
                return KeyEventResult.handled;
              } else if (_rewindFocusNode.hasFocus) {
                _audioFocusNode.requestFocus();
                return KeyEventResult.handled;
              } else if (_playPauseFocusNode.hasFocus) {
                _rewindFocusNode.requestFocus();
                return KeyEventResult.handled;
              } else if (_forwardFocusNode.hasFocus) {
                _playPauseFocusNode.requestFocus();
                return KeyEventResult.handled;
              } else if (_fullscreenFocusNode.hasFocus) {
                _forwardFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              // Если на Quality (крайняя левая) - ничего не делаем
              if (_qualityFocusNode.hasFocus) {
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              if (_qualityFocusNode.hasFocus) {
                _audioFocusNode.requestFocus();
                return KeyEventResult.handled;
              } else if (_audioFocusNode.hasFocus) {
                _rewindFocusNode.requestFocus();
                return KeyEventResult.handled;
              } else if (_rewindFocusNode.hasFocus) {
                _playPauseFocusNode.requestFocus();
                return KeyEventResult.handled;
              } else if (_playPauseFocusNode.hasFocus) {
                _forwardFocusNode.requestFocus();
                return KeyEventResult.handled;
              } else if (_forwardFocusNode.hasFocus) {
                _fullscreenFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              // Если на Fullscreen (крайняя правая) - ничего не делаем
              if (_fullscreenFocusNode.hasFocus) {
                return KeyEventResult.handled;
              }
            }
          }
        }
        
        // Прекращаем перемотку при отпускании клавиши
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
                                  focusNode: _progressBarFocusNode,
                                  autofocus: false,
                                  onPressed: () {},
                                  onLongPressStart: () {
                                    // Длительное нажатие на прогресс-баре можно использовать для навигации
                                  },
                                  child: ProgressBar(
                                    state: widget.state,
                                    controller: widget.controller,
                                    formatDuration: widget.formatDuration ?? _defaultFormatDuration,
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
                                              key: _qualityButtonKey,
                                              controller: widget.controller,
                                              onInteraction: _startHideTimer,
                                              focusNode: _qualityFocusNode,
                                            ),
                                            const SizedBox(width: 8),
                                            AudioTrackButton(
                                              key: _audioButtonKey,
                                              controller: widget.controller,
                                              onInteraction: _startHideTimer,
                                              focusNode: _audioFocusNode,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          FocusableControlButton(
                                            focusNode: _rewindFocusNode,
                                            onPressed: () {
                                              _seekBackward();
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
                                            focusNode: _playPauseFocusNode,
                                            onPressed: _togglePlayPause,
                                            child: PlayPauseButton(
                                              controller: widget.controller,
                                              state: widget.state,
                                              onInteraction: _startHideTimer,
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          FocusableControlButton(
                                            focusNode: _forwardFocusNode,
                                            onPressed: () {
                                              _seekForward();
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
                                              focusNode: _fullscreenFocusNode,
                                              onPressed: () {
                                                _startHideTimer();
                                                _toggleFullscreen(context);
                                              },
                                              child: FullscreenButton(
                                                isFullscreen: widget.isFullscreen,
                                                onPressed: () {
                                                  _startHideTimer();
                                                  _toggleFullscreen(context);
                                                },
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

/// Полноэкранная страница воспроизведения
class _FullscreenPlayerPage extends StatefulWidget {
  final RhsPlayerController controller;
  final String Function(Duration) formatDuration;
  final Duration? controlsHideAfter;
  final int? initialFocusIndex;

  const _FullscreenPlayerPage({
    required this.controller,
    required this.formatDuration,
    required this.controlsHideAfter,
    this.initialFocusIndex,
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
                      initialFocusIndex: widget.initialFocusIndex,
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
