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
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
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
