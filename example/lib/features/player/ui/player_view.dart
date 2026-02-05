import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/entities/media/model/media_item.dart';
import 'package:rhs_player_example/features/player/ui/controls/video_controls.dart';
import 'package:rhs_player_example/shared/ui/widgets/buffering_overlay.dart';

/// Виджет плеера с контролами и оверлеем.
/// Инкапсулирует RhsPlayerView с VideoControls.
class PlayerView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return RhsPlayerView(
      controller: controller,
      boxFit: BoxFit.contain,
      overlay: Stack(
        children: [
          BufferingOverlay(controller: controller),
          VideoControls(
            controller: controller,
            onSwitchSource: () {}, // Placeholder
            recommendedItems: recommendedItems
                .map((e) => e.toCarouselItem())
                .toList(),
            initialRecommendedIndex: 0,
            onRecommendedItemActivated: (item) {
              // Найти MediaItem по source URL и вызвать callback
              final mediaItem = recommendedItems.firstWhere(
                (e) => e.url == item.mediaSource?.url,
                orElse: () => recommendedItems.first,
              );
              onItemSelected?.call(mediaItem);
            },
            registerBackHandler: registerBackHandler,
            onBackButtonPressed: onBackButtonPressed,
          ),
        ],
      ),
    );
  }
}
