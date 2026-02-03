import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'track_models.dart';

/// Слушает канал событий треков от ExoPlayer и предоставляет обновления списка треков.
class RhsNativeTracks {
  /// Идентификатор представления
  final int viewId;

  /// Канал событий треков
  late final EventChannel _eventChannel;

  /// Подписка на события
  StreamSubscription? _sub;

  /// Уведомитель списка видео треков
  final ValueNotifier<List<RhsVideoTrack>> videoTracks = ValueNotifier([]);

  /// Уведомитель списка аудио треков
  final ValueNotifier<List<RhsAudioTrack>> audioTracks = ValueNotifier([]);

  RhsNativeTracks(this.viewId) {
    _eventChannel = EventChannel('rhsplayer/tracks_$viewId');
  }

  /// Начинает прослушивание событий треков
  void start() {
    _sub?.cancel();
    _sub = _eventChannel.receiveBroadcastStream().listen(
      _onTracksEvent,
      onError: (_) {},
    );
  }

  /// Обрабатывает событие треков от платформы
  void _onTracksEvent(dynamic evt) {
    if (evt is Map) {
      try {
        if (evt.containsKey('video')) {
          final video = evt['video'] as List;
          final tracks = video
              .map((e) => e is Map ? Map<dynamic, dynamic>.from(e) : null)
              .whereType<Map<dynamic, dynamic>>()
              .map(RhsVideoTrack.fromMap)
              .toList();
          videoTracks.value = tracks;
        }
        if (evt.containsKey('audio')) {
          final audio = evt['audio'] as List;
          final tracks = audio
              .map((e) => e is Map ? Map<dynamic, dynamic>.from(e) : null)
              .whereType<Map<dynamic, dynamic>>()
              .map(RhsAudioTrack.fromMap)
              .toList();
          audioTracks.value = tracks;
        }
      } catch (e) {
        // Игнорируем ошибки парсинга
      }
    }
  }

  /// Освобождает ресурсы
  void dispose() {
    _sub?.cancel();
    videoTracks.dispose();
    audioTracks.dispose();
  }
}
