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
class RhsPlayerController {
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

  /// Список слушателей прогресса воспроизведения
  final List<ValueChanged<Duration>> _progressListeners = [];

  /// Список слушателей состояния буферизации
  final List<ValueChanged<bool>> _bufferingListeners = [];

  /// Список слушателей состояния воспроизведения
  final List<ValueChanged<RhsPlaybackState>> _playbackStateListeners = [];

  /// Список слушателей изменений дорожек
  final List<VoidCallback> _tracksListeners = [];

  /// Список слушателей ошибок
  final List<ValueChanged<String?>> _errorListeners = [];

  /// Создает контроллер с одним медиа элементом.
  RhsPlayerController.single(
    RhsMediaSource source, {
    this.autoPlay = true,
    this.loop = false,
    this.playbackOptions = const RhsPlaybackOptions(),
  }) : playlist = [source],
       _controllerId = _nextControllerId++ {
    _wasPlaying = autoPlay;
  }

  /// Создает контроллер для пользовательского плейлиста.
  RhsPlayerController.playlist(
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
    if (_events != null) {
      if (_eventsListener != null) {
        _events!.state.removeListener(_eventsListener!);
      }
      _events!.dispose();
    }
    final ev = RhsNativeEvents(id);
    ev.start();
    _events = ev;
    _eventsListener = () {
      final v = ev.state.value;
      _resumePositionMs = v.position.inMilliseconds;
      _wasPlaying = v.isPlaying;
      // Уведомляем всех слушателей
      for (final listener in _progressListeners) {
        listener(v.position);
      }
      for (final listener in _bufferingListeners) {
        listener(v.isBuffering);
      }
      for (final listener in _playbackStateListeners) {
        listener(v);
      }
    };
    ev.state.addListener(_eventsListener!);
    // Подписываемся на ошибки
    ev.error.addListener(_errorListener);
  }

  /// Обработчик изменений ошибок
  void _errorListener() {
    final error = _events?.error.value;
    for (final listener in _errorListeners) {
      listener(error);
    }
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
    final tracks = raw
        .map((e) => e is Map ? Map<dynamic, dynamic>.from(e) : null)
        .whereType<Map<dynamic, dynamic>>()
        .map(RhsVideoTrack.fromMap)
        .toList();
    // Уведомляем слушателей об изменении дорожек
    for (final listener in _tracksListeners) {
      listener();
    }
    return tracks;
  }

  /// Выбирает конкретную видео дорожку по [trackId].
  Future<void> selectVideoTrack(String trackId) async {
    await _invoke('setVideoTrack', {'id': trackId});
    // Уведомляем слушателей об изменении дорожек
    for (final listener in _tracksListeners) {
      listener();
    }
  }

  /// Очищает ручные переопределения дорожек и возвращается к автоматическому выбору.
  Future<void> clearVideoTrackSelection() async {
    await _invoke('setVideoTrack', {'id': null});
    // Уведомляем слушателей об изменении дорожек
    for (final listener in _tracksListeners) {
      listener();
    }
  }

  /// Получает доступные аудио дорожки.
  Future<List<RhsAudioTrack>> getAudioTracks() async {
    final raw = await _invokeResult<List<dynamic>>('getAudioTracks');
    if (raw == null) return const [];
    final tracks = raw
        .map((e) => e is Map ? Map<dynamic, dynamic>.from(e) : null)
        .whereType<Map<dynamic, dynamic>>()
        .map(RhsAudioTrack.fromMap)
        .toList();
    // Уведомляем слушателей об изменении дорожек
    for (final listener in _tracksListeners) {
      listener();
    }
    return tracks;
  }

  /// Выбирает аудио дорожку. Передача `null` восстанавливает выбор по умолчанию.
  Future<void> selectAudioTrack(String? trackId) async {
    await _invoke('setAudioTrack', {'id': trackId});
    // Уведомляем слушателей об изменении дорожек
    for (final listener in _tracksListeners) {
      listener();
    }
  }

