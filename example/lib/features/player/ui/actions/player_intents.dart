import 'package:flutter/widgets.dart';

/// Интенты для управления воспроизведением видео.
/// Декларируют "что хочет сделать пользователь" без реализации.

// ==================== Playback Intents ====================

/// Запустить воспроизведение
class PlayIntent extends Intent {
  const PlayIntent();
}

/// Поставить на паузу
class PauseIntent extends Intent {
  const PauseIntent();
}

/// Переключить play/pause
class TogglePlayPauseIntent extends Intent {
  const TogglePlayPauseIntent();
}

// ==================== Seek Intents ====================

/// Перемотка назад на заданный шаг
class SeekBackwardIntent extends Intent {
  final Duration step;

  const SeekBackwardIntent(this.step);
}

/// Перемотка вперёд на заданный шаг
class SeekForwardIntent extends Intent {
  final Duration step;

  const SeekForwardIntent(this.step);
}

// ==================== Controls Visibility Intents ====================

/// Показать контролы видео
class ShowControlsIntent extends Intent {
  /// Сбросить фокус на начальный элемент (play/pause)
  final bool resetFocus;

  const ShowControlsIntent({this.resetFocus = false});
}

/// Скрыть контролы видео
class HideControlsIntent extends Intent {
  const HideControlsIntent();
}

/// Переключить видимость контролов
class ToggleControlsVisibilityIntent extends Intent {
  const ToggleControlsVisibilityIntent();
}

// ==================== Menu Intents ====================

/// Открыть меню выбора качества
class OpenQualityMenuIntent extends Intent {
  const OpenQualityMenuIntent();
}

/// Открыть меню выбора аудиодорожки
class OpenSoundtrackMenuIntent extends Intent {
  const OpenSoundtrackMenuIntent();
}
