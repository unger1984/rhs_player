import 'dart:async';
import 'package:flutter/material.dart';
import '../platform/native_player_controller.dart';
import '../platform/native_player_view.dart';
import '../platform/native_events.dart';
import '../platform/native_tracks.dart';
import '../utils/native_bridge.dart';
import '../utils/thumbnails.dart';
import 'modern_player_controls.dart';
import 'vertical_slider.dart';

/// Высокоуровневый виджет Flutter, который отображает современный интерфейс
/// с поддержкой жестов.
class RhsModernPlayer extends StatefulWidget {
  /// Контроллер для управления воспроизведением
  final RhsNativePlayerController controller;

  /// Дополнительный оверлей, который будет отображаться поверх плеера
  final Widget? overlay;

  /// Время перемотки при двойном нажатии
  final Duration doubleTapSeek;

  /// Время перемотки при длительном нажатии
  final Duration longPressSeek;

  /// Время автоматического скрытия элементов управления
  final Duration autoHideAfter;

  /// Начальный режим масштабирования видео
  final BoxFit initialBoxFit;

  /// Флаг блокировки элементов управления при запуске
  final bool startLocked;

  /// Флаг полноэкранного режима
  final bool isFullscreen;

  /// Флаг автоматического перехода в полноэкранный режим
  final bool autoFullscreen;

  /// Обработчик изменения состояния воспроизведения
  final ValueChanged<RhsPlaybackState>? onStateChanged;

  /// Обработчик ошибок воспроизведения
  final ValueChanged<String?>? onError;

  /// Коллбек переключения полноэкранного режима.
  ///
  /// Вызывается с `true`, когда плеер запрашивает переход в fullscreen
  /// (по кнопке или при autoFullscreen), и с `false`, когда пользователь
  /// нажимает "выйти из fullscreen" в контролах.
  /// Сам `RhsModernPlayer` больше не открывает новый маршрут.
  final ValueChanged<bool>? onFullscreenChanged;

  const RhsModernPlayer({
    super.key,
    required this.controller,
    this.overlay,
    this.doubleTapSeek = const Duration(seconds: 10),
    this.longPressSeek = const Duration(seconds: 3),
    this.autoHideAfter = const Duration(seconds: 3),
    this.initialBoxFit = BoxFit.contain,
    this.startLocked = false,
    this.isFullscreen = false,
    this.autoFullscreen = false,
    this.onStateChanged,
    this.onError,
    this.onFullscreenChanged,
  });

  @override
  State<RhsModernPlayer> createState() => _RhsModernPlayerState();
}

class _RhsModernPlayerState extends State<RhsModernPlayer> {
  /// Интервал тиков при длительном нажатии
  static const Duration _longPressTick = Duration(milliseconds: 200);

  /// Уведомитель режима масштабирования
  late final ValueNotifier<BoxFit> _fit = ValueNotifier(widget.initialBoxFit);

  /// Флаг отображения элементов управления
  bool _showControls = true;

  /// Таймер автоматического скрытия элементов управления
  Timer? _hide;

  /// Позиция предварительного просмотра при перемотке
  Duration? _preview;

  /// Начальная позиция горизонтального перетаскивания
  Offset? _hStart;

  /// Флаг отображения регулятора громкости
  bool _showVol = false;

  /// Флаг отображения регулятора яркости
  bool _showBri = false;

  /// Уровень громкости
  double _volLevel = 0.5;

  /// Уровень яркости
  double _briLevel = 0.5;

  /// Таймер скрытия регуляторов громкости/яркости
  Timer? _vbHide;

  /// Флаг блокировки элементов управления
  bool _locked = false;

  /// Флаг отображения подсказки о блокировке
  bool _lockHint = false;

  /// Таймер скрытия подсказки о блокировке
  Timer? _lockHintTimer;

  /// Текст всплывающего уведомления при перемотке
  String? _seekFlash;

  /// Выравнивание всплывающего уведомления
  Alignment _seekFlashAlign = Alignment.center;

  /// Таймер скрытия всплывающего уведомления
  Timer? _seekFlashTimer;

  /// Таймер повтора перемотки при длительном нажатии
  Timer? _seekRepeat;

  /// Накопленное время при длительном нажатии
  Duration _longPressAccumulated = Duration.zero;

  /// Целевая позиция при длительном нажатии
  Duration? _longPressTarget;

  /// Направление перемотки при длительном нажатии (1 - вперед, -1 - назад)
  int _longPressDirection = 0;

  /// Список миниатюр для предварительного просмотра
  List<ThumbCue>? _thumbs;

  /// Флаг загрузки миниатюр
  bool _thumbsLoading = false;

  /// Флаг режима экономии трафика
  bool _dataSaver = false;

  /// Список доступных видео дорожек
  List<RhsVideoTrack> _videoTracks = const <RhsVideoTrack>[];

  /// Идентификатор выбранной видео дорожки
  String? _manualTrackId;

  /// Будущее завершения загрузки видео дорожек
  Future<void>? _pendingTrackFetch;

  /// Номер запроса на загрузку видео дорожек
  int _trackFetchTicket = 0;

  /// Флаг автоматического перехода в полноэкранный режим
  bool _autoFullscreenTriggered = false;

  /// Последнее уведомление о состоянии воспроизведения
  RhsPlaybackState? _lastStateNotification;

  /// Последнее уведомление об ошибке
  String? _lastErrorNotification;

  /// Список доступных аудио дорожек
  List<RhsAudioTrack> _audioTracks = const <RhsAudioTrack>[];

  /// Список доступных субтитров
  List<RhsSubtitleTrack> _subtitleTracks = const <RhsSubtitleTrack>[];

  /// Будущее завершения загрузки аудио дорожек
  Future<void>? _pendingAudioFetch;

  /// Будущее завершения загрузки субтитров
  Future<void>? _pendingSubtitleFetch;

  /// Номер запроса на загрузку аудио дорожек
  int _audioFetchTicket = 0;

  /// Номер запроса на загрузку субтитров
  int _subtitleFetchTicket = 0;

  /// Идентификатор выбранной аудио дорожки
  String? _manualAudioId;

  /// Идентификатор выбранных субтитров
  String? _manualSubtitleId;

  /// Текущая скорость воспроизведения
  double _currentSpeed = 1.0;

  /// Скорость воспроизведения перед ускорением
  double? _speedBeforeBoost;

  /// Размер круглых кнопок управления
  static const double _circleControlSize = 52;

  /// Получает заголовки для запроса миниатюр (берется из первого элемента плейлиста)
  Map<String, String>? get _thumbHeaders {
    final list = widget.controller.playlist;
    if (list.isEmpty) return null;
    return list.first.thumbnailHeaders;
  }

