import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'playback_state.dart';

/// Слушает канал событий платформы и предоставляет обновления состояния воспроизведения.
class RhsNativeEvents {
  /// Идентификатор представления
  final int viewId;

  /// Канал событий платформы
  late final EventChannel _eventChannel;

  /// Подписка на события
  StreamSubscription? _sub;

  /// Уведомитель состояния воспроизведения (включая ошибку; playing и error взаимоисключают друг друга)
  final ValueNotifier<RhsPlaybackState> state = ValueNotifier(
    const RhsPlaybackState(
      position: Duration.zero,
      duration: Duration.zero,
      bufferedPosition: Duration.zero,
      isPlaying: false,
      isBuffering: true,
      error: null,
    ),
  );

  RhsNativeEvents(this.viewId) {
    _eventChannel = EventChannel('rhsplayer/events_$viewId');
  }

  /// Начинает прослушивание событий
  void start() {
    _sub?.cancel();
    _sub = _eventChannel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (_) {},
    );
  }

  /// Обрабатывает событие от платформы
  void _onEvent(dynamic evt) {
    if (evt is Map) {
      final posMs = (evt['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (evt['durationMs'] as num?)?.toInt() ?? 0;
      final bufferedMs = (evt['bufferedPositionMs'] as num?)?.toInt() ?? 0;
      final playing = evt['isPlaying'] == true;
      final buffering = evt['isBuffering'] == true;
      final errMsg = evt['error'] as String?;
      final error = (errMsg != null && errMsg.isNotEmpty) ? errMsg : null;
      state.value = RhsPlaybackState(
        position: Duration(milliseconds: posMs),
        duration: Duration(milliseconds: durMs),
        bufferedPosition: Duration(milliseconds: bufferedMs),
        isPlaying: playing,
        isBuffering: buffering,
        error: playing ? null : error,
      );
    }
  }

  /// Освобождает ресурсы
  void dispose() {
    _sub?.cancel();
    state.dispose();
  }
}
