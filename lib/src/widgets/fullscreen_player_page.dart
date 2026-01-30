import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rxdart/rxdart.dart';

/// Снапшот для объединённого стрима событий и состояния.
class _FullscreenSnapshot {
  final dynamic events;
  final RhsPlaybackState state;

  _FullscreenSnapshot(this.events, this.state);
}

/// Полноэкранная страница воспроизведения.
class FullscreenPlayerPage extends StatefulWidget {
  final RhsPlayerController controller;
  final String Function(Duration) formatDuration;
  final Duration? controlsHideAfter;
  final int? initialFocusIndex;

  const FullscreenPlayerPage({
    super.key,
    required this.controller,
    required this.formatDuration,
    this.controlsHideAfter,
    this.initialFocusIndex,
  });

  @override
  State<FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<FullscreenPlayerPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: Stack(
          children: [
            RhsPlayerView(
              controller: widget.controller,
              boxFit: BoxFit.contain,
            ),
            StreamBuilder<_FullscreenSnapshot>(
              stream: Rx.combineLatest2<RhsNativeEvents?, RhsPlaybackState,
                  _FullscreenSnapshot>(
                widget.controller.eventsStream,
                widget.controller.playbackStateStream,
                (events, state) => _FullscreenSnapshot(events, state),
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final data = snapshot.data!;
                if (data.events == null) {
                  return const SizedBox.shrink();
                }
                final state = data.state;
                return PlayerControls(
                  controller: widget.controller,
                  state: state,
                  formatDuration: widget.formatDuration,
                  controlsHideAfter: widget.controlsHideAfter,
                  isFullscreen: true,
                  initialFocusIndex: widget.initialFocusIndex,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
