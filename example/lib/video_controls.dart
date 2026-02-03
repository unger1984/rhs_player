import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/play_pause_control_button.dart';
import 'package:rhs_player_example/controls/builder/video_controls_builder.dart';
import 'package:rhs_player_example/controls/core/key_handling_result.dart';
import 'package:rhs_player_example/controls/items/button_item.dart';
import 'package:rhs_player_example/controls/items/custom_widget_item.dart';
import 'package:rhs_player_example/controls/items/quality_selector_item.dart';
import 'package:rhs_player_example/controls/items/soundtrack_selector_item.dart';
import 'package:rhs_player_example/controls/items/progress_slider_item.dart';
import 'package:rhs_player_example/controls/rows/full_width_row.dart';
import 'package:rhs_player_example/controls/rows/recommended_carousel_row.dart';
import 'package:rhs_player_example/controls/rows/three_zone_button_row.dart';
import 'package:rhs_player_example/controls/rows/top_bar_row.dart';

/// Виджет управления видео с поддержкой Android TV пульта
/// Использует новую систему навигации с Chain of Responsibility паттерном
class VideoControls extends StatefulWidget {
  final RhsPlayerController controller;
  final VoidCallback onSwitchSource;
  final VoidCallback? onFavoritePressed;
  final List<RecommendedCarouselItem> recommendedItems;
  final int initialRecommendedIndex;
  final void Function(int index)? onRecommendedScrollIndexChanged;
  final void Function(RecommendedCarouselItem item)? onRecommendedItemActivated;

  const VideoControls({
    super.key,
    required this.controller,
    required this.onSwitchSource,
    required this.recommendedItems,
    this.onFavoritePressed,
    this.initialRecommendedIndex = 0,
    this.onRecommendedScrollIndexChanged,
    this.onRecommendedItemActivated,
  });

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  /// Колбэки навигации из билдера (родительский context не видит VideoControlsNavigation).
  NavCallbacks? _nav;

  /// Показывать кнопку качества только после загрузки видеотреков.
  bool _hasVideoTracks = false;
  VoidCallback? _removeVideoTracksListener;

  @override
  void initState() {
    super.initState();
    _removeVideoTracksListener = widget.controller.addVideoTracksListener((
      tracks,
    ) {
      if (mounted) {
        setState(() => _hasVideoTracks = tracks.isNotEmpty);
      }
    });
  }

  @override
  void dispose() {
    _removeVideoTracksListener?.call();
    super.dispose();
  }

