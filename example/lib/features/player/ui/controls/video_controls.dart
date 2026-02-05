import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/features/player/ui/controls/widgets/play_pause_button.dart';
import 'package:rhs_player_example/features/player/ui/controls/builder/video_controls_builder.dart';
import 'package:rhs_player_example/features/player/ui/controls/core/key_handling_result.dart';
import 'package:rhs_player_example/features/player/ui/controls/items/button_item.dart';
import 'package:rhs_player_example/features/player/ui/controls/items/custom_widget_item.dart';
import 'package:rhs_player_example/features/player/ui/controls/items/quality_selector_item.dart';
import 'package:rhs_player_example/features/player/ui/controls/items/soundtrack_selector_item.dart';
import 'package:rhs_player_example/features/player/ui/controls/items/progress_slider_item.dart';
import 'package:rhs_player_example/features/player/ui/controls/rows/full_width_row.dart';
import 'package:rhs_player_example/features/player/ui/controls/rows/recommended_carousel_row.dart';
import 'package:rhs_player_example/features/player/ui/controls/rows/three_zone_button_row.dart';
import 'package:rhs_player_example/features/player/ui/controls/rows/top_bar_row.dart';
import 'package:rhs_player_example/shared/ui/theme/app_durations.dart';

/// Виджет управления видео с поддержкой Android TV пульта
/// Использует новую систему навигации с Chain of Responsibility паттерном
class VideoControls extends StatefulWidget {
  final RhsPlayerController controller;
  final VoidCallback onSwitchSource;
  final VoidCallback? onFavoritePressed;
  final List<RecommendedCarouselItem> recommendedItems;
  final int initialRecommendedIndex;
  final void Function(int index)? onRecommendedScrollIndexChanged;
  final void Function(RecommendedCarouselItem item)? onRecommendedItemActivated;

  /// Время до автоскрытия контролов с момента последнего действия (клавиша/взаимодействие).
  /// Если null или [Duration.zero], автоскрытие отключено.
  final Duration? autoHideDelay;

  /// Регистрация обработчика аппаратной кнопки Back (ряд home/back).
  /// Передаётся функция: при вызове возвращает true, если контролы были видны и скрыты (back поглощён), иначе false.
  final void Function(bool Function()? handler)? registerBackHandler;

  /// Вызывается при нажатии UI-кнопки «Назад» (всегда выход с экрана, без скрытия контролов).
  final VoidCallback? onBackButtonPressed;

  const VideoControls({
    super.key,
    required this.controller,
    required this.onSwitchSource,
    required this.recommendedItems,
    this.onFavoritePressed,
    this.initialRecommendedIndex = 0,
    this.onRecommendedScrollIndexChanged,
    this.onRecommendedItemActivated,
    this.autoHideDelay = const Duration(seconds: 5),
    this.registerBackHandler,
    this.onBackButtonPressed,
  });

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  /// Колбэки навигации из билдера (родительский context не видит VideoControlsNavigation).
  NavCallbacks? _nav;

  /// Key ряда карусели для определения клика вне карусели (свернуть при клике мимо).
  final GlobalKey _carouselRowKey = GlobalKey();

  /// Видимость контролов (верхняя/нижняя группа с анимацией).
  bool _controlsVisible = true;

  /// Показывать слайдер прогресса при перемотке со скрытыми контролами.
  bool _seekingOverlayVisible = false;

  /// Таймер автоскрытия контролов.
  Timer? _hideTimer;

  /// Таймер скрытия слайдера после перемотки (контролы скрыты).
  Timer? _seekingOverlayTimer;

  /// Открыто меню выбора качества или саундтрека — контролы скрывать нельзя.
  bool _isMenuOpen = false;

  /// Показывать кнопку качества только после загрузки видеотреков.
  bool _hasVideoTracks = false;
  VoidCallback? _removeVideoTracksListener;

  /// Показывать кнопку саундтрека только при наличии аудиотреков.
  bool _hasAudioTracks = false;
  VoidCallback? _removeAudioTracksListener;

  RhsPlayerStatus? _previousPlayerStatus;
  VoidCallback? _removeStatusListener;

  /// Повтор перемотки при удержании влево/вправо (контролы скрыты).
  Timer? _prioritySeekTimer;
  LogicalKeyboardKey? _prioritySeekKey;
  int _prioritySeekTick = 0;

