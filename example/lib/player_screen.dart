import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

import 'package:rhs_player_example/video_controls.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlayerScreenContent();
  }
}

class _PlayerScreenContent extends StatefulWidget {
  const _PlayerScreenContent();

  @override
  State<_PlayerScreenContent> createState() => _PlayerScreenContentState();
}

class _PlayerScreenContentState extends State<_PlayerScreenContent> {
  int _recommendedCarouselIndex = 0;

  final media0 = RhsMediaSource(
    "https://user67561.nowcdn.co/done/widevine_playready/06bff34bc0fed90c578b72d72905680ae9b29e29/index.mpd",
    drm: const RhsDrmConfig(
      type: RhsDrmType.widevine,
      licenseUrl: 'https://drm93075.nowdrm.co/widevine',
    ),
  );
  final media1 = RhsMediaSource(
    "https://user67561.nowcdn.co/done/widevine_playready/7c6be93192a4888f3491f46fee3dbcb57c77bd08/index.mpd",
    drm: const RhsDrmConfig(
      type: RhsDrmType.widevine,
      licenseUrl: 'https://drm93075.nowdrm.co/widevine',
    ),
  );
  final media2 = RhsMediaSource(
    "https://user67561.nowcdn.co/done/widevine_playready/34b23ff04263fd82a6e8f2a096b2771ba5bd4de9/index.mpd",
    drm: const RhsDrmConfig(
      type: RhsDrmType.widevine,
      licenseUrl: 'https://drm93075.nowdrm.co/widevine',
    ),
  );
  int _vid = 0;
  late RhsPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = RhsPlayerController.single(media0);

    controller.addStatusListener((status) {
      if (status is RhsPlayerStatusError) {
        print('EVENT PLAYER ERROR: ${status.message}');
      } else {
        print('EVENT PLAYER STATUS: $status');
      }
    });

    controller.addPositionDataListener((data) {
      print('EVENT POSITION DATA: ${data.position} / ${data.duration}');
    });

    controller.addBufferedPositionListener((position) {
      print('EVENT BUFFERED: $position');
    });

    controller.addVideoTracksListener((tracks) {
      final trackLabels = tracks.map((t) => t.displayLabel).join(', ');
      print('EVENT VIDEO TRACKS: [$trackLabels]');
    });

    controller.addAudioTracksListener((tracks) {
      final trackLabels = tracks.map((t) => t.label).join(', ');
      print('EVENT AUDIO TRACKS: [$trackLabels]');
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleChange() {
    if (_vid == 1) {
      controller.loadMediaSource(media2);
      setState(() {
        _vid = 2;
      });
    } else {
      controller.loadMediaSource(media1);
      setState(() {
        _vid = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: RhsPlayerView(
            controller: controller,
            boxFit: BoxFit.contain,
            overlay: VideoControls(
              controller: controller,
              onSwitchSource: _handleChange,
              initialRecommendedIndex: _recommendedCarouselIndex,
              onRecommendedScrollIndexChanged: (index) {
                setState(() => _recommendedCarouselIndex = index);
              },
            ),
          ),
        ),
      ),
    );
  }
}
