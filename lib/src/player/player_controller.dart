import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:rhs_player/src/playback/player_status.dart';
import 'package:rhs_player/src/playback/position_data.dart';
import 'package:rxdart/rxdart.dart';

import '../media/media_source.dart';
import '../media/drm_config.dart';
import '../playback/playback_events.dart';
import '../playback/playback_state.dart';
import '../playback/playback_options.dart';
import '../tracks/track_models.dart';
import '../tracks/track_events.dart';

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

  /// Обработчик событий треков от ExoPlayer
  RhsNativeTracks? _tracks;

  /// Список отложенных слушателей треков (до создания view)
  final List<ValueChanged<List<RhsVideoTrack>>> _pendingVideoTracksListeners =
      [];

  /// Список отложенных слушателей треков (до создания view)
  final List<ValueChanged<List<RhsAudioTrack>>> _pendingAudioTracksListeners =
      [];

  /// Флаг, что первоначальный список треков был загружен
  bool _initialTracksFetched = false;

  /// Последний выбранный трек видео (для сохранения при пересоздании виджетов)
  String? _selectedVideoTrackId;

  /// Позиция возобновления воспроизведения в миллисекундах
  int _resumePositionMs = 0;

  /// Флаг состояния воспроизведения перед паузой
  bool _wasPlaying = false;

  /// Подписка на события состояния (включая ошибку)
  StreamSubscription<RhsPlaybackState>? _stateSubscription;

  /// Контроллер потока для ValueNotifier состояния
  StreamController<RhsPlaybackState>? _stateController;

  /// Флаг режима экономии трафика
  bool _dataSaver = false;

  /// Stream состояния плеера
  final _playerStatusSubject = BehaviorSubject<RhsPlayerStatus>.seeded(
    const RhsPlayerStatusLoading(),
  );

  /// Stream с данными о позиции и длительности
  final _positionDataSubject = BehaviorSubject<RhsPositionData>.seeded(
    const RhsPositionData(Duration.zero, Duration.zero),
  );

  /// Stream о буферизованной позиции
  final _bufferedPositionSubject = BehaviorSubject<Duration>.seeded(
    Duration.zero,
  );

  /// Stream изменений дорожек
  final PublishSubject<void> _tracksSubject = PublishSubject<void>();

  /// Stream событий (для обратной совместимости)
  final BehaviorSubject<RhsNativeEvents?> _eventsSubject =
      BehaviorSubject<RhsNativeEvents?>.seeded(null);

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
        .map(
          (s) => {
            'url': s.url,
            'headers': s.headers ?? {},
            'drm': _drmToMap(s.drm),
          },
        )
        .toList(),
  };

  /// Привязывает контроллер к идентификатору нативного представления.
  void attachViewId(int id) {
    _channel = MethodChannel('rhsplayer/view_$id');
    // Перепривязывает события; освобождает предыдущие для избежания утечек
    if (_events != null) {
      _stateSubscription?.cancel();
      _stateController?.close();
      _events!.dispose();
    }
    if (_tracks != null) {
      _tracks!.dispose();
    }

    _initialTracksFetched = false; // Сбрасываем флаг

    final ev = RhsNativeEvents(id);
    ev.start();
    _events = ev;
    _eventsSubject.add(ev);

    // Инициализируем слушатель треков
    final tracks = RhsNativeTracks(id);
    tracks.start();
    _tracks = tracks;

    // Подписываем отложенных слушателей
    for (final listener in _pendingVideoTracksListeners) {
      void valueChangedListener() {
        listener(tracks.videoTracks.value);
      }

      tracks.videoTracks.addListener(valueChangedListener);
    }
    for (final listener in _pendingAudioTracksListeners) {
      void valueChangedListener() {
        listener(tracks.audioTracks.value);
      }

      tracks.audioTracks.addListener(valueChangedListener);
    }

    // Подписываемся на изменения состояния (включая ошибку)
    _stateSubscription = _listenToStateNotifier(ev.state).listen((state) {
      final wasPlayingBeforeUpdate = _wasPlaying;
      _resumePositionMs = state.position.inMilliseconds;
      _wasPlaying = state.isPlaying;

      // Разово загружаем треки, как только плеер начинает играть
      if (state.isPlaying &&
          !wasPlayingBeforeUpdate &&
          !_initialTracksFetched) {
        _initialTracksFetched = true;
        getVideoTracks();
      }

      // Обновляем новые потоки
      _updatePlayerStatus(state);
      _positionDataSubject.add(RhsPositionData(state.position, state.duration));
      _bufferedPositionSubject.add(state.bufferedPosition);
    });
  }

  void _updatePlayerStatus(RhsPlaybackState state) {
    if (state.error != null) {
      _playerStatusSubject.add(RhsPlayerStatusError(state.error!));
    } else if (state.isBuffering) {
      _playerStatusSubject.add(const RhsPlayerStatusLoading());
    } else if (state.isPlaying) {
      _playerStatusSubject.add(const RhsPlayerStatusPlaying());
    } else if (state.position >= state.duration &&
        state.duration > Duration.zero) {
      _playerStatusSubject.add(const RhsPlayerStatusEnded());
    } else {
      _playerStatusSubject.add(const RhsPlayerStatusPaused());
    }
  }

  /// Преобразует ValueNotifier в Stream для состояния воспроизведения
  Stream<RhsPlaybackState> _listenToStateNotifier(
    ValueNotifier<RhsPlaybackState> notifier,
  ) {
    _stateController?.close();
    _stateController = StreamController<RhsPlaybackState>.broadcast();
    void listener() => _stateController!.add(notifier.value);
    notifier.addListener(listener);
    _stateController!.onCancel = () => notifier.removeListener(listener);
    return _stateController!.stream;
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
  Future<void> seekTo(Duration position) async =>
      _invoke('seekTo', {'millis': position.inMilliseconds});

  /// Регулирует скорость воспроизведения [speed].
  Future<void> setSpeed(double speed) async =>
      _invoke('setSpeed', {'speed': speed});

  /// Переключает зацикливание для текущего элемента или плейлиста.
  Future<void> setLooping(bool looping) async =>
      _invoke('setLooping', {'loop': looping});

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
    if (raw == null) {
      _tracks?.videoTracks.value = [];
      return const [];
    }
    final tracks = raw
        .map((e) => e is Map ? Map<dynamic, dynamic>.from(e) : null)
        .whereType<Map<dynamic, dynamic>>()
        .map(RhsVideoTrack.fromMap)
        .toList();

    // Обновляем ValueNotifier, чтобы слушатели получили актуальный список
    _tracks?.videoTracks.value = tracks;

    // Уведомляем слушателей об изменении дорожек (для старого API)
    _tracksSubject.add(null);
    return tracks;
  }

  /// Выбирает конкретную видео дорожку по [trackId].
  Future<void> selectVideoTrack(String trackId) async {
    _selectedVideoTrackId = trackId; // Сохраняем выбранный трек
    await _invoke('setVideoTrack', {'id': trackId});
    // Уведомляем слушателей об изменении дорожек
    _tracksSubject.add(null);
  }

  /// Очищает ручные переопределения дорожек и возвращается к автоматическому выбору.
  Future<void> clearVideoTrackSelection() async {
    _selectedVideoTrackId = null; // Сбрасываем сохраненный трек
    await _invoke('setVideoTrack', {'id': null});
    // Уведомляем слушателей об изменении дорожек
    _tracksSubject.add(null);
  }

  /// Получает доступные аудио дорожки.
  Future<List<RhsAudioTrack>> getAudioTracks() async {
    final raw = await _invokeResult<List<dynamic>>('getAudioTracks');
    if (raw == null) {
      _tracks?.audioTracks.value = [];
      return const [];
    }
    final tracks = raw
        .map((e) => e is Map ? Map<dynamic, dynamic>.from(e) : null)
        .whereType<Map<dynamic, dynamic>>()
        .map(RhsAudioTrack.fromMap)
        .toList();
    // Уведомляем слушателей об изменении дорожек
    _tracks?.audioTracks.value = tracks;
    _tracksSubject.add(null);
    return tracks;
  }

  /// Выбирает аудио дорожку. Передача `null` восстанавливает выбор по умолчанию.
  Future<void> selectAudioTrack(String? trackId) async {
    await _invoke('setAudioTrack', {'id': trackId});
    // Уведомляем слушателей об изменении дорожек
    _tracksSubject.add(null);
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
    _tracksSubject.add(null);
    return tracks;
  }

  /// Выбирает дорожку субтитров. Передача `null` отключает отображение текста.
  Future<void> selectSubtitleTrack(String? trackId) async {
    await _invoke('setSubtitleTrack', {'id': trackId});
    // Уведомляем слушателей об изменении дорожек
    _tracksSubject.add(null);
  }

  /// Запрашивает режим "картинка в картинке", где поддерживается.
  Future<bool> enterPictureInPicture() async {
    final ok = await _invokeResult<bool>('enterPip');
    return ok ?? false;
  }

  /// Освобождает нативные ресурсы.
  Future<void> dispose() async {
    await _invoke('dispose');
    _stateSubscription?.cancel();
    _stateController?.close();
    _events?.dispose();
    await _playerStatusSubject.close();
    await _positionDataSubject.close();
    await _bufferedPositionSubject.close();
    await _tracksSubject.close();
    await _eventsSubject.close();
    _tracks?.dispose();
  }

  /// События воспроизведения, генерируемые нативным слоем (для обратной совместимости).
  RhsNativeEvents? get events => _events;

  /// Список видео треков, обновляемый автоматически от ExoPlayer
  ValueNotifier<List<RhsVideoTrack>>? get videoTracks => _tracks?.videoTracks;

  /// Список аудио треков, обновляемый автоматически от ExoPlayer
  ValueNotifier<List<RhsAudioTrack>>? get audioTracks => _tracks?.audioTracks;

  /// Последний выбранный ID трека видео (для восстановления состояния после пересоздания виджета)
  String? get selectedVideoTrackId => _selectedVideoTrackId;

  /// Stream состояния плеера
  Stream<RhsPlayerStatus> get playerStatusStream => _playerStatusSubject.stream;

  /// Stream с данными о позиции и длительности
  Stream<RhsPositionData> get positionDataStream => _positionDataSubject.stream;

  /// Stream о буферизованной позиции
  Stream<Duration> get bufferedPositionStream =>
      _bufferedPositionSubject.stream;

  /// Stream изменений дорожек
  Stream<void> get tracksStream => _tracksSubject.stream;

  /// Stream событий (для обратной совместимости)
  Stream<RhsNativeEvents?> get eventsStream => _eventsSubject.stream;

  /// Текущее состояние плеера
  RhsPlayerStatus get currentPlayerStatus => _playerStatusSubject.value;

  /// Текущие данные о позиции
  RhsPositionData get currentPositionData => _positionDataSubject.value;

  /// Текущая позиция воспроизведения
  Duration get currentPosition => _positionDataSubject.value.position;

  /// Текущая буферизованная позиция
  Duration get currentBufferedPosition => _bufferedPositionSubject.value;

  /// Добавляет слушатель состояния плеера.
  /// Возвращает функцию для отписки.
  VoidCallback addStatusListener(ValueChanged<RhsPlayerStatus> listener) {
    final subscription = playerStatusStream.listen(listener);
    return () => subscription.cancel();
  }

  /// Добавляет слушатель данных о позиции.
  /// Возвращает функцию для отписки.
  VoidCallback addPositionDataListener(ValueChanged<RhsPositionData> listener) {
    final subscription = positionDataStream.listen(listener);
    return () => subscription.cancel();
  }

  /// Добавляет слушатель буферизованной позиции.
  /// Возвращает функцию для отписки.
  VoidCallback addBufferedPositionListener(ValueChanged<Duration> listener) {
    final subscription = bufferedPositionStream.listen(listener);
    return () => subscription.cancel();
  }

  /// Добавляет слушатель списка доступных видео дорожек.
  /// Событие сработает после загрузки видео и при каждом изменении списка.
  /// Возвращает функцию для отписки.
  VoidCallback addVideoTracksListener(
    ValueChanged<List<RhsVideoTrack>> listener,
  ) {
    final notifier = _tracks?.videoTracks;
    if (notifier == null) {
      // View еще не создан - сохраняем слушатель для отложенной подписки
      _pendingVideoTracksListeners.add(listener);
      return () => _pendingVideoTracksListeners.remove(listener);
    }

    // Создаем обертку, чтобы вызывать listener с ValueChanged
    void valueChangedListener() {
      listener(notifier.value);
    }

    notifier.addListener(valueChangedListener);

    return () => notifier.removeListener(valueChangedListener);
  }

  /// Добавляет слушатель списка доступных аудио дорожек.
  /// Событие сработает после загрузки видео и при каждом изменении списка.
  /// Возвращает функцию для отписки.
  VoidCallback addAudioTracksListener(
    ValueChanged<List<RhsAudioTrack>> listener,
  ) {
    final notifier = _tracks?.audioTracks;
    if (notifier == null) {
      // View еще не создан - сохраняем слушатель для отложенной подписки
      _pendingAudioTracksListeners.add(listener);
      return () => _pendingAudioTracksListeners.remove(listener);
    }

    // Создаем обертку, чтобы вызывать listener с ValueChanged
    void valueChangedListener() {
      listener(notifier.value);
    }

    notifier.addListener(valueChangedListener);

    return () => notifier.removeListener(valueChangedListener);
  }

  /// Добавляет слушатель изменений дорожек.
  /// Возвращает функцию для удаления слушателя.
  VoidCallback addTracksListener(VoidCallback listener) {
    final subscription = tracksStream.listen((_) => listener());
    return () => subscription.cancel();
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
  Future<T?> _invokeResult<T>(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    final ch = _channel;
    if (ch == null) return null;
    try {
      return await ch.invokeMethod<T>(method, args);
    } catch (_) {
      return null;
    }
  }
}
