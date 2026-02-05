import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/features/player/ui/actions/player_actions.dart';
import 'package:rhs_player_example/features/player/ui/actions/player_intents.dart';
import 'package:rhs_player_example/features/player/ui/actions/player_shortcuts.dart';
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
import 'package:rhs_player_example/features/player/ui/controls/state/controls_event.dart';
import 'package:rhs_player_example/features/player/ui/controls/state/controls_state.dart';
import 'package:rhs_player_example/features/player/ui/controls/state/controls_state_machine.dart';
import 'package:rhs_player_example/features/player/ui/controls/state/state_config.dart';
import 'package:rhs_player_example/shared/ui/theme/app_durations.dart';

/// Виджет управления видео с поддержкой Android TV пульта.
///
/// Использует паттерны:
/// - State Machine для управления состояниями контролов (ControlsStateMachine)
/// - Chain of Responsibility для навигации между элементами (NavigationManager)
/// - Actions/Intents для обработки команд управления плеером
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
  // ==================== State Machine ====================

  /// State Machine управления состояниями контролов (скрыты/видны/меню/пауза и т.д.)
  late final ControlsStateMachine _stateMachine;

  // ==================== Навигация и UI ====================

  /// Колбэки навигации из билдера (родительский context не видит VideoControlsNavigation).
  NavCallbacks? _nav;

  /// Key ряда карусели для определения клика вне карусели (свернуть при клике мимо).
  final GlobalKey _carouselRowKey = GlobalKey();

  // ==================== Треки (видео/аудио) ====================

  /// Показывать кнопку качества только после загрузки видеотреков.
  bool _hasVideoTracks = false;
  VoidCallback? _removeVideoTracksListener;

  /// Показывать кнопку саундтрека только при наличии аудиотреков.
  bool _hasAudioTracks = false;
  VoidCallback? _removeAudioTracksListener;

  // ==================== Статус плеера ====================

  VoidCallback? _removeStatusListener;

  // ==================== Приоритетная обработка клавиш (повтор перемотки) ====================

  /// Таймер повтора перемотки при удержании влево/вправо (контролы скрыты).
  /// Управляется локально, не через State Machine, т.к. это UI-специфичная логика.
  Timer? _prioritySeekTimer;
  LogicalKeyboardKey? _prioritySeekKey;
  int _prioritySeekTick = 0;

  @override
  void initState() {
    super.initState();

    // ==================== Инициализация State Machine ====================

    _stateMachine = ControlsStateMachine(
      config: StateConfig(
        autoHideDelay: widget.autoHideDelay,
        seekingOverlayDuration: const Duration(seconds: 2),
      ),
      // Начальное состояние - контролы видны в режиме peek
      initialState: const ControlsVisiblePeekState(),
      // Callback на изменение состояния - обновляем UI и обрабатываем side effects
      onStateChanged: (oldState, newState) {
        if (mounted) {
          setState(() {});
          _handleStateTransition(oldState, newState);
        }
      },
    );

    // ==================== Подписка на статус плеера ====================

    // Отправляем события изменения статуса в State Machine
    _removeStatusListener = widget.controller.addStatusListener((status) {
      _stateMachine.handleEvent(PlayerStatusChangedEvent(status));
    });

    // ==================== Подписка на треки ====================

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

    // ==================== Аппаратная кнопка Back ====================

    // Обработчик аппаратной кнопки Back (ряд home/back) — через registerBackHandler + PopScope на экране
    widget.registerBackHandler?.call(() {
      final state = _stateMachine.currentState;
      final isHidden =
          state is ControlsHiddenState || state is SeekingOverlayState;

      if (isHidden) {
        return false; // контролы скрыты — страница покажет «Назад ещё раз» или выйдет
      }
      // Карусель развёрнута — уводим фокус на play/pause, тогда onFocusChanged вызовет переход в peek
      if (state is ControlsVisibleExpandedState) {
        _nav?.requestFocusOnId('play_pause_button');
        return true;
      }
      // Контролы видны (peek и др.) — скрыть контролы
      _stateMachine.handleEvent(const HideControlsEvent());
      return true;
    });

    // ==================== Приоритетный обработчик клавиш ====================

    // Перехватывает события ДО системы фокусов для обработки при скрытых контролах
    ServicesBinding.instance.keyboard.addHandler(_handlePriorityKey);
  }

  /// Приоритетный обработчик клавиш для скрытых контролов.
  ///
  /// Перехватывает события ДО системы фокусов для обработки при скрытых контролах:
  /// - OK/Enter/стрелки вверх/вниз → показать контролы (через ShowControlsEvent)
  /// - Стрелки влево/вправо → перемотка с повтором при удержании (через SeekWhileHiddenEvent)
  ///
  /// Возвращает true, если событие обработано (поглощено).
  bool _handlePriorityKey(KeyEvent event) {
    // Остановка повтора перемотки при отпускании влево/вправо
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

    // Обработка только при KeyDownEvent и скрытых контролах
    if (event is! KeyDownEvent) return false;

    final state = _stateMachine.currentState;
    final isControlsHidden =
        state is ControlsHiddenState || state is SeekingOverlayState;

    if (!isControlsHidden) return false;

    final key = event.logicalKey;

    // OK/Enter/стрелки вверх/вниз → показать контролы с восстановлением фокуса
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      log('Priority key handler: $key pressed, showing controls');
      _stateMachine.handleEvent(const ShowControlsEvent(resetFocus: true));
      return true;
    }

    // Стрелки влево/вправо → перемотка с повтором при удержании
    if (key == LogicalKeyboardKey.arrowLeft) {
      _prioritySeekTimer?.cancel();
      _prioritySeekKey = LogicalKeyboardKey.arrowLeft;
      _prioritySeekTick = 0;
      _seekBackward(AppDurations.seekStepForTick(0));
      // Уведомляем State Machine о перемотке (для показа слайдера)
      _stateMachine.handleEvent(const SeekWhileHiddenEvent());
      // Запускаем повтор перемотки
      _prioritySeekTimer = Timer.periodic(AppDurations.repeatInterval, (_) {
        if (!mounted) {
          _prioritySeekTimer?.cancel();
          return;
        }
        _prioritySeekTick++;
        _seekBackward(AppDurations.seekStepForTick(_prioritySeekTick));
        // При каждом повторе сбрасываем таймер слайдера
        _stateMachine.handleEvent(const SeekWhileHiddenEvent());
      });
      return true;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      _prioritySeekTimer?.cancel();
      _prioritySeekKey = LogicalKeyboardKey.arrowRight;
      _prioritySeekTick = 0;
      _seekForward(AppDurations.seekStepForTick(0));
      // Уведомляем State Machine о перемотке (для показа слайдера)
      _stateMachine.handleEvent(const SeekWhileHiddenEvent());
      // Запускаем повтор перемотки
      _prioritySeekTimer = Timer.periodic(AppDurations.repeatInterval, (_) {
        if (!mounted) {
          _prioritySeekTimer?.cancel();
          return;
        }
        _prioritySeekTick++;
        _seekForward(AppDurations.seekStepForTick(_prioritySeekTick));
        // При каждом повторе сбрасываем таймер слайдера
        _stateMachine.handleEvent(const SeekWhileHiddenEvent());
      });
      return true;
    }

    return false;
  }

  @override
  void dispose() {
    // Очистка State Machine (отмена таймеров)
    _stateMachine.dispose();

    // Очистка обработчиков
    widget.registerBackHandler?.call(null);
    ServicesBinding.instance.keyboard.removeHandler(_handlePriorityKey);

    // Отмена таймера повтора перемотки
    _prioritySeekTimer?.cancel();

    // Отписка от событий плеера
    _removeStatusListener?.call();
    _removeVideoTracksListener?.call();
    _removeAudioTracksListener?.call();

    super.dispose();
  }

  // ==================== Обработчики состояний и переходов ====================

  /// Обработка side effects при переходе между состояниями.
  ///
  /// Вызывается из onStateChanged callback State Machine.
  /// Фокус при показе контролов восстанавливается в билдере по _focusedIdBeforeHide ?? initialFocusId.
  void _handleStateTransition(ControlsState oldState, ControlsState newState) {
    log('State transition: $oldState → $newState');
  }

  // ==================== Публичные методы управления контролами ====================

  /// Показать контролы (обёртка для ShowControlsEvent).
  void _showControls({bool resetFocus = false}) {
    _stateMachine.handleEvent(ShowControlsEvent(resetFocus: resetFocus));
  }

  /// Скрыть контролы (обёртка для HideControlsEvent).
  void _hideControls() {
    _stateMachine.handleEvent(const HideControlsEvent());
  }

  /// Переключить видимость контролов (обёртка для ToggleControlsEvent).
  void _toggleControlsVisibility() {
    _stateMachine.handleEvent(const ToggleControlsEvent());
  }

  /// Меню открыто (обёртка для MenuOpenedEvent).
  void _onMenuOpened() {
    log('VideoControls: menu opened');
    _stateMachine.handleEvent(const MenuOpenedEvent());
  }

  /// Меню закрыто (обёртка для MenuClosedEvent).
  void _onMenuClosed() {
    log('VideoControls: menu closed');
    _stateMachine.handleEvent(const MenuClosedEvent());
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
    // Получаем текущее состояние и конфигурацию видимости из State Machine
    final state = _stateMachine.currentState;
    final config = state.visibilityConfig;

    // Определяем, видны ли контролы (для Shortcuts и других проверок)
    final isVisible =
        state is! ControlsHiddenState && state is! SeekingOverlayState;

    return Stack(
      children: [
        _buildBufferingOverlay(),
        Shortcuts(
          shortcuts: buildPlayerShortcuts(controlsVisible: isVisible),
          child: Actions(
            actions: <Type, Action<Intent>>{
              // Playback actions
              TogglePlayPauseIntent: TogglePlayPauseAction(widget.controller),
              // Seek actions
              SeekBackwardIntent: SeekBackwardAction(widget.controller),
              SeekForwardIntent: SeekForwardAction(widget.controller),
              // Controls visibility actions
              ShowControlsIntent: ShowControlsAction(_showControls),
              HideControlsIntent: HideControlsAction(_hideControls),
              ToggleControlsVisibilityIntent: ToggleControlsVisibilityAction(
                _toggleControlsVisibility,
              ),
            },
            child: VideoControlsBuilder(
              initialFocusId: 'play_pause_button',
              // Передаём конфигурацию видимости из State Machine
              controlsVisible: !config.excludeFromFocus,
              showProgressSlider: config.showProgressSlider,
              // Callback для получения навигационных колбэков
              onNavReady: (callbacks) => _nav = callbacks,
              // Взаимодействие с контролами -> сброс таймера
              onControlsInteraction: () {
                _stateMachine.handleEvent(const UserInteractionEvent());
              },
              // Изменение фокуса -> отправка события в State Machine
              onFocusChanged: (itemId) {
                _stateMachine.handleEvent(FocusChangedEvent(itemId));
              },
              onToggleVisibilityRequested: _toggleControlsVisibility,
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
                          child: Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                          ),
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
                          child: ImageIcon(
                            AssetImage('assets/controls/like.png'),
                          ),
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
                          // Проверяем видимость контролов через State Machine
                          final isVisible =
                              _stateMachine.currentState
                                  is! ControlsHiddenState &&
                              _stateMachine.currentState
                                  is! SeekingOverlayState;
                          log(
                            'play_pause keyHandler: controlsVisible=$isVisible',
                          );
                          if (isVisible) {
                            // Вызываем Action для переключения play/pause
                            Actions.maybeInvoke<TogglePlayPauseIntent>(
                              context,
                              const TogglePlayPauseIntent(),
                            );
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
                            onPressed: () {
                              // Вызываем Action для переключения play/pause
                              Actions.maybeInvoke<TogglePlayPauseIntent>(
                                context,
                                const TogglePlayPauseIntent(),
                              );
                            },
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
          ),
        ),
      ],
    );
  }

  // ==================== Методы перемотки ====================

  /// Перемотка назад на указанный шаг.
  ///
  /// Используется из:
  /// - Приоритетного обработчика клавиш (_handlePriorityKey)
  /// - Кнопок перемотки (ButtonItem с onPressedWithStep)
  /// - ProgressSliderItem (при навигации стрелками)
  void _seekBackward(Duration step) {
    final newPosition = widget.controller.currentPosition - step;
    widget.controller.seekTo(
      newPosition > Duration.zero ? newPosition : Duration.zero,
    );
  }

  /// Перемотка вперёд на указанный шаг.
  ///
  /// Используется из:
  /// - Приоритетного обработчика клавиш (_handlePriorityKey)
  /// - Кнопок перемотки (ButtonItem с onPressedWithStep)
  /// - ProgressSliderItem (при навигации стрелками)
  void _seekForward(Duration step) {
    final newPosition = widget.controller.currentPosition + step;
    final duration = widget.controller.currentPositionData.duration;
    widget.controller.seekTo(newPosition < duration ? newPosition : duration);
  }
}
