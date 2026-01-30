import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

class ProgressBar extends StatelessWidget {
  final RhsPlaybackState state;
  final RhsPlayerController controller;
  final String Function(Duration) formatDuration;

  const ProgressBar({super.key, required this.state, required this.controller, required this.formatDuration});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Фоновая дорожка и буферизованная область с отступами как у Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Stack(
                    children: [
                      // Фоновая дорожка (не загружено)
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      // Буферизованная область (загружено)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final totalWidth = constraints.maxWidth;
                          final duration = state.duration.inMilliseconds.toDouble().clamp(1, double.infinity);
                          final bufferedWidth = (state.bufferedPosition.inMilliseconds / duration * totalWidth).clamp(0.0, totalWidth);
                          return Container(
                            height: 2,
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
                // Слайдер для текущей позиции
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    min: 0,
                    max: state.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    value: state.position.inMilliseconds.clamp(0, state.duration.inMilliseconds).toDouble(),
                    onChanged: (value) {
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