  /// Получает события воспроизведения из контроллера
  RhsNativeEvents? get _events => widget.controller.events;

  @override
  void dispose() {
    _hide?.cancel();
    _seekRepeat?.cancel();
    _seekFlashTimer?.cancel();
    _fit.dispose();
    super.dispose();
  }

  /// Перезапускает таймер автоматического скрытия элементов управления
  void _restartHide() {
    _hide?.cancel();
    _hide = Timer(widget.autoHideAfter, () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  /// Проверяет необходимость автоматического перехода в полноэкранный режим
  void _maybeAutoFullscreen() {
    if (_autoFullscreenTriggered) return;
    if (!widget.autoFullscreen || widget.isFullscreen) return;
    _autoFullscreenTriggered = true;
    _enterFullscreen();
  }

  /// Переходит в полноэкранный режим (делегирует это родителю через коллбек).
  void _enterFullscreen() {
    if (!mounted || widget.isFullscreen) return;
    // Локально просто сбрасываем временные оверлеи,
    // а реальный переход в fullscreen делает родитель.
    setState(() {
      _showControls = false;
      _preview = null;
      _seekFlash = null;
    });
    _hide?.cancel();
    widget.onFullscreenChanged?.call(true);
  }

  @override
  void didUpdateWidget(covariant RhsModernPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoFullscreen != widget.autoFullscreen && widget.autoFullscreen) {
      _autoFullscreenTriggered = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoFullscreen());
    }
  }

  /// Проверяет, изменилось ли состояние воспроизведения
  bool _hasStateChanged(RhsPlaybackState current) {
    final prev = _lastStateNotification;
    if (prev == null) return true;
    return prev.isPlaying != current.isPlaying ||
        prev.isBuffering != current.isBuffering ||
        prev.duration != current.duration ||
        prev.position != current.position;
  }

