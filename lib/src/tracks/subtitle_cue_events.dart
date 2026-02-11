import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Слушает канал событий текущих субтитров от ExoPlayer.
class RhsNativeSubtitleCues {
  /// Идентификатор представления
  final int viewId;

  /// Канал событий субтитров
  late final EventChannel _eventChannel;

  /// Подписка на события
  StreamSubscription? _sub;

  /// Уведомитель текущего текста субтитров
  final ValueNotifier<String> currentText = ValueNotifier('');

  RhsNativeSubtitleCues(this.viewId) {
    _eventChannel = EventChannel('rhsplayer/cues_$viewId');
  }

  /// Начинает прослушивание событий субтитров
  void start() {
    _sub?.cancel();
    _sub = _eventChannel.receiveBroadcastStream().listen(
      _onCuesEvent,
      onError: (_) {},
    );
  }

  /// Обрабатывает событие субтитров от платформы
  void _onCuesEvent(dynamic evt) {
    if (evt is Map) {
      try {
        final text = evt['text'] as String? ?? '';
        currentText.value = text;
        dev.log('Subtitle cue received: "$text"', name: 'RhsSubtitleCues');
      } catch (e) {
        dev.log('Error parsing subtitle cue: $e', name: 'RhsSubtitleCues');
      }
    }
  }

  /// Освобождает ресурсы
  void dispose() {
    _sub?.cancel();
    currentText.dispose();
  }
}