  @override
  void initState() {
    super.initState();
    _previousPlayerStatus = widget.controller.currentPlayerStatus;
    _removeStatusListener = widget.controller.addStatusListener((status) {
      final wasPaused = _previousPlayerStatus is RhsPlayerStatusPaused;
      _previousPlayerStatus = status;
      if (wasPaused &&
          (status is RhsPlayerStatusPlaying ||
              status is RhsPlayerStatusLoading)) {
        _resetHideTimer();
      }
    });
    _removeVideoTracksListener = widget.controller.addVideoTracksListener((
      tracks,
    ) {
      if (mounted) {
        setState(() => _hasVideoTracks = tracks.isNotEmpty);
      }
    });
    _removeAudioTracksListener = widget.controller.addAudioTracksListener((
      tracks,
    ) {
      if (mounted) {
        setState(() => _hasAudioTracks = tracks.isNotEmpty);
      }
    });
    _resetHideTimer();
    // Обработчик аппаратной кнопки Back (ряд home/back) — через registerBackHandler + PopScope на экране
    widget.registerBackHandler?.call(() {
      if (_controlsVisible) {
        _hideControls();
        return true;
      }
      return false;
    });
    // Приоритетный обработчик клавиш - перехватывает ДО системы фокусов
    ServicesBinding.instance.keyboard.addHandler(_handlePriorityKey);
  }