  @override
  void initState() {
    super.initState();
    _locked = widget.startLocked;
    _restartHide();
    _maybeLoadThumbs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshVideoTracks();
      _maybeAutoFullscreen();
    });
  }

  /// Загружает миниатюры для предварительного просмотра
  Future<void> _maybeLoadThumbs() async {
    if (_thumbsLoading) return;
    final list = widget.controller.playlist;
    if (list.isEmpty) return;
    final vtt = list.first.thumbnailVttUrl;
    if (vtt == null) return;
    setState(() => _thumbsLoading = true);
    try {
      final cues = await fetchVttThumbnails(vtt, headers: list.first.thumbnailHeaders);
      if (!mounted) return;
      setState(() {
        _thumbs = cues;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _thumbs = const [];
      });
    } finally {
      if (mounted) setState(() => _thumbsLoading = false);
    }
  }

  /// Отображает всплывающее уведомление при перемотке
  void _showSeekFlash(String text, Alignment alignment, {Duration? hideAfter}) {
    _seekFlashTimer?.cancel();
    _seekFlashTimer = null;
    if (!mounted) {
      _seekFlash = text;
      _seekFlashAlign = alignment;
      return;
    }
    setState(() {
      _seekFlash = text;
      _seekFlashAlign = alignment;
    });
    if (hideAfter != null) {
      _seekFlashTimer = Timer(hideAfter, () {
        if (!mounted) return;
        setState(() => _seekFlash = null);
      });
    } else {
      _seekFlashTimer = null;
    }
  }

  /// Скрывает всплывающее уведомление при перемотке
  void _hideSeekFlash() {
    _seekFlashTimer?.cancel();
    _seekFlashTimer = null;
    if (!mounted) {
      _seekFlash = null;
      return;
    }
    if (_seekFlash != null) {
      setState(() => _seekFlash = null);
    }
  }

  /// Начинает перемотку при длительном нажатии
  void _startLongPressSeek({required bool forward}) {
    final events = _events;
    if (events == null) return;
    final state = events.state.value;
    if (state.duration.inMilliseconds <= 0) return;
    _seekRepeat?.cancel();
    _seekFlashTimer?.cancel();
    _longPressDirection = forward ? 1 : -1;
    _longPressAccumulated = Duration.zero;
    _longPressTarget = state.position;
    _applyLongPressSeek();
    _seekRepeat = Timer.periodic(_longPressTick, (_) => _applyLongPressSeek());
    _restartHide();
  }

  /// Обновляет направление перемотки при длительном нажатии
  void _updateLongPressDirection({required bool forward}) {
    final newDirection = forward ? 1 : -1;
    if (_seekRepeat == null || _longPressDirection == newDirection) {
      return;
    }
    _longPressDirection = newDirection;
    _longPressAccumulated = Duration.zero;
    final events = _events;
    _longPressTarget = events?.state.value.position;
  }

  /// Применяет перемотку при длительном нажатии
  void _applyLongPressSeek() {
    final events = _events;
    if (events == null) return;
    if (_longPressDirection == 0) return;
    final state = events.state.value;
    final duration = state.duration;
    if (duration.inMilliseconds <= 0) {
      _stopLongPressSeek(animateHide: false);
      return;
    }
    final step = widget.longPressSeek;
    if (step.inMilliseconds <= 0) return;
    final base = _longPressTarget ?? state.position;
    final delta = _longPressDirection < 0 ? -step : step;
    final target = _clampDuration(base + delta, Duration.zero, duration);
    final actual = target - base;
    if (actual.inMilliseconds == 0) {
      final label = '${_longPressDirection < 0 ? '-' : '+'}${_formatSeekValue(_longPressAccumulated)}s';
      _showSeekFlash(label, _longPressDirection < 0 ? Alignment.centerLeft : Alignment.centerRight);
      return;
    }
    _longPressTarget = target;
    widget.controller.seekTo(target);
    _longPressAccumulated += _absDuration(actual);
    final label = '${_longPressDirection < 0 ? '-' : '+'}${_formatSeekValue(_longPressAccumulated)}s';
    _showSeekFlash(label, _longPressDirection < 0 ? Alignment.centerLeft : Alignment.centerRight);
  }

  /// Останавливает перемотку при длительном нажатии
  void _stopLongPressSeek({bool animateHide = true}) {
    final direction = _longPressDirection;
    final accumulated = _longPressAccumulated;
    _seekRepeat?.cancel();
    _seekRepeat = null;
    _longPressTarget = null;
    _longPressDirection = 0;
    _longPressAccumulated = Duration.zero;
    if (!animateHide) {
      _hideSeekFlash();
      _restartHide();
      return;
    }
    if (accumulated.inMilliseconds <= 0) {
      _hideSeekFlash();
      _restartHide();
      return;
    }
    final label = '${direction < 0 ? '-' : '+'}${_formatSeekValue(accumulated)}s';
    _showSeekFlash(
      label,
      direction < 0 ? Alignment.centerLeft : Alignment.centerRight,
      hideAfter: const Duration(milliseconds: 600),
    );
    _restartHide();
  }

  /// Ограничивает значение продолжительности в заданном диапазоне
  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Возвращает абсолютное значение продолжительности
  Duration _absDuration(Duration value) {
    return value.isNegative ? -value : value;
  }

  /// Форматирует значение перемотки для отображения
  String _formatSeekValue(Duration value) {
    final ms = value.inMilliseconds.abs();
    if (ms == 0) return '0';
    if (ms % 1000 == 0) {
      return (ms ~/ 1000).toString();
    }
    final seconds = ms / 1000;
    final fixed = seconds.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  /// Обновляет список доступных видео дорожек
  void _refreshVideoTracks({bool force = false}) {
    if (!force && _pendingTrackFetch != null) return;
    final ticket = ++_trackFetchTicket;
    _pendingTrackFetch = widget.controller
        .getVideoTracks()
        .then((tracks) {
          if (!mounted || _trackFetchTicket != ticket) return;
          setState(() {
            _videoTracks = tracks;
            if (_manualTrackId != null && tracks.every((t) => t.id != _manualTrackId)) {
              _manualTrackId = null;
            }
          });
        })
        .catchError((_) {})
        .whenComplete(() {
          if (_trackFetchTicket == ticket) {
            _pendingTrackFetch = null;
          }
        });
  }

  /// Обновляет список доступных аудио дорожек
  void _refreshAudioTracks({bool force = false}) {
    if (!force && _pendingAudioFetch != null) return;
    final ticket = ++_audioFetchTicket;
    _pendingAudioFetch = widget.controller
        .getAudioTracks()
        .then((tracks) {
          if (!mounted || _audioFetchTicket != ticket) return;
          setState(() {
            _audioTracks = tracks;
            if (_manualAudioId != null && tracks.every((t) => t.id != _manualAudioId)) {
              _manualAudioId = null;
            }
          });
        })
        .catchError((_) {})
        .whenComplete(() {
          if (_audioFetchTicket == ticket) {
            _pendingAudioFetch = null;
          }
        });
  }

  /// Обновляет список доступных субтитров
  void _refreshSubtitleTracks({bool force = false}) {
    if (!force && _pendingSubtitleFetch != null) return;
    final ticket = ++_subtitleFetchTicket;
    _pendingSubtitleFetch = widget.controller
        .getSubtitleTracks()
        .then((tracks) {
          if (!mounted || _subtitleFetchTicket != ticket) return;
          setState(() {
            _subtitleTracks = tracks;
            if (_manualSubtitleId != null && tracks.every((t) => t.id != _manualSubtitleId)) {
              _manualSubtitleId = null;
            }
          });
        })
        .catchError((_) {})
        .whenComplete(() {
          if (_subtitleFetchTicket == ticket) {
            _pendingSubtitleFetch = null;
          }
        });
  }

  /// Проверяет необходимость загрузки дорожек
  void _ensureTracksLoaded(RhsPlaybackState st) {
    if (st.isBuffering && st.duration == Duration.zero) return;
    if (_videoTracks.isEmpty) _refreshVideoTracks();
    if (_audioTracks.isEmpty) _refreshAudioTracks();
    if (_subtitleTracks.isEmpty) _refreshSubtitleTracks();
  }

  /// Обрабатывает выбор качества видео
  Future<void> _onQualitySelected(String value) async {
    switch (value) {
      case 'auto':
        setState(() {
          _dataSaver = false;
          _manualTrackId = null;
        });
        await widget.controller.setDataSaver(false);
        await widget.controller.clearVideoTrackSelection();
        break;
      case 'dataSaver':
        setState(() {
          _dataSaver = true;
          _manualTrackId = null;
        });
        await widget.controller.setDataSaver(true);
        await widget.controller.clearVideoTrackSelection();
        break;
      default:
        setState(() {
          _dataSaver = false;
          _manualTrackId = value;
        });
        await widget.controller.setDataSaver(false);
        await widget.controller.selectVideoTrack(value);
        break;
    }
    _restartHide();
    if (!mounted) return;
    _refreshVideoTracks(force: true);
  }

  // Вспомогательные геттеры и билдеры для дорожек/качества теперь живут
  // в отдельном компоненте RhsModernPlayerControls.

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RhsPlaybackState>(
      valueListenable:
          _events?.state ??
          ValueNotifier(
            const RhsPlaybackState(
              position: Duration.zero,
              duration: Duration.zero,
              isPlaying: false,
              isBuffering: true,
            ),
          ),
      builder: (_, st, __) {
        if (widget.onStateChanged != null && _hasStateChanged(st)) {
          widget.onStateChanged!(st);
          _lastStateNotification = st;
        }
        final currentError = _events?.error.value;
        if (widget.onError != null && currentError != _lastErrorNotification) {
          widget.onError!(currentError);
          _lastErrorNotification = currentError;
        }
        _ensureTracksLoaded(st);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_locked) {
              _lockHint = true;
              _lockHintTimer?.cancel();
              _lockHintTimer = Timer(const Duration(seconds: 2), () {
                if (!mounted) return;
                setState(() => _lockHint = false);
              });
              setState(() {});
              return;
            }
            setState(() => _showControls = !_showControls);
            if (_showControls) _restartHide();
          },
          onDoubleTapDown: (d) {
            if (_locked) {
              return;
            }
            final w = context.size?.width ?? 0;
            final x = d.localPosition.dx;
            final left = x < w / 3;
            final right = x > 2 * w / 3;
            if (left || right) {
              final delta = left ? -widget.doubleTapSeek : widget.doubleTapSeek;
              final t = st.position + delta;
              final target = t < Duration.zero ? Duration.zero : (t > st.duration ? st.duration : t);
              _stopLongPressSeek(animateHide: false);
              widget.controller.seekTo(target);
              final text = "${delta.isNegative ? '-' : '+'}${_formatSeekValue(widget.doubleTapSeek)}s";
              _showSeekFlash(
                text,
                left ? Alignment.centerLeft : Alignment.centerRight,
                hideAfter: const Duration(milliseconds: 600),
              );
            } else {
              st.isPlaying ? widget.controller.pause() : widget.controller.play();
            }
            _restartHide();
          },
          onHorizontalDragStart: (d) {
            if (_locked) {
              return;
            }
            _hStart = d.localPosition;
            _preview = st.position;
          },
          onHorizontalDragUpdate: (d) {
            if (_locked) {
              return;
            }
            final start = _hStart;
            if (start == null) return;
            final diff = d.localPosition.dx - start.dx;
            final newPos = (_preview ?? st.position) + Duration(milliseconds: (diff * 50).toInt());
            final clamped = newPos < Duration.zero ? Duration.zero : (newPos > st.duration ? st.duration : newPos);
            setState(() => _preview = clamped);
          },
          onHorizontalDragEnd: (_) {
            if (_locked) {
              return;
            }
            if (_preview != null) {
              widget.controller.seekTo(_preview!);
              setState(() => _preview = null);
            }
          },
          onLongPressStart: (details) {
            if (_locked) return;
            if (st.duration.inMilliseconds <= 0) return;
            final width = context.size?.width ?? 0;
            final forward = details.localPosition.dx > width / 2;
            _startLongPressSeek(forward: forward);
          },
          onLongPressMoveUpdate: (details) {
            if (_locked || _seekRepeat == null) return;
            final width = context.size?.width ?? 0;
            final forward = details.localPosition.dx > width / 2;
            _updateLongPressDirection(forward: forward);
          },
          onLongPressEnd: (_) {
            if (_locked) return;
            _stopLongPressSeek();
          },
          onLongPressCancel: () {
            _stopLongPressSeek(animateHide: false);
          },
          onVerticalDragUpdate: (d) async {
            if (_locked) {
              return;
            }
            final w = context.size?.width ?? 0;
            final right = d.localPosition.dx > w / 2;
            final delta = -d.delta.dy / 200; // up increase
            if (right) {
              setState(() {
                _showVol = true;
                _volLevel = (_volLevel + delta).clamp(0.0, 1.0);
              });
              unawaited(
                NativeBridge.setVolume(delta)
                    .then((value) {
                      if (!mounted) return;
                      setState(() => _volLevel = value);
                    })
                    .catchError((_) {}),
              );
            } else {
              setState(() {
                _showBri = true;
                _briLevel = (_briLevel + delta).clamp(0.0, 1.0);
              });
              unawaited(
                NativeBridge.setBrightness(delta)
                    .then((value) {
                      if (!mounted) return;
                      setState(() => _briLevel = value);
                    })
                    .catchError((_) {}),
              );
            }
            _vbHide?.cancel();
            _vbHide = Timer(const Duration(milliseconds: 800), () {
              if (!mounted) return;
              setState(() {
                _showVol = false;
                _showBri = false;
              });
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder<BoxFit>(
                valueListenable: _fit,
                builder: (_, fit, __) => RhsNativePlayerView(controller: widget.controller, boxFit: fit, overlay: null),
              ),
              // Верхний прозрачный слой взаимодействия для обеспечения обнаружения нажатий в любом месте
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (_locked) {
                      _lockHint = true;
                      _lockHintTimer?.cancel();
                      _lockHintTimer = Timer(const Duration(seconds: 2), () {
                        if (!mounted) return;
                        setState(() => _lockHint = false);
                      });
                      setState(() {});
                      return;
                    }
                    setState(() => _showControls = !_showControls);
                    if (_showControls) _restartHide();
                  },
                  onDoubleTapDown: (d) {
                    if (_locked) {
                      return;
                    }
                    final box = context.findRenderObject() as RenderBox?;
                    final w = box?.size.width ?? 0;
                    final x = d.localPosition.dx;
                    final left = x < w / 3;
                    final right = x > 2 * w / 3;
                    final st =
                        _events?.state.value ??
                        const RhsPlaybackState(
                          position: Duration.zero,
                          duration: Duration.zero,
                          isPlaying: false,
                          isBuffering: false,
                        );
                    if (left || right) {
                      final delta = left ? -widget.doubleTapSeek : widget.doubleTapSeek;
                      final t = st.position + delta;
                      final target = t < Duration.zero ? Duration.zero : (t > st.duration ? st.duration : t);
                      _stopLongPressSeek(animateHide: false);
                      widget.controller.seekTo(target);
                      final text = "${delta.isNegative ? '-' : '+'}${_formatSeekValue(widget.doubleTapSeek)}s";
                      _showSeekFlash(
                        text,
                        left ? Alignment.centerLeft : Alignment.centerRight,
                        hideAfter: const Duration(milliseconds: 600),
                      );
                    } else {
                      st.isPlaying ? widget.controller.pause() : widget.controller.play();
                    }
                    _restartHide();
                  },
                  onHorizontalDragStart: (d) {
                    if (_locked) {
                      return;
                    }
                    final st =
                        _events?.state.value ??
                        const RhsPlaybackState(
                          position: Duration.zero,
                          duration: Duration.zero,
                          isPlaying: false,
                          isBuffering: false,
                        );
                    _hStart = d.localPosition;
                    _preview = st.position;
                  },
                  onHorizontalDragUpdate: (d) {
                    if (_locked) {
                      return;
                    }
                    final st =
                        _events?.state.value ??
                        const RhsPlaybackState(
                          position: Duration.zero,
                          duration: Duration.zero,
                          isPlaying: false,
                          isBuffering: false,
                        );
                    final start = _hStart;
                    if (start == null) return;
                    final diff = d.localPosition.dx - start.dx;
                    final newPos = (_preview ?? st.position) + Duration(milliseconds: (diff * 50).toInt());
                    final clamped = newPos < Duration.zero
                        ? Duration.zero
                        : (newPos > st.duration ? st.duration : newPos);
                    setState(() => _preview = clamped);
                  },
                  onHorizontalDragEnd: (_) {
                    if (_locked) {
                      return;
                    }
                    if (_preview != null) {
                      widget.controller.seekTo(_preview!);
                      setState(() => _preview = null);
                    }
                  },
                  onLongPressStart: (details) {
                    if (_locked) return;
                    final st = _events?.state.value;
                    if (st == null || st.duration.inMilliseconds <= 0) return;
                    final box = context.findRenderObject() as RenderBox?;
                    final width = box?.size.width ?? 0;
                    final forward = details.localPosition.dx > width / 2;
                    _startLongPressSeek(forward: forward);
                  },
                  onLongPressMoveUpdate: (details) {
                    if (_locked || _seekRepeat == null) return;
                    final box = context.findRenderObject() as RenderBox?;
                    final width = box?.size.width ?? 0;
                    final forward = details.localPosition.dx > width / 2;
                    _updateLongPressDirection(forward: forward);
                  },
                  onLongPressEnd: (_) {
                    if (_locked) return;
                    _stopLongPressSeek();
                  },
                  onLongPressCancel: () {
                    _stopLongPressSeek(animateHide: false);
                  },
                  onVerticalDragUpdate: (d) async {
                    if (_locked) {
                      return;
                    }
                    final box = context.findRenderObject() as RenderBox?;
                    final w = box?.size.width ?? 0;
                    final right = d.localPosition.dx > w / 2;
                    final delta = -d.delta.dy / 200; // up increase
                    if (right) {
                      setState(() {
                        _showVol = true;
                        _volLevel = (_volLevel + delta).clamp(0.0, 1.0);
                      });
                      unawaited(
                        NativeBridge.setVolume(delta)
                            .then((value) {
                              if (!mounted) return;
                              setState(() => _volLevel = value);
                            })
                            .catchError((_) {}),
                      );
                    } else {
                      setState(() {
                        _showBri = true;
                        _briLevel = (_briLevel + delta).clamp(0.0, 1.0);
                      });
                      unawaited(
                        NativeBridge.setBrightness(delta)
                            .then((value) {
                              if (!mounted) return;
                              setState(() => _briLevel = value);
                            })
                            .catchError((_) {}),
                      );
                    }
                    _vbHide?.cancel();
                    _vbHide = Timer(const Duration(milliseconds: 800), () {
                      if (!mounted) return;
                      setState(() {
                        _showVol = false;
                        _showBri = false;
                      });
                    });
                  },
                ),
              ),
              if (widget.overlay != null)
                Positioned(top: 12, right: 12, child: IgnorePointer(ignoring: false, child: widget.overlay!)),
              if (_preview != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_thumbs != null && _thumbs!.isNotEmpty) _buildThumbFor(_preview!),
                        const SizedBox(height: 4),
                        Text(_fmt(_preview!), style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              if (st.isBuffering)
                const Center(
                  child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: Colors.white)),
                ),
              if (_showControls)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: RhsModernPlayerControls(
                    state: st,
                    isFullscreen: widget.isFullscreen,
                    isLocked: _locked,
                    circleControlSize: _circleControlSize,
                    currentSpeed: _currentSpeed,
                    dataSaver: _dataSaver,
                    manualVideoTrackId: _manualTrackId,
                    manualAudioTrackId: _manualAudioId,
                    manualSubtitleTrackId: _manualSubtitleId,
                    videoTracks: _videoTracks,
                    audioTracks: _audioTracks,
                    subtitleTracks: _subtitleTracks,
                    hasPendingVideoTracks: _pendingTrackFetch != null,
                    hasPendingAudioTracks: _pendingAudioFetch != null,
                    hasPendingSubtitleTracks: _pendingSubtitleFetch != null,
                    boxFitNotifier: _fit,
                    onPlayPause: () {
                      st.isPlaying ? widget.controller.pause() : widget.controller.play();
                      _restartHide();
                    },
                    onSeekRelative: (offset) => _seekRelative(st, offset),
                    onLockControls: () {
                      setState(() {
                        _locked = true;
                        _showControls = false;
                      });
                    },
                    onEnterPip: () {
                      unawaited(
                        widget.controller
                            .enterPictureInPicture()
                            .then((ok) {
                              if (!mounted) return;
                              if (ok) {
                                _restartHide();
                              } else {
                                debugPrint('Picture-in-picture is unavailable.');
                              }
                            })
                            .catchError((_) {}),
                      );
                    },
                    onToggleFullscreen: () {
                      if (widget.isFullscreen) {
                        widget.onFullscreenChanged?.call(false);
                      } else {
                        _enterFullscreen();
                      }
                    },
                    onOpenVideoMenu: () => _refreshVideoTracks(force: true),
                    onOpenAudioMenu: () => _refreshAudioTracks(force: true),
                    onOpenSubtitleMenu: () => _refreshSubtitleTracks(force: true),
                    onSelectQuality: (value) => _onQualitySelected(value),
                    onSelectAudioTrack: (value) {
                      if (value == null) {
                        setState(() => _manualAudioId = null);
                        unawaited(widget.controller.selectAudioTrack(null));
                      } else {
                        setState(() => _manualAudioId = value);
                        unawaited(widget.controller.selectAudioTrack(value));
                      }
                      _restartHide();
                    },
                    onSelectSubtitleTrack: (value) {
                      if (value == null) {
                        setState(() => _manualSubtitleId = null);
                        unawaited(widget.controller.selectSubtitleTrack(null));
                      } else {
                        setState(() => _manualSubtitleId = value);
                        unawaited(widget.controller.selectSubtitleTrack(value));
                      }
                      _restartHide();
                    },
                    onSpeedBoostStart: _handleSpeedBoostStart,
                    onSpeedBoostEnd: _handleSpeedBoostEnd,
                    onSetUserSpeed: (speed) => _setUserSpeed(speed),
                    onChangeBoxFit: (fit) async {
                      _fit.value = fit;
                      await widget.controller.setBoxFit(fit);
                      if (!mounted) return;
                      _restartHide();
                    },
                  ),
                ),
              if (_seekFlash != null)
                Align(
                  alignment: _seekFlashAlign,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: Text(_seekFlash!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  ),
                ),
              if (_locked || _lockHint)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.black54,
                    onPressed: () {
                      setState(() {
                        _locked = false;
                        _lockHint = false;
                      });
                      _restartHide();
                    },
                    child: const Icon(Icons.lock_open, color: Colors.white),
                  ),
                ),
              if (_showVol)
                Positioned(
                  right: 12,
                  top: 24,
                  bottom: 24,
                  child: RhsVerticalSlider(value: _volLevel, icon: Icons.volume_up),
                ),
              if (_showBri)
                Positioned(
                  left: 12,
                  top: 24,
                  bottom: 24,
                  child: RhsVerticalSlider(value: _briLevel, icon: Icons.brightness_6),
                ),
              // Оверлей ошибки (повтор) поверх всего
              if (_events?.error.value != null)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white70, size: 36),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            _events!.error.value ?? 'Playback error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            widget.controller.retry();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Выполняет относительную перемотку
  void _seekRelative(RhsPlaybackState st, Duration offset) {
    final current = _events?.state.value ?? st;
    final durationMs = current.duration.inMilliseconds;
    if (durationMs <= 0) return;
    final targetMs = (current.position + offset).inMilliseconds;
    final clamped = targetMs.clamp(0, durationMs).toInt();
    widget.controller.seekTo(Duration(milliseconds: clamped));
    _restartHide();
  }

  /// Начинает ускоренное воспроизведение
  void _handleSpeedBoostStart() {
    if (_speedBeforeBoost != null) return;
    _speedBeforeBoost = _currentSpeed;
    setState(() => _currentSpeed = 2.0);
    unawaited(widget.controller.setSpeed(2.0));
    _restartHide();
  }

  /// Завершает ускоренное воспроизведение
  void _handleSpeedBoostEnd() {
    final previous = _speedBeforeBoost;
    if (previous == null) return;
    _speedBeforeBoost = null;
    setState(() => _currentSpeed = previous);
    unawaited(widget.controller.setSpeed(previous));
    _restartHide();
  }

  /// Устанавливает пользовательскую скорость воспроизведения
  Future<void> _setUserSpeed(double speed) async {
    _speedBeforeBoost = null;
    setState(() => _currentSpeed = speed);
    await widget.controller.setSpeed(speed);
    if (!mounted) return;
    _restartHide();
  }

  /// Форматирует продолжительность для отображения
  String _fmt(Duration d) {
    if (d.inHours > 0) {
      final h = d.inHours.toString().padLeft(2, '0');
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Создает миниатюру для предварительного просмотра
  Widget _buildThumbFor(Duration d) {
    final cues = _thumbs;
    if (cues == null || cues.isEmpty) return const SizedBox.shrink();
    ThumbCue? cue;
    for (final c in cues) {
      if (d >= c.start && d < c.end) {
        cue = c;
        break;
      }
    }
    cue ??= cues.last;
    final uri = cue.image.toString();
    final crop = cue.hasCrop
        ? Rect.fromLTWH((cue.x!).toDouble(), (cue.y!).toDouble(), (cue.w!).toDouble(), (cue.h!).toDouble())
        : null;
    const targetW = 160.0;
    if (crop == null) {
      return Image.network(uri, width: targetW, fit: BoxFit.cover, headers: _thumbHeaders);
    }
    final scale = targetW / crop.width;
    return ClipRect(
      child: SizedBox(
        width: targetW,
        height: crop.height * scale,
        child: FittedBox(
          fit: BoxFit.none,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(-crop.left, -crop.top),
            child: Image.network(uri, headers: _thumbHeaders),
          ),
        ),
      ),
    );
  }
}

