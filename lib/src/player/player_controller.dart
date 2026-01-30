import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

  /// Последний выбранный трек видео (для сохранения при пересоздании виджетов)
  String? _selectedVideoTrackId;

  /// Позиция возобновления воспроизведения в миллисекундах
  int _resumePositionMs = 0;

  /// Флаг состояния воспроизведения перед паузой
  bool _wasPlaying = false;

  /// Подписка на события состояния
  StreamSubscription<RhsPlaybackState>? _stateSubscription;

  /// Подписка на события ошибок
  StreamSubscription<String?>? _errorSubscription;

  /// Контроллеры потоков для ValueNotifier
  StreamController<RhsPlaybackState>? _stateController;
  StreamController<String?>? _errorController;

  /// Флаг режима экономии трафика
  bool _dataSaver = false;

  /// Stream прогресса воспроизведения
  final BehaviorSubject<Duration> _progressSubject = BehaviorSubject<Duration>.seeded(Duration.zero);

  /// Stream состояния буферизации
  final BehaviorSubject<bool> _bufferingSubject = BehaviorSubject<bool>.seeded(false);

  /// Stream состояния воспроизведения
  final BehaviorSubject<RhsPlaybackState> _playbackStateSubject = BehaviorSubject<RhsPlaybackState>.seeded(
    const RhsPlaybackState(
      position: Duration.zero,
      duration: Duration.zero,
      bufferedPosition: Duration.zero,
      isPlaying: false,
      isBuffering: false,
    ),
  );

  /// Stream изменений дорожек
  final PublishSubject<void> _tracksSubject = PublishSubject<void>();

  /// Stream ошибок
  final BehaviorSubject<String?> _errorSubject = BehaviorSubject<String?>.seeded(null);

  /// Stream событий (для обратной совместимости)
  final BehaviorSubject<RhsNativeEvents?> _eventsSubject = BehaviorSubject<RhsNativeEvents?>.seeded(null);

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
      _stateSubscription?.cancel();
      _errorSubscription?.cancel();
      _stateController?.close();
      _errorController?.close();
      _events!.dispose();
    }
    if (_tracks != null) {
      _tracks!.dispose();
    }

    final ev = RhsNativeEvents(id);
    ev.start();
    _events = ev;
    _eventsSubject.add(ev);

    // Инициализируем слушатель треков
    final tracks = RhsNativeTracks(id);
    tracks.start();
    _tracks = tracks;

    // Подписываемся на изменения состояния
    _stateSubscription = _listenToStateNotifier(ev.state).listen((state) {
      _resumePositionMs = state.position.inMilliseconds;
      _wasPlaying = state.isPlaying;
      _progressSubject.add(state.position);
      _bufferingSubject.add(state.isBuffering);
      _playbackStateSubject.add(state);
    });

    // Подписываемся на ошибки
    _errorSubscription = _listenToErrorNotifier(ev.error).listen((error) {
      _errorSubject.add(error);
    });
  }

  /// Преобразует ValueNotifier в Stream для состояния воспроизведения
  Stream<RhsPlaybackState> _listenToStateNotifier(ValueNotifier<RhsPlaybackState> notifier) {
    _stateController?.close();
    _stateController = StreamController<RhsPlaybackState>.broadcast();
    void listener() => _stateController!.add(notifier.value);
    notifier.addListener(listener);
    _stateController!.onCancel = () => notifier.removeListener(listener);
    return _stateController!.stream;
  }

  /// Преобразует ValueNotifier в Stream для ошибок
  Stream<String?> _listenToErrorNotifier(ValueNotifier<String?> notifier) {
    _errorController?.close();
    _errorController = StreamController<String?>.broadcast();
    void listener() => _errorController!.add(notifier.value);
    notifier.addListener(listener);
    _errorController!.onCancel = () => notifier.removeListener(listener);
    return _errorController!.stream;
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
    if (raw == null) return const [];
    final tracks = raw
        .map((e) => e is Map ? Map<dynamic, dynamic>.from(e) : null)
        .whereType<Map<dynamic, dynamic>>()
        .map(RhsAudioTrack.fromMap)
        .toList();
    // Уведомляем слушателей об изменении дорожек
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
    _errorSubscription?.cancel();
    _stateController?.close();
    _errorController?.close();
    _events?.dispose();
    await _progressSubject.close();
    await _bufferingSubject.close();
    await _playbackStateSubject.close();
    await _tracksSubject.close();
    await _errorSubject.close();
    await _eventsSubject.close();
    _tracks?.dispose();
  }

  /// События воспроизведения, генерируемые нативным слоем (для обратной совместимости).
  RhsNativeEvents? get events => _events;

  /// Список видео треков, обновляемый автоматически от ExoPlayer
  ValueNotifier<List<RhsVideoTrack>>? get videoTracks => _tracks?.videoTracks;

  /// Последний выбранный ID трека видео (для восстановления состояния после пересоздания виджета)
  String? get selectedVideoTrackId => _selectedVideoTrackId;

  /// Stream прогресса воспроизведения
  Stream<Duration> get progressStream => _progressSubject.stream;

  /// Stream состояния буферизации
  Stream<bool> get bufferingStream => _bufferingSubject.stream;

  /// Stream состояния воспроизведения
  Stream<RhsPlaybackState> get playbackStateStream => _playbackStateSubject.stream;

  /// Stream изменений дорожек
  Stream<void> get tracksStream => _tracksSubject.stream;

  /// Stream ошибок воспроизведения
  Stream<String?> get errorStream => _errorSubject.stream;

  /// Stream событий (для обратной совместимости)
  Stream<RhsNativeEvents?> get eventsStream => _eventsSubject.stream;

  /// Текущее состояние воспроизведения
  RhsPlaybackState get currentPlaybackState => _playbackStateSubject.value;

  /// Текущая позиция воспроизведения
  Duration get currentPosition => _progressSubject.value;

  /// Текущее состояние буферизации
  bool get isBuffering => _bufferingSubject.value;

  /// Текущая ошибка воспроизведения
  String? get currentError => _errorSubject.value;

  /// Добавляет слушатель прогресса воспроизведения.
  /// Возвращает функцию для удаления слушателя.
  /// @deprecated Используйте [progressStream] вместо этого
  VoidCallback addProgressListener(ValueChanged<Duration> listener) {
    final subscription = progressStream.listen(listener);
    return () => subscription.cancel();
  }

  /// Добавляет слушатель состояния буферизации.
  /// Возвращает функцию для удаления слушателя.
  /// @deprecated Используйте [bufferingStream] вместо этого
  VoidCallback addBufferingListener(ValueChanged<bool> listener) {
    final subscription = bufferingStream.listen(listener);
    return () => subscription.cancel();
  }

  /// Добавляет слушатель состояния воспроизведения.
  /// Возвращает функцию для удаления слушателя.
  /// @deprecated Используйте [playbackStateStream] вместо этого
  VoidCallback addPlaybackStateListener(ValueChanged<RhsPlaybackState> listener) {
    final subscription = playbackStateStream.listen(listener);
    return () => subscription.cancel();
  }

  /// Добавляет слушатель изменений дорожек.
  /// Возвращает функцию для удаления слушателя.
  /// @deprecated Используйте [tracksStream] вместо этого
  VoidCallback addTracksListener(VoidCallback listener) {
    final subscription = tracksStream.listen((_) => listener());
    return () => subscription.cancel();
  }

  /// Добавляет слушатель ошибок воспроизведения.
  /// Возвращает функцию для удаления слушателя.
  /// @deprecated Используйте [errorStream] вместо этого
  VoidCallback addErrorListener(ValueChanged<String?> listener) {
    final subscription = errorStream.listen(listener);
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