  bool _handlePriorityKey(KeyEvent event) {
    // Остановка повтора перемотки при отпускании влево/вправо (в любом состоянии контролов)
    if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_prioritySeekKey == event.logicalKey) {
          _prioritySeekTimer?.cancel();
          _prioritySeekTimer = null;
          _prioritySeekKey = null;
        }
        return true;
      }
      return false;
    }

    if (event is KeyDownEvent && !_controlsVisible) {
      final key = event.logicalKey;
      debugPrint('Priority key handler: key=$key, controlsVisible=false');

      switch (key) {
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.enter:
          debugPrint('Priority key handler: OK pressed, showing controls');
          _showControls(resetFocus: true);
          return true;

        case LogicalKeyboardKey.arrowLeft:
          _prioritySeekTimer?.cancel();
          _prioritySeekKey = LogicalKeyboardKey.arrowLeft;
          _prioritySeekTick = 0;
          _seekBackward(AppDurations.seekStepForTick(0));
          _prioritySeekTimer = Timer.periodic(AppDurations.repeatInterval, (_) {
            if (!mounted) {
              _prioritySeekTimer?.cancel();
              return;
            }
            _prioritySeekTick++;
            _seekBackward(AppDurations.seekStepForTick(_prioritySeekTick));
          });
          return true;

        case LogicalKeyboardKey.arrowRight:
          _prioritySeekTimer?.cancel();
          _prioritySeekKey = LogicalKeyboardKey.arrowRight;
          _prioritySeekTick = 0;
          _seekForward(AppDurations.seekStepForTick(0));
          _prioritySeekTimer = Timer.periodic(AppDurations.repeatInterval, (_) {
            if (!mounted) {
              _prioritySeekTimer?.cancel();
              return;
            }
            _prioritySeekTick++;
            _seekForward(AppDurations.seekStepForTick(_prioritySeekTick));
          });
          return true;

        case LogicalKeyboardKey.arrowUp:
        case LogicalKeyboardKey.arrowDown:
          debugPrint('Priority key handler: Up/Down arrow, showing controls');
          _showControls(resetFocus: true);
          return true;

        default:
          break;
      }
    }
    return false;
  }

  @override
  void dispose() {
    widget.registerBackHandler?.call(null);
    ServicesBinding.instance.keyboard.removeHandler(_handlePriorityKey);
    _prioritySeekTimer?.cancel();
    _hideTimer?.cancel();
    _seekingOverlayTimer?.cancel();
    _removeStatusListener?.call();
    _removeVideoTracksListener?.call();
    _removeAudioTracksListener?.call();
    super.dispose();
  }

  void _showControls({bool resetFocus = false}) {
    debugPrint('_showControls called: resetFocus=$resetFocus');
    _hideTimer?.cancel();
    _seekingOverlayTimer?.cancel();
    if (!_controlsVisible && mounted) {
      setState(() {
        _controlsVisible = true;
        _seekingOverlayVisible = false;
      });
      // Если нужно сбросить фокус, запланируем восстановление на initial элемент
      if (resetFocus) {
        debugPrint(
          '_showControls: scheduling focus restore to play_pause_button',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _nav?.scheduleFocusRestore('play_pause_button');
        });
      }
    }
    _resetHideTimer();
  }

  void _hideControls() {
    if (_controlsVisible && mounted) {
      setState(() => _controlsVisible = false);
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    final delay = widget.autoHideDelay;
    if (delay != null && delay != Duration.zero) {
      _hideTimer = Timer(delay, () {
        if (!mounted) return;
        final status = widget.controller.currentPlayerStatus;
        if (status is RhsPlayerStatusPaused) return;
        // Не скрывать контролы, если открыто меню качества/саундтрека
        if (_isMenuOpen) return;
        // Не скрывать, пока фокус на карусели — перезапускаем таймер
        if (_nav?.getFocusedItemId() == 'recommended_row_carousel') {
          _resetHideTimer();
          return;
        }
        _hideControls();
      });
    }
  }

  void _onMenuOpened() {
    debugPrint('VideoControls: menu opened, canceling hide timer');
    _hideTimer?.cancel();
    setState(() => _isMenuOpen = true);
  }

  void _onMenuClosed() {
    debugPrint('VideoControls: menu closed, resetting hide timer');
    setState(() => _isMenuOpen = false);
    _resetHideTimer();
  }

  void _toggleControlsVisibility() {
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  Widget _buildBufferingOverlay() {
    return StreamBuilder<RhsPlayerStatus>(
      stream: widget.controller.playerStatusStream,
      builder: (context, snapshot) {
        if (snapshot.data is RhsPlayerStatusLoading) {
          return Center(
            child: SizedBox(
              width: 80.r,
              height: 80.r,
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildBufferingOverlay(),
        VideoControlsBuilder(
          initialFocusId: 'play_pause_button',
          controlsVisible: _controlsVisible,
          showProgressSlider: _controlsVisible || _seekingOverlayVisible,
          onNavReady: (callbacks) => _nav = callbacks,
          onControlsInteraction: _showControls,
          onToggleVisibilityRequested: _toggleControlsVisibility,
          onSeekBackward: _seekBackward,
          onSeekForward: _seekForward,
          onHideControlsWhenDownFromLastRow: _hideControls,
          carouselRowKey: _carouselRowKey,
          rows: [
            TopBarRow(
              id: 'top_bar_row',
              index: 0,
              height: 124,
              backgroundColor: const Color(0xCC201B2E),
              horizontalPadding: 120,
              title: 'Тут будет название фильма',
              leftItems: [
                ButtonItem(
                  id: 'back_button',
                  onPressed: () {
                    final onBack = widget.onBackButtonPressed;
                    if (onBack != null) {
                      onBack();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  buttonSize: 76,
                  buttonBorderRadius: 16,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(left: 5.w),
                      child: Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                  ),
                ),
              ],
              rightItems: _hasAudioTracks
                  ? [
                      CustomWidgetItem(
                        id: 'soundtrack_selector',
                        builder: (focusNode) => SoundtrackSelectorItem(
                          controller: widget.controller,
                          focusNode: focusNode,
                          onRegisterOverlayFocus:
                              _nav?.registerOverlayFocusNode,
                          onMenuOpened: _onMenuOpened,
                          onMenuClosed: _onMenuClosed,
                        ),
                      ),
                    ]
                  : [],
            ),
            FullWidthRow(
              id: 'progress_row',
              index: 1,
              padding: EdgeInsets.symmetric(horizontal: 120.w),
              items: [
                ProgressSliderItem(
                  id: 'progress_slider',
                  controller: widget.controller,
                  onSeekBackward: _seekBackward,
                  onSeekForward: _seekForward,
                ),
              ],
            ),
            ThreeZoneButtonRow(
              id: 'control_buttons_row',
              index: 2,
              spacing: 32,
              leftItems: [
                ButtonItem(
                  id: 'favorite_button',
                  onPressed: widget.onFavoritePressed ?? () {},
                  child: Center(
                    child: SizedBox(
                      width: 56.w,
                      height: 56.h,
                      child: ImageIcon(AssetImage('assets/controls/like.png')),
                    ),
                  ),
                ),
              ],
              centerItems: [
                ButtonItem(
                  id: 'rewind_button',
                  onPressedWithStep: _seekBackward,
                  repeatWhileHeld: true,
                  child: Center(
                    child: SizedBox(
                      width: 56.w,
                      height: 56.h,
                      child: ImageIcon(
                        AssetImage('assets/controls/rewind_L.png'),
                      ),
                    ),
                  ),
                ),
                CustomWidgetItem(
                  id: 'play_pause_button',
                  keyHandler: (event) {
                    // Обрабатываем OK только когда контролы видимы
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.enter)) {
                      debugPrint(
                        'play_pause keyHandler: controlsVisible=$_controlsVisible',
                      );
                      if (_controlsVisible) {
                        _togglePlayPause();
                        return KeyHandlingResult.handled;
                      }
                      return KeyHandlingResult.notHandled;
                    }
                    return KeyHandlingResult.notHandled;
                  },
                  builder: (focusNode) => StreamBuilder<RhsPlayerStatus>(
                    stream: widget.controller.playerStatusStream,
                    builder: (context, snapshot) {
                      final status = snapshot.data;
                      final isPlaying =
                          status is RhsPlayerStatusPlaying ||
                          status is RhsPlayerStatusLoading;
                      return PlayPauseButton(
                        focusNode: focusNode,
                        isPlaying: isPlaying,
                        onPressed: _togglePlayPause,
                      );
                    },
                  ),
                ),
                ButtonItem(
                  id: 'forward_button',
                  onPressedWithStep: _seekForward,
                  repeatWhileHeld: true,
                  child: Center(
                    child: SizedBox(
                      width: 56.w,
                      height: 56.h,
                      child: ImageIcon(
                        AssetImage('assets/controls/rewind_R.png'),
                      ),
                    ),
                  ),
                ),
              ],
              rightItems: _hasVideoTracks
                  ? [
                      CustomWidgetItem(
                        id: 'quality_selector',
                        builder: (focusNode) => QualitySelectorItem(
                          controller: widget.controller,
                          focusNode: focusNode,
                          onRegisterOverlayFocus:
                              _nav?.registerOverlayFocusNode,
                          onMenuOpened: _onMenuOpened,
                          onMenuClosed: _onMenuClosed,
                        ),
                      ),
                    ]
                  : [],
            ),
            RecommendedCarouselRow(
              key: _carouselRowKey,
              id: 'recommended_row',
              index: 3,
              carouselItems: widget.recommendedItems,
              initialScrollIndex: widget.initialRecommendedIndex,
              onItemSelected: widget.onRecommendedScrollIndexChanged,
              onItemActivated: widget.onRecommendedItemActivated == null
                  ? null
                  : (item) {
                      final requestFocus = _nav?.requestFocusOnId;
                      final scheduleRestore = _nav?.scheduleFocusRestore;
                      scheduleRestore?.call('play_pause_button');
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        requestFocus?.call('play_pause_button');
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            widget.onRecommendedItemActivated!(item);
                          });
                        });
                      });
                    },
            ),
          ],
        ),
      ],
    );
  }

  void _seekBackward([Duration? step]) {
    _onSeekWhileControlsHidden();
    final s = step ?? const Duration(seconds: 10);
    final newPosition = widget.controller.currentPosition - s;
    widget.controller.seekTo(
      newPosition > Duration.zero ? newPosition : Duration.zero,
    );
  }

  void _seekForward([Duration? step]) {
    _onSeekWhileControlsHidden();
    final s = step ?? const Duration(seconds: 10);
    final newPosition = widget.controller.currentPosition + s;
    final duration = widget.controller.currentPositionData.duration;
    widget.controller.seekTo(newPosition < duration ? newPosition : duration);
  }

  /// При перемотке со скрытыми контролами показываем слайдер на время.
  void _onSeekWhileControlsHidden() {
    if (!_controlsVisible && mounted) {
      _seekingOverlayTimer?.cancel();
      setState(() => _seekingOverlayVisible = true);
      _seekingOverlayTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _seekingOverlayVisible = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    final status = widget.controller.currentPlayerStatus;
    if (status is RhsPlayerStatusPlaying || status is RhsPlayerStatusLoading) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
  }
}
