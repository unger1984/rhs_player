import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

import '../theme/player_style.dart';

class ProgressBar extends StatelessWidget {
  final RhsPlaybackState state;
  final RhsPlayerController controller;
  final String Function(Duration) formatDuration;
  final VoidCallback? onInteraction;

  const ProgressBar({
    super.key,
    required this.state,
    required this.controller,
    required this.formatDuration,
    this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          SizedBox(
            height: PlayerStyle.progressBarHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PlayerStyle.progressBarHorizontalPadding,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        height: PlayerStyle.progressTrackHeight,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final totalWidth = constraints.maxWidth;
                          final duration = state.duration.inMilliseconds
                              .toDouble()
                              .clamp(1, double.infinity);
                          final bufferedWidth = (state.bufferedPosition
                                      .inMilliseconds /
                                  duration *
                                  totalWidth)
                              .clamp(0.0, totalWidth);
                          return Container(
                            height: PlayerStyle.progressTrackHeight,
                            width: bufferedWidth,
                            decoration: BoxDecoration(
                              color: Colors.white38,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: PlayerStyle.progressTrackHeight,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: PlayerStyle.sliderThumbRadius,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                    overlayShape: RoundSliderOverlayShape(
                      overlayRadius: PlayerStyle.sliderOverlayRadius,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: state.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    value: state.position.inMilliseconds.clamp(0, state.duration.inMilliseconds).toDouble(),
                    onChanged: (value) {
                      onInteraction?.call();
                      controller.seekTo(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(state.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
              Text(formatDuration(state.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