/// Нижняя панель элементов управления современного плеера.
class _PlayerControls extends StatelessWidget {
  final RhsPlaybackState state;
  final bool isFullscreen;
  final bool isLocked;
  final double circleControlSize;
  final double currentSpeed;
  final bool dataSaver;
  final String? manualVideoTrackId;
  final String? manualAudioTrackId;
  final String? manualSubtitleTrackId;
  final List<RhsVideoTrack> videoTracks;
  final List<RhsAudioTrack> audioTracks;
  final List<RhsSubtitleTrack> subtitleTracks;
  final bool hasPendingVideoTracks;
  final bool hasPendingAudioTracks;
  final bool hasPendingSubtitleTracks;
  final ValueNotifier<BoxFit> boxFitNotifier;
  final VoidCallback onPlayPause;
  final void Function(Duration offset) onSeekRelative;
  final VoidCallback onLockControls;
  final VoidCallback onEnterPip;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onOpenVideoMenu;
  final VoidCallback onOpenAudioMenu;
  final VoidCallback onOpenSubtitleMenu;
  final Future<void> Function(String value) onSelectQuality;
  final void Function(String? value) onSelectAudioTrack;
  final void Function(String? value) onSelectSubtitleTrack;
  final VoidCallback onSpeedBoostStart;
  final VoidCallback onSpeedBoostEnd;
  final Future<void> Function(double speed) onSetUserSpeed;
  final Future<void> Function(BoxFit fit) onChangeBoxFit;

