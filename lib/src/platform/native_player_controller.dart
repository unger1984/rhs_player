import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/media_source.dart';
import '../core/drm.dart';
import 'native_events.dart';
import 'native_tracks.dart';
import 'playback_options.dart';

/// Мост между Flutter и нативной реализацией плеера.
///
/// Контроллер управляет плейлистом, жизненным циклом и предоставляет 
/// удобные методы, такие как [play], [pause], [seekTo] и выбор дорожек.
class RhsNativePlayerController {
  /// Список медиа источников для воспроизведения
  final List<RhsMediaSource> playlist;
  
  /// Флаг автоматического воспроизведения при запуске
  final bool autoPlay;
  
  /// Флаг зацикливания воспроизведения
  final bool loop;
  
  /// Опции воспроизведения
  final RhsPlaybackOptions playbackOptions;
  
  /// Следующий доступный идентификатор контроллера
  static int _nextControllerId = 1;
  
  /// Идентификатор текущего контроллера
  final int _controllerId;
  
  /// Канал связи с нативным кодом
  MethodChannel? _channel;
  
  /// Обработчик событий нативного плеера
  RhsNativeEvents? _events;
  
  /// Позиция возобновления воспроизведения в миллисекундах
  int _resumePositionMs = 0;
  
  /// Флаг состояния воспроизведения перед паузой
  bool _wasPlaying = false;
  
  /// Слушатель событий изменения состояния
  VoidCallback? _eventsListener;
  
  /// Флаг режима экономии трафика
  bool _dataSaver = false;

  /// Создает контроллер с одним медиа элементом.
  RhsNativePlayerController.single(
    RhsMediaSource source, {
    this.autoPlay = true,
    this.loop = false,
    this.playbackOptions = const RhsPlaybackOptions(),
  }) : playlist = [source],
       _controllerId = _nextControllerId++ {
    _wasPlaying = autoPlay;
  }

  /// Создает контроллер для пользовательского плейлиста.
  RhsNativePlayerController.playlist(
    this.playlist, {
    this.autoPlay = true,
    this.loop = false,
    this.playbackOptions = const RhsPlaybackOptions(),
  }) : _controllerId = _nextControllerId++ {
    _wasPlaying = autoPlay;
  }

  /// Сериализованные аргументы, передаваемые в нативное представление.
  Map<String, dynamic> get creationParams => {
    'autoPlay': autoPlay,
    'loop': loop,
    'startPositionMs': _resumePositionMs,
    'startAutoPlay': _wasPlaying,
    'dataSaver': _dataSaver,
    'playbackOptions': playbackOptions.toMap(),
    'controllerId': _controllerId,
    'playlist': playlist
        .map((s) => {'url': s.url, 'headers': s.headers ?? {}, 'isLive': s.isLive, 'drm': _drmToMap(s.drm)})
        .toList(),
  };

  /// Привязывает контроллер к идентификатору нативного представления.
  void attachViewId(int id) {
    _channel = MethodChannel('rhsplayer/view_$id');
    // Перепривязывает события; освобождает предыдущие для избежания утечек
    _events?.dispose();
    final ev = RhsNativeEvents(id);
    ev.start();
    _events = ev;
    _eventsListener?.call();
    _eventsListener = () {
      final v = ev.state.value;
      _resumePositionMs = v.position.inMilliseconds;
      _wasPlaying = v.isPlaying;
    };
    ev.state.addListener(_eventsListener!);
  }

  /// Преобразует конфигурацию DRM в карту для передачи в нативный код
  Map<String, dynamic> _drmToMap(RhsDrmConfig drm) => {
    'type': drm.type.name,
    'licenseUrl': drm.licenseUrl,
    'headers': drm.headers ?? {},
    'clearKey': drm.clearKey,
    'contentId': drm.contentId,
  };

  /// Начинает воспроизведение, если готов.
  Future<void> play() async => _invoke('play');

  /// Ставит воспроизведение на паузу, сохраняя буфер.
  Future<void> pause() async => _invoke('pause');

  /// Перематывает к новой [position].
  Future<void> seekTo(Duration position) async => _invoke('seekTo', {'millis': position.inMilliseconds});

  /// Регулирует скорость воспроизведения [speed].
  Future<void> setSpeed(double speed) async => _invoke('setSpeed', {'speed': speed});