  /// Получает дорожки субтитров / титров.
  Future<List<RhsSubtitleTrack>> getSubtitleTracks() async {
    final raw = await _invokeResult<List<dynamic>>('getSubtitleTracks');
    if (raw == null) return const [];
    final tracks = raw
        .map((e) => e is Map ? Map<dynamic, dynamic>.from(e) : null)
        .whereType<Map<dynamic, dynamic>>()
        .map(RhsSubtitleTrack.fromMap)
        .toList();
    // Уведомляем слушателей об изменении дорожек
    for (final listener in _tracksListeners) {
      listener();
    }
    return tracks;
  }

  /// Выбирает дорожку субтитров. Передача `null` отключает отображение текста.
  Future<void> selectSubtitleTrack(String? trackId) async {
    await _invoke('setSubtitleTrack', {'id': trackId});
    // Уведомляем слушателей об изменении дорожек
    for (final listener in _tracksListeners) {
      listener();
    }
  }

  /// Запрашивает режим "картинка в картинке", где поддерживается.
  Future<bool> enterPictureInPicture() async {
    final ok = await _invokeResult<bool>('enterPip');
    return ok ?? false;
  }

  /// Освобождает нативные ресурсы.
  Future<void> dispose() async {
    await _invoke('dispose');
    if (_events != null) {
      if (_eventsListener != null) {
        _events!.state.removeListener(_eventsListener!);
      }
      _events!.error.removeListener(_errorListener);
      _events?.dispose();
    }
    _progressListeners.clear();
    _bufferingListeners.clear();
    _playbackStateListeners.clear();
    _tracksListeners.clear();
    _errorListeners.clear();
  }

  /// События воспроизведения, генерируемые нативным слоем.
  RhsNativeEvents? get events => _events;

  /// Добавляет слушатель прогресса воспроизведения.
  /// Возвращает функцию для удаления слушателя.
  VoidCallback addProgressListener(ValueChanged<Duration> listener) {
    _progressListeners.add(listener);
    // Немедленно вызываем с текущей позицией, если события уже инициализированы
    final currentState = _events?.state.value;
    if (currentState != null) {
      listener(currentState.position);
    }
    return () => _progressListeners.remove(listener);
  }

  /// Добавляет слушатель состояния буферизации.
  /// Возвращает функцию для удаления слушателя.
  VoidCallback addBufferingListener(ValueChanged<bool> listener) {
    _bufferingListeners.add(listener);
    // Немедленно вызываем с текущим состоянием, если события уже инициализированы
    final currentState = _events?.state.value;
    if (currentState != null) {
      listener(currentState.isBuffering);
    }
    return () => _bufferingListeners.remove(listener);
  }

  /// Добавляет слушатель состояния воспроизведения.
  /// Возвращает функцию для удаления слушателя.
  VoidCallback addPlaybackStateListener(ValueChanged<RhsPlaybackState> listener) {
    _playbackStateListeners.add(listener);
    // Немедленно вызываем с текущим состоянием, если события уже инициализированы
    final currentState = _events?.state.value;
    if (currentState != null) {
      listener(currentState);
    }
    return () => _playbackStateListeners.remove(listener);
  }

  /// Добавляет слушатель изменений дорожек.
  /// Возвращает функцию для удаления слушателя.
  VoidCallback addTracksListener(VoidCallback listener) {
    _tracksListeners.add(listener);
    return () => _tracksListeners.remove(listener);
  }

  /// Добавляет слушатель ошибок воспроизведения.
  /// Возвращает функцию для удаления слушателя.
  VoidCallback addErrorListener(ValueChanged<String?> listener) {
    _errorListeners.add(listener);
    // Немедленно вызываем с текущей ошибкой, если она есть
    final currentError = _events?.error.value;
    if (currentError != null) {
      listener(currentError);
    }
    return () => _errorListeners.remove(listener);
  }

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