  const _PlayerControls({
    required this.state,
    required this.isFullscreen,
    required this.isLocked,
    required this.circleControlSize,
    required this.currentSpeed,
    required this.dataSaver,
    required this.manualVideoTrackId,
    required this.manualAudioTrackId,
    required this.manualSubtitleTrackId,
    required this.videoTracks,
    required this.audioTracks,
    required this.subtitleTracks,
    required this.hasPendingVideoTracks,
    required this.hasPendingAudioTracks,
    required this.hasPendingSubtitleTracks,
    required this.boxFitNotifier,
    required this.onPlayPause,
    required this.onSeekRelative,
    required this.onLockControls,
    required this.onEnterPip,
    required this.onToggleFullscreen,
    required this.onOpenVideoMenu,
    required this.onOpenAudioMenu,
    required this.onOpenSubtitleMenu,
    required this.onSelectQuality,
    required this.onSelectAudioTrack,
    required this.onSelectSubtitleTrack,
    required this.onSpeedBoostStart,
    required this.onSpeedBoostEnd,
    required this.onSetUserSpeed,
    required this.onChangeBoxFit,
  });

  static const double _dialogCornerRadius = 5;

  static const List<BoxFit> _boxFitChoices = <BoxFit>[
    BoxFit.contain,
    BoxFit.cover,
    BoxFit.fill,
    BoxFit.fitWidth,
    BoxFit.fitHeight,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isShortHeight = constraints.maxHeight < 230;
        final circleSize = isShortHeight ? 44.0 : circleControlSize;
        final playDiameter = isShortHeight ? 60.0 : 70.0;
        final circleSpacing = isShortHeight ? 12.0 : 16.0;
        final verticalGap = isShortHeight ? 12.0 : 18.0;
        final circleControls = _buildCircleControls(context, circleSize);

        return Container(
          color: Colors.transparent,
          padding: EdgeInsets.fromLTRB(16, isShortHeight ? 10 : 14, 16, isShortHeight ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (circleControls.isNotEmpty)
                Align(
                  alignment: Alignment.topLeft,
                  child: Wrap(spacing: circleSpacing, runSpacing: circleSpacing, children: circleControls),
                ),
              if (circleControls.isNotEmpty) SizedBox(height: verticalGap),
              const Spacer(),
              _buildProgressRow(context),
              _buildTransportRow(context, circleSize, playDiameter, isShortHeight),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressRow(BuildContext context) {
    return Row(
      children: [
        Text(_fmt(state.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
            ),
            child: Slider(
              min: 0,
              max: state.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
              value: state.position.inMilliseconds.clamp(0, state.duration.inMilliseconds).toDouble(),
              onChanged: (_) {},
              onChangeEnd: (v) => onSeekRelative(Duration(milliseconds: v.toInt())),
            ),
          ),
        ),
        Text(_fmt(state.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  List<Widget> _buildCircleControls(BuildContext context, double circleSize) {
    return <Widget>[
      _buildQualityButton(context, circleSize),
      _buildSpeedButton(circleSize),
      _buildAudioButton(context, circleSize),
      _buildSubtitleButton(context, circleSize),
      _buildResizeButton(context, circleSize),
    ];
  }

  Widget _buildTransportRow(BuildContext context, double circleSize, double playDiameter, bool isShortHeight) {
    final skipBack = _buildSeekButton(-const Duration(seconds: 10), circleSize);
    final skipForward = _buildSeekButton(const Duration(seconds: 10), circleSize);
    final centerGap = isShortHeight ? 16.0 : 20.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildLockButton(circleSize),
        SizedBox(width: isShortHeight ? 8 : 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              skipBack,
              SizedBox(width: centerGap),
              _buildPlayPauseButton(diameter: playDiameter),
              SizedBox(width: centerGap),
              skipForward,
            ],
          ),
        ),
        SizedBox(width: isShortHeight ? 8 : 12),
        _buildPipButton(circleSize),
        const SizedBox(width: 8),
        _buildFullscreenButton(circleSize),
      ],
    );
  }

  Widget _buildPlayPauseButton({double? diameter}) {
    final icon = state.isPlaying ? Icons.pause : Icons.play_arrow;
    final overlayOpacity = state.isPlaying ? 0.35 : 0.22;
    final size = diameter ?? 68.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPlayPause,
      onLongPressStart: (_) => onSpeedBoostStart(),
      onLongPressEnd: (_) => onSpeedBoostEnd(),
      onLongPressCancel: onSpeedBoostEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(color: Color.fromRGBO(255, 255, 255, overlayOpacity), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }

  Widget _buildSeekButton(Duration offset, double circleSize) {
    final isForward = offset.inMilliseconds > 0;
    final seconds = offset.inSeconds.abs();
    final icon = _seekIconFor(seconds, isForward);
    Widget child;
    if (icon != null) {
      child = Icon(icon, color: Colors.white, size: 26);
    } else {
      final sign = isForward ? '+' : '-';
      child = Text(
        '$sign${seconds}s',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      );
    }
    return _circleTapButton(
      tooltip: isForward ? 'Forward $seconds s' : 'Rewind $seconds s',
      onTap: () => onSeekRelative(offset),
      child: child,
      size: circleSize,
    );
  }

  IconData? _seekIconFor(int seconds, bool isForward) {
    if (seconds == 5) {
      return isForward ? Icons.forward_5 : Icons.replay_5;
    }
    if (seconds == 10) {
      return isForward ? Icons.forward_10 : Icons.replay_10;
    }
    if (seconds == 30) {
      return isForward ? Icons.forward_30 : Icons.replay_30;
    }
    return null;
  }

  Widget _buildQualityButton(BuildContext context, double circleSize) {
    return PopupMenuButton<String>(
      tooltip: 'Quality',
      color: const Color(0xFF1F1F1F),
      surfaceTintColor: Colors.transparent,
      padding: EdgeInsets.zero,
      onOpened: onOpenVideoMenu,
      onSelected: (v) => onSelectQuality(v),
      itemBuilder: _qualityPopupItems,
      child: _circleShell(Icon(_qualityIcon, color: Colors.white), size: circleSize),
    );
  }

  Widget _buildAudioButton(BuildContext context, double circleSize) {
    return PopupMenuButton<String>(
      tooltip: 'Audio',
      color: const Color(0xFF1F1F1F),
      surfaceTintColor: Colors.transparent,
      padding: EdgeInsets.zero,
      onOpened: onOpenAudioMenu,
      onSelected: (value) {
        if (value == '__auto__') {
          onSelectAudioTrack(null);
        } else {
          onSelectAudioTrack(value);
        }
      },
      itemBuilder: _audioPopupItems,
      child: _circleShell(const Icon(Icons.audiotrack, color: Colors.white), size: circleSize),
    );
  }

  Widget _buildSubtitleButton(BuildContext context, double circleSize) {
    return PopupMenuButton<String>(
      tooltip: 'Subtitles',
      color: const Color(0xFF1F1F1F),
      surfaceTintColor: Colors.transparent,
      padding: EdgeInsets.zero,
      onOpened: onOpenSubtitleMenu,
      onSelected: (value) {
        if (value == '__off__') {
          onSelectSubtitleTrack(null);
        } else {
          onSelectSubtitleTrack(value);
        }
      },
      itemBuilder: _subtitlePopupItems,
      child: _circleShell(const Icon(Icons.subtitles, color: Colors.white), size: circleSize),
    );
  }

  Widget _buildLockButton(double circleSize) {
    return _circleTapButton(
      tooltip: 'Lock controls',
      child: const Icon(Icons.lock, color: Colors.white),
      onTap: onLockControls,
      size: circleSize,
    );
  }

  Widget _buildSpeedButton(double circleSize) {
    return PopupMenuButton<double>(
      tooltip: 'Speed',
      padding: EdgeInsets.zero,
      onSelected: (s) => onSetUserSpeed(s),
      itemBuilder: _speedPopupItems,
      child: _circleShell(
        Text(
          _speedBadge,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.4),
        ),
        size: circleSize,
      ),
    );
  }

  Widget _buildResizeButton(BuildContext context, double circleSize) {
    return _circleTapButton(
      tooltip: 'Resize',
      child: const Icon(Icons.aspect_ratio, color: Colors.white),
      onTap: () async {
        final fit = await _showBoxFitDialog(context);
        if (fit == null) return;
        await onChangeBoxFit(fit);
      },
      size: circleSize,
    );
  }

  Widget _buildPipButton(double circleSize) {
    return _circleTapButton(
      tooltip: 'Picture-in-picture',
      child: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
      onTap: onEnterPip,
      size: circleSize,
    );
  }

  Widget _buildFullscreenButton(double circleSize) {
    final icon = isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen;
    return _circleTapButton(
      tooltip: isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
      child: Icon(icon, color: Colors.white),
      onTap: onToggleFullscreen,
      size: circleSize,
    );
  }

  List<PopupMenuEntry<String>> _qualityPopupItems(BuildContext context) {
    final items = <PopupMenuEntry<String>>[];
    final current = _activeTrack;
    final autoSubtitle = !dataSaver && current != null && manualVideoTrackId == null
        ? 'Current: ${current.displayLabel}'
        : null;
    items.add(
      PopupMenuItem(
        value: 'auto',
        child: _qualityMenuRow(
          context,
          label: 'Auto',
          subtitle: autoSubtitle,
          selected: !dataSaver && manualVideoTrackId == null,
        ),
      ),
    );
    items.add(
      PopupMenuItem(
        value: 'dataSaver',
        child: _qualityMenuRow(context, label: 'Data Saver', subtitle: 'Cap ~0.8 Mbps', selected: dataSaver),
      ),
    );
    if (videoTracks.isNotEmpty) {
      final sorted = [...videoTracks]..sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));
      items.add(const PopupMenuDivider());
      for (final track in sorted) {
        items.add(
          PopupMenuItem(
            value: track.id,
            child: _qualityMenuRow(
              context,
              label: track.displayLabel,
              selected: manualVideoTrackId == track.id,
              isPlaying: track.selected,
            ),
          ),
        );
      }
    } else if (hasPendingVideoTracks) {
      items.add(const PopupMenuItem<String>(enabled: false, value: '__loading__', child: Text('Loading variants...')));
    } else {
      items.add(const PopupMenuItem<String>(enabled: false, value: '__empty__', child: Text('No variants reported')));
    }
    return items;
  }

  List<PopupMenuEntry<String>> _audioPopupItems(BuildContext context) {
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem(
        value: '__auto__',
        child: _qualityMenuRow(context, label: 'Auto', subtitle: 'Default audio', selected: manualAudioTrackId == null),
      ),
    ];
    if (audioTracks.isNotEmpty) {
      items.add(const PopupMenuDivider());
      for (final track in audioTracks) {
        items.add(
          PopupMenuItem(
            value: track.id,
            child: _qualityMenuRow(
              context,
              label: track.label ?? (track.language ?? track.id),
              subtitle: track.language,
              selected: manualAudioTrackId == track.id || (manualAudioTrackId == null && track.selected),
              isPlaying: track.selected,
            ),
          ),
        );
      }
    } else if (hasPendingAudioTracks) {
      items.add(
        const PopupMenuItem<String>(enabled: false, value: '__loading_audio__', child: Text('Loading audio tracks...')),
      );
    }
    return items;
  }

