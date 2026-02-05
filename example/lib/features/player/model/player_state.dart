import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/entities/media/model/media_item.dart';
import 'package:rhs_player_example/shared/api/media_repository.dart';

/// Управление состоянием плеера.
/// Инкапсулирует всю бизнес-логику: инициализацию контроллера,
/// загрузку фильмов, подписку на события, управление воспроизведением.
class PlayerState {
  final MediaRepository _repository;

  /// Контроллер плеера
  late final RhsPlayerController controller;

  /// Список всех загруженных фильмов
  List<MediaItem> _mediaItems = [];

  /// Текущий воспроизводимый фильм
  MediaItem? _currentItem;

  /// Callback для обновления UI
  void Function()? onStateChanged;

  /// Обработчик кнопки Back от VideoControls
  bool Function()? backHandler;

  PlayerState(this._repository);

  /// Инициализация плеера и загрузка данных
  Future<void> initialize() async {
    // Создаём контроллер с placeholder source
    final placeholderSource = RhsMediaSource(
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    );
    controller = RhsPlayerController.single(placeholderSource);

    // Подписываемся на события плеера
    _subscribeToPlayerEvents();

    // Загружаем список фильмов
    await _loadMediaItems();
  }

  /// Подписка на события плеера (логирование)
  void _subscribeToPlayerEvents() {
    controller.addStatusListener((status) {
      if (status is RhsPlayerStatusError) {
        developer.log('EVENT PLAYER ERROR: ${status.message}');
      } else {
        developer.log('EVENT PLAYER STATUS: $status');
      }
    });

    controller.addPositionDataListener((data) {
      developer.log('EVENT POSITION DATA: ${data.position} / ${data.duration}');
    });

    controller.addBufferedPositionListener((position) {
      developer.log('EVENT BUFFERED: $position');
    });

    controller.addVideoTracksListener((tracks) {
      final trackLabels = tracks.map((t) => t.displayLabel).join(', ');
      developer.log('EVENT VIDEO TRACKS: [$trackLabels]');
    });

    controller.addAudioTracksListener((tracks) {
      final trackLabels = tracks.map((t) => t.label).join(', ');
      developer.log('EVENT AUDIO TRACKS: [$trackLabels]');
    });
  }

  /// Загрузка списка фильмов из репозитория
  Future<void> _loadMediaItems() async {
    try {
      _mediaItems = await _repository.loadMediaItems();

      if (_mediaItems.isEmpty) {
        debugPrint('PlayerState: No media items loaded');
        return;
      }

      // Начинаем воспроизведение первого фильма
      final firstItem = _mediaItems.first;
      _currentItem = firstItem;
      controller.loadMediaSource(firstItem.toMediaSource());

      onStateChanged?.call();
    } catch (e, st) {
      debugPrint('PlayerState: Failed to load media items: $e\n$st');
    }
  }

  /// Воспроизведение выбранного фильма
  void playMedia(MediaItem item) {
    if (_currentItem == item) return;

    _currentItem = item;
    controller.loadMediaSource(item.toMediaSource());
    onStateChanged?.call();
  }

  /// Получить список рекомендаций (все фильмы кроме текущего)
  List<MediaItem> getRecommendedItems() {
    if (_currentItem == null) return _mediaItems;
    return _mediaItems.where((item) => item != _currentItem).toList();
  }

  /// Текущий воспроизводимый фильм
  MediaItem? get currentItem => _currentItem;

  /// Очистка ресурсов
  void dispose() {
    controller.dispose();
  }
}
