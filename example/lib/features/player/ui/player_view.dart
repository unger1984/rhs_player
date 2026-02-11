import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/entities/media/model/media_item.dart';
import 'package:rhs_player_example/features/player/ui/controls/video_controls.dart';
import 'package:rhs_player_example/features/player/ui/subtitle_overlay.dart';
import 'package:rhs_player_example/shared/ui/widgets/buffering_overlay.dart';

/// Виджет плеера с контролами и оверлеем.
/// Инкапсулирует RhsPlayerView с VideoControls.
class PlayerView extends StatefulWidget {
  final RhsPlayerController controller;
  final List<MediaItem> recommendedItems;
  final void Function(MediaItem)? onItemSelected;
  final void Function(bool Function()?)? registerBackHandler;
  final VoidCallback? onBackButtonPressed;

  const PlayerView({
    super.key,
    required this.controller,
    required this.recommendedItems,
    this.onItemSelected,
    this.registerBackHandler,
    this.onBackButtonPressed,
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  /// Контролы видны (не скрыты). При false субтитры опускаются ниже.
  final ValueNotifier<bool> _controlsVisibleNotifier = ValueNotifier(true);

  /// Контролы раскрыты (карусель expanded). Субтитры сдвигаются выше.
  final ValueNotifier<bool> _controlsExpandedNotifier = ValueNotifier(false);

  @override
  void dispose() {
    _controlsVisibleNotifier.dispose();
    _controlsExpandedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RhsPlayerView(
      controller: widget.controller,
      boxFit: BoxFit.contain,
      overlay: Stack(
        children: [
          SubtitleOverlay(
            controller: widget.controller,
            controlsVisible: _controlsVisibleNotifier,
            controlsExpanded: _controlsExpandedNotifier,
          ),
          BufferingOverlay(controller: widget.controller),
          VideoControls(
            controller: widget.controller,
            onSwitchSource: () {}, // Placeholder
            onControlsVisibilityChanged: (visible) {
              _controlsVisibleNotifier.value = visible;
            },
            onControlsExpandedChanged: (expanded) {
              _controlsExpandedNotifier.value = expanded;
            },
            recommendedItems: widget.recommendedItems
                .map((e) => e.toCarouselItem())
                .toList(),
            initialRecommendedIndex: 0,
            onRecommendedItemActivated: (item) {
              // Найти MediaItem по source URL и вызвать callback
              final mediaItem = widget.recommendedItems.firstWhere(
                (e) => e.url == item.mediaSource?.url,
                orElse: () => widget.recommendedItems.first,
              );
              widget.onItemSelected?.call(mediaItem);
            },
            registerBackHandler: widget.registerBackHandler,
            onBackButtonPressed: widget.onBackButtonPressed,
          ),
        ],
      ),
    );
  }
}