  List<PopupMenuEntry<String>> _subtitlePopupItems(BuildContext context) {
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem(
        value: '__off__',
        child: _qualityMenuRow(context, label: 'Subtitles off', selected: manualSubtitleTrackId == null),
      ),
    ];
    if (subtitleTracks.isNotEmpty) {
      items.add(const PopupMenuDivider());
      for (final track in subtitleTracks) {
        items.add(
          PopupMenuItem(
            value: track.id,
            child: _qualityMenuRow(
              context,
              label: track.label ?? (track.language ?? track.id),
              subtitle: track.language,
              selected: manualSubtitleTrackId == track.id || (manualSubtitleTrackId == null && track.selected),
              isPlaying: track.selected,
            ),
          ),
        );
      }
    } else if (hasPendingSubtitleTracks) {
      items.add(
        const PopupMenuItem<String>(enabled: false, value: '__loading_sub__', child: Text('Loading subtitles...')),
      );
    }
    return items;
  }

  List<PopupMenuEntry<double>> _speedPopupItems(BuildContext context) {
    const speeds = <double>[0.5, 1.0, 1.25, 1.5, 2.0];
    return speeds
        .map(
          (speed) => PopupMenuItem<double>(
            value: speed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  child: (speed - currentSpeed).abs() < 0.01
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
                Text(_formatSpeed(speed)),
              ],
            ),
          ),
        )
        .toList();
  }

  Future<BoxFit?> _showBoxFitDialog(BuildContext context) {
    final current = boxFitNotifier.value;
    return showDialog<BoxFit>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F1F1F),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_dialogCornerRadius)),
          title: const Text('Resize', style: TextStyle(color: Colors.white)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _boxFitChoices.map((fit) {
                final isSelected = fit == current;
                final label = _boxFitLabel(fit);
                final icon = _boxFitIcon(fit);
                final borderColor = isSelected ? Colors.white : Colors.white24;
                final background = isSelected
                    ? const Color.fromRGBO(255, 255, 255, 0.18)
                    : const Color.fromRGBO(255, 255, 255, 0.04);
                return SizedBox(
                  width: 88,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(_dialogCornerRadius),
                      onTap: () => Navigator.of(dialogContext).pop(fit),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(_dialogCornerRadius),
                          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: Colors.white, size: 26),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _boxFitLabel(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'Contain';
      case BoxFit.cover:
        return 'Cover';
      case BoxFit.fill:
        return 'Fill';
      case BoxFit.fitWidth:
        return 'Fit Width';
      case BoxFit.fitHeight:
        return 'Fit Height';
      case BoxFit.none:
        return 'None';
      case BoxFit.scaleDown:
        return 'Scale Down';
    }
  }

  IconData _boxFitIcon(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return Icons.fit_screen;
      case BoxFit.cover:
        return Icons.crop_original;
      case BoxFit.fill:
        return Icons.aspect_ratio;
      case BoxFit.fitWidth:
        return Icons.swap_horiz;
      case BoxFit.fitHeight:
        return Icons.swap_vert;
      case BoxFit.none:
        return Icons.crop_free;
      case BoxFit.scaleDown:
        return Icons.compress;
    }
  }

  IconData get _qualityIcon {
    if (dataSaver) return Icons.data_saver_on;
    if (manualVideoTrackId != null) return Icons.high_quality;
    return Icons.hd;
  }

  RhsVideoTrack? get _activeTrack {
    for (final t in videoTracks) {
      if (t.selected) return t;
    }
    return null;
  }

  String get _speedBadge {
    return _formatSpeed(currentSpeed, uppercase: true);
  }

  String _formatSpeed(double speed, {bool uppercase = false}) {
    final suffix = uppercase ? 'X' : 'x';
    if ((speed - speed.roundToDouble()).abs() < 0.01) {
      return '${speed.toInt()}$suffix';
    }
    if ((speed * 10).roundToDouble() == speed * 10) {
      return '${speed.toStringAsFixed(1)}$suffix';
    }
    return '${speed.toStringAsFixed(2)}$suffix';
  }

  Widget _circleShell(Widget child, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _circleTapButton({required Widget child, String? tooltip, VoidCallback? onTap, required double size}) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2),
        onTap: onTap,
        child: _circleShell(child, size: size),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }

  Widget _qualityMenuRow(
    BuildContext context, {
    required String label,
    bool selected = false,
    String? subtitle,
    bool isPlaying = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.labelLarge?.copyWith(color: Colors.white);
    final subStyle = textTheme.bodySmall?.copyWith(color: Colors.white70);
    return SizedBox(
      width: 220,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) const Icon(Icons.check, size: 16, color: Colors.white) else const SizedBox(width: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: titleStyle),
                if (subtitle != null) Text(subtitle, style: subStyle),
              ],
            ),
          ),
          if (isPlaying)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.play_arrow, size: 16, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    if (d.inHours > 0) {
      final h = d.inHours.toString().padLeft(2, '0');
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
