import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

import '../theme/player_style.dart';

class PlayPauseButton extends StatefulWidget {
  final RhsPlayerController controller;
  final RhsPlaybackState state;
  final VoidCallback? onInteraction;

  const PlayPauseButton({
    super.key,
    required this.controller,
    required this.state,
    this.onInteraction,
  });

  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton> {
  RhsNativeEvents? _events;
  StreamSubscription<RhsNativeEvents?>? _eventsSubscription;
  bool? _userIntent;
  bool _wasBuffering = false;

  @override
  void initState() {
    super.initState();
    _eventsSubscription = widget.controller.eventsStream.listen((events) {
      if (!mounted) return;
      if (_events != events) {
        _events?.state.removeListener(_onStateChanged);
        _events = events;
        if (events != null) {
          events.state.addListener(_onStateChanged);
        }
        _onStateChanged();
      }
    });
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = _events?.state.value;
    if (state == null) return;

    setState(() {
      // Синхронизируем с фактическим состоянием (пауза/play с пульта или извне).
      if (!state.isBuffering) {
        _userIntent = state.isPlaying;
      }
      _wasBuffering = state.isBuffering;
    });
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _events?.state.removeListener(_onStateChanged);
    super.dispose();
  }

  bool get _showAsPlaying {
    final state = _events?.state.value;
    if (state == null) return false;
    // Во время буферизации показываем намерение пользователя, иначе — фактическое состояние.
    if (state.isBuffering) return _userIntent ?? state.isPlaying;
    return state.isPlaying;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _showAsPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
        color: Colors.white,
        size: PlayerStyle.playPauseIconSize,
      ),
      onPressed: () {
        widget.onInteraction?.call();
        final currentIsPlaying = _showAsPlaying;
        setState(() {
          _userIntent = !currentIsPlaying;
        });
        if (currentIsPlaying) {
          widget.controller.pause();
        } else {
          widget.controller.play();
        }
      },
    );
  }
}