  Widget _buildBufferingOverlay() {
    return StreamBuilder<RhsPlayerStatus>(
      stream: widget.controller.playerStatusStream,
      builder: (context, snapshot) {
        if (snapshot.data is RhsPlayerStatusLoading) {
          return Center(
            child: SizedBox(
              width: 80.r,
              height: 80.r,
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildBufferingOverlay(),
        VideoControlsBuilder(
          initialFocusId: 'play_pause_button',
          onNavReady: (callbacks) => _nav = callbacks,
          rows: [
            TopBarRow(
              id: 'top_bar_row',
              index: 0,
              height: 124,
              backgroundColor: const Color(0xCC201B2E),
              horizontalPadding: 120,
              title: 'Тут будет название фильма',
              leftItems: [
                ButtonItem(
                  id: 'back_button',
                  onPressed: () => Navigator.of(context).pop(),
                  buttonSize: 76,
                  buttonBorderRadius: 16,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(left: 5.w),
                      child: Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                  ),
                ),
              ],
              rightItems: [
                CustomWidgetItem(
                  id: 'soundtrack_selector',
                  builder: (focusNode) => SoundtrackSelectorItem(
                    controller: widget.controller,
                    focusNode: focusNode,
                    onRegisterOverlayFocus: _nav?.registerOverlayFocusNode,
                  ),
                ),
              ],
            ),
            FullWidthRow(
              id: 'progress_row',
              index: 1,
              padding: EdgeInsets.symmetric(horizontal: 120.w),
              items: [
                ProgressSliderItem(
                  id: 'progress_slider',
                  controller: widget.controller,
                  onSeekBackward: _seekBackward,
                  onSeekForward: _seekForward,
                ),
              ],
            ),
            ThreeZoneButtonRow(
              id: 'control_buttons_row',
              index: 2,
              spacing: 32,
              leftItems: [
                ButtonItem(
                  id: 'favorite_button',
                  onPressed: widget.onFavoritePressed ?? () {},
                  child: Center(
                    child: SizedBox(
                      width: 56.w,
                      height: 56.h,
                      child: ImageIcon(AssetImage('assets/controls/like.png')),
                    ),
                  ),
                ),
              ],
              centerItems: [
                ButtonItem(
                  id: 'rewind_button',
                  onPressed: _seekBackward,
                  repeatWhileHeld: true,
                  child: Center(
                    child: SizedBox(
                      width: 56.w,
                      height: 56.h,
                      child: ImageIcon(
                        AssetImage('assets/controls/rewind_L.png'),
                      ),
                    ),
                  ),
                ),
                CustomWidgetItem(
                  id: 'play_pause_button',
                  keyHandler: (event) {
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.enter)) {
                      _togglePlayPause();
                      return KeyHandlingResult.handled;
                    }
                    return KeyHandlingResult.notHandled;
                  },
                  builder: (focusNode) => StreamBuilder<RhsPlayerStatus>(
                    stream: widget.controller.playerStatusStream,
                    builder: (context, snapshot) {
                      final status = snapshot.data;
                      final isPlaying =
                          status is RhsPlayerStatusPlaying ||
                          status is RhsPlayerStatusLoading;
                      return PlayPauseControlButton(
                        focusNode: focusNode,
                        isPlaying: isPlaying,
                        onPressed: _togglePlayPause,
                      );
                    },
                  ),
                ),
                ButtonItem(
                  id: 'forward_button',
                  onPressed: _seekForward,
                  repeatWhileHeld: true,
                  child: Center(
                    child: SizedBox(
                      width: 56.w,
                      height: 56.h,
                      child: ImageIcon(
                        AssetImage('assets/controls/rewind_R.png'),
                      ),
                    ),
                  ),
                ),
              ],
              rightItems: _hasVideoTracks
                  ? [
                      CustomWidgetItem(
                        id: 'quality_selector',
                        builder: (focusNode) => QualitySelectorItem(
                          controller: widget.controller,
                          focusNode: focusNode,
                          onRegisterOverlayFocus:
                              _nav?.registerOverlayFocusNode,
                        ),
                      ),
                    ]
                  : [],
            ),
            RecommendedCarouselRow(
              id: 'recommended_row',
              index: 3,
              carouselItems: widget.recommendedItems,
              initialScrollIndex: widget.initialRecommendedIndex,
              onItemSelected: widget.onRecommendedScrollIndexChanged,
              onItemActivated: widget.onRecommendedItemActivated == null
                  ? null
                  : (item) {
                      final requestFocus = _nav?.requestFocusOnId;
                      final scheduleRestore = _nav?.scheduleFocusRestore;
                      scheduleRestore?.call('play_pause_button');
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        requestFocus?.call('play_pause_button');
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            widget.onRecommendedItemActivated!(item);
                          });
                        });
                      });
                    },
            ),
          ],
        ),
      ],
    );
  }

  void _seekBackward() {
    final newPosition =
        widget.controller.currentPosition - const Duration(seconds: 10);
    widget.controller.seekTo(
      newPosition > Duration.zero ? newPosition : Duration.zero,
    );
  }

  void _seekForward() {
    final newPosition =
        widget.controller.currentPosition + const Duration(seconds: 10);
    final duration = widget.controller.currentPositionData.duration;
    widget.controller.seekTo(newPosition < duration ? newPosition : duration);
  }

  void _togglePlayPause() {
    final status = widget.controller.currentPlayerStatus;
    if (status is RhsPlayerStatusPlaying || status is RhsPlayerStatusLoading) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
  }
}
