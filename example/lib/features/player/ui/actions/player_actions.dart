import 'package:flutter/widgets.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/features/player/ui/actions/player_intents.dart';

/// Action классы для обработки Intent'ов управления плеером.
/// Содержат реализацию "как это сделать".

// ==================== Playback Actions ====================

/// Action для запуска воспроизведения
class PlayAction extends Action<PlayIntent> {
  final RhsPlayerController controller;

  PlayAction(this.controller);

  @override
  void invoke(PlayIntent intent) {
    controller.play();
  }
}

/// Action для паузы
class PauseAction extends Action<PauseIntent> {
  final RhsPlayerController controller;

  PauseAction(this.controller);

  @override
  void invoke(PauseIntent intent) {
    controller.pause();
  }
}

/// Action для переключения play/pause
class TogglePlayPauseAction extends Action<TogglePlayPauseIntent> {
  final RhsPlayerController controller;

  TogglePlayPauseAction(this.controller);

  @override
  void invoke(TogglePlayPauseIntent intent) {
    final status = controller.currentPlayerStatus;
    if (status is RhsPlayerStatusPlaying || status is RhsPlayerStatusLoading) {
      controller.pause();
    } else {
      controller.play();
    }
  }
}

// ==================== Seek Actions ====================

/// Action для перемотки назад
class SeekBackwardAction extends Action<SeekBackwardIntent> {
  final RhsPlayerController controller;

  SeekBackwardAction(this.controller);

  @override
  void invoke(SeekBackwardIntent intent) {
    final newPosition = controller.currentPosition - intent.step;
    controller.seekTo(
      newPosition > Duration.zero ? newPosition : Duration.zero,
    );
  }
}

/// Action для перемотки вперёд
class SeekForwardAction extends Action<SeekForwardIntent> {
  final RhsPlayerController controller;

  SeekForwardAction(this.controller);

  @override
  void invoke(SeekForwardIntent intent) {
    final newPosition = controller.currentPosition + intent.step;
    final duration = controller.currentPositionData.duration;
    controller.seekTo(newPosition < duration ? newPosition : duration);
  }
}

// ==================== Controls Visibility Actions ====================

/// Action для показа контролов
class ShowControlsAction extends Action<ShowControlsIntent> {
  final void Function({bool resetFocus}) onShowControls;

  ShowControlsAction(this.onShowControls);

  @override
  void invoke(ShowControlsIntent intent) {
    onShowControls(resetFocus: intent.resetFocus);
  }
}

/// Action для скрытия контролов
class HideControlsAction extends Action<HideControlsIntent> {
  final VoidCallback onHideControls;

  HideControlsAction(this.onHideControls);

  @override
  void invoke(HideControlsIntent intent) {
    onHideControls();
  }
}

/// Action для переключения видимости контролов
class ToggleControlsVisibilityAction
    extends Action<ToggleControlsVisibilityIntent> {
  final VoidCallback onToggleVisibility;

  ToggleControlsVisibilityAction(this.onToggleVisibility);

  @override
  void invoke(ToggleControlsVisibilityIntent intent) {
    onToggleVisibility();
  }
}

// ==================== Menu Actions ====================

/// Action для открытия меню качества
class OpenQualityMenuAction extends Action<OpenQualityMenuIntent> {
  final VoidCallback onOpenMenu;

  OpenQualityMenuAction(this.onOpenMenu);

  @override
  void invoke(OpenQualityMenuIntent intent) {
    onOpenMenu();
  }
}

/// Action для открытия меню аудиодорожки
class OpenSoundtrackMenuAction extends Action<OpenSoundtrackMenuIntent> {
  final VoidCallback onOpenMenu;

  OpenSoundtrackMenuAction(this.onOpenMenu);

  @override
  void invoke(OpenSoundtrackMenuIntent intent) {
    onOpenMenu();
  }
}
