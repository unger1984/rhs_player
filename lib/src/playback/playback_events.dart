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

  /// Уведомитель состояния воспроизведения
  final ValueNotifier<RhsPlaybackState> state = ValueNotifier(
    const RhsPlaybackState(position: Duration.zero, duration: Duration.zero, isPlaying: false, isBuffering: true),
  );

  /// Уведомитель ошибок воспроизведения
  /// Выдает ненулевое значение, когда нативная сторона сообщает об ошибке; 
  /// очищается при возобновлении воспроизведения.
  final ValueNotifier<String?> error = ValueNotifier(null);

  RhsNativeEvents(this.viewId) {
    _eventChannel = EventChannel('rhsplayer/events_$viewId');
  }

  /// Начинает прослушивание событий
  void start() {
    _sub?.cancel();
    _sub = _eventChannel.receiveBroadcastStream().listen(_onEvent, onError: (_) {});
  }

  /// Обрабатывает событие от платформы
  void _onEvent(dynamic evt) {
    if (evt is Map) {
      final posMs = (evt['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (evt['durationMs'] as num?)?.toInt() ?? 0;
      final playing = evt['isPlaying'] == true;
      final buffering = evt['isBuffering'] == true;
      final errMsg = evt['error'] as String?;
      if (errMsg != null && errMsg.isNotEmpty) {
        error.value = errMsg;
      } else if (playing) {
        // Очищает ошибку после возобновления воспроизведения
        error.value = null;
      }
      state.value = RhsPlaybackState(
        position: Duration(milliseconds: posMs),
        duration: Duration(milliseconds: durMs),
        isPlaying: playing,
        isBuffering: buffering,
      );
    }
  }

  /// Освобождает ресурсы
  void dispose() {
    _sub?.cancel();
    state.dispose();
    error.dispose();
  }
}