  /// Переключает зацикливание для текущего элемента или плейлиста.
  Future<void> setLooping(bool looping) async => _invoke('setLooping', {'loop': looping});

  /// Обновляет масштабирование содержимого нативного представления.
  Future<void> setBoxFit(BoxFit fit) async => _invoke('setBoxFit', {
    'fit': switch (fit) {
      BoxFit.contain => 'contain',
      BoxFit.cover => 'cover',
      BoxFit.fill => 'fill',
      BoxFit.fitWidth => 'fitWidth',
      BoxFit.fitHeight => 'fitHeight',
      BoxFit.none => 'contain',
      BoxFit.scaleDown => 'contain',
    },
  });

  /// Переподготавливает медиа источник и пытается возобновить воспроизведение.
  Future<void> retry() async => _invoke('retry');

  /// Ограничивает битрейт, когда [enable] равно true, для экономии трафика.
  Future<void> setDataSaver(bool enable) async {
    _dataSaver = enable;
    await _invoke('setDataSaver', {'enable': enable});
  }

  /// Получает доступные видео дорожки от нативного плеера.
  Future<List<RhsVideoTrack>> getVideoTracks() async {
    final raw = await _invokeResult<List<dynamic>>('getVideoTracks');
    if (raw == null) return const [];
    return raw
        .map((e) => e is Map ? Map<dynamic, dynamic>.from(e) : null)
        .whereType<Map<dynamic, dynamic>>()
        .map(RhsVideoTrack.fromMap)
        .toList();
  }

  /// Выбирает конкретную видео дорожку по [trackId].
  Future<void> selectVideoTrack(String trackId) async {
    await _invoke('setVideoTrack', {'id': trackId});
  }

  /// Очищает ручные переопределения дорожек и возвращается к автоматическому выбору.
  Future<void> clearVideoTrackSelection() async {
    await _invoke('setVideoTrack', {'id': null});
  }

  /// Получает доступные аудио дорожки.
  Future<List<RhsAudioTrack>> getAudioTracks() async {
    final raw = await _invokeResult<List<dynamic>>('getAudioTracks');
    if (raw == null) return const [];
    return raw
        .map((e) => e is Map ? Map<dynamic, dynamic>.from(e) : null)
        .whereType<Map<dynamic, dynamic>>()
        .map(RhsAudioTrack.fromMap)
        .toList();
  }

  /// Выбирает аудио дорожку. Передача `null` восстанавливает выбор по умолчанию.
  Future<void> selectAudioTrack(String? trackId) async {
    await _invoke('setAudioTrack', {'id': trackId});
  }

  /// Получает дорожки субтитров / титров.
  Future<List<RhsSubtitleTrack>> getSubtitleTracks() async {
    final raw = await _invokeResult<List<dynamic>>('getSubtitleTracks');
    if (raw == null) return const [];
    return raw
        .map((e) => e is Map ? Map<dynamic, dynamic>.from(e) : null)
        .whereType<Map<dynamic, dynamic>>()
        .map(RhsSubtitleTrack.fromMap)
        .toList();
  }

  /// Выбирает дорожку субтитров. Передача `null` отключает отображение текста.
  Future<void> selectSubtitleTrack(String? trackId) async {
    await _invoke('setSubtitleTrack', {'id': trackId});
  }

  /// Запрашивает режим "картинка в картинке", где поддерживается.
  Future<bool> enterPictureInPicture() async {
    final ok = await _invokeResult<bool>('enterPip');
    return ok ?? false;
  }

  /// Освобождает нативные ресурсы.
  Future<void> dispose() async {
    await _invoke('dispose');
    _events?.dispose();
  }

  /// События воспроизведения, генерируемые нативным слоем.
  RhsNativeEvents? get events => _events;

  /// Вызывает метод нативного кода без возвращаемого значения
  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    final ch = _channel;
    if (ch == null) return;
    try {
      await ch.invokeMethod(method, args);
    } catch (_) {}
  }

  /// Вызывает метод нативного кода с возвращаемым значением
  Future<T?> _invokeResult<T>(String method, [Map<String, dynamic>? args]) async {
    final ch = _channel;
    if (ch == null) return null;
    try {
      return await ch.invokeMethod<T>(method, args);
    } catch (_) {
      return null;
    }
  }
}
