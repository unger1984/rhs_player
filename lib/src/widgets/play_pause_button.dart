import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

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
  /// Намерение пользователя: null = следовать за isPlaying, true = показывать pause, false = показывать play
  bool? _userIntent;
  bool _wasBuffering = false;

  @override
  void initState() {
    super.initState();
    _checkEvents();
  }

  void _checkEvents() {
    final events = widget.controller.events;
    if (events != null && _events != events) {
      if (_events != null) {
        _events!.state.removeListener(_onStateChanged);
      }
      _events = events;
      events.state.addListener(_onStateChanged);
      _onStateChanged();
    } else if (events == null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _checkEvents();
      });
    }
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = _events?.state.value;
    if (state == null) return;

    setState(() {
      // Когда буферизация заканчивается — синхронизируем intent с реальным состоянием
      if (_wasBuffering && !state.isBuffering) {
        _userIntent = state.isPlaying;
      }
      _wasBuffering = state.isBuffering;
    });
  }

  @override
  void dispose() {
    _events?.state.removeListener(_onStateChanged);
    super.dispose();
  }

  bool get _showAsPlaying {
    // Если есть намерение пользователя — показываем его
    if (_userIntent != null) return _userIntent!;
    // Иначе следуем за реальным isPlaying
    return _events?.state.value.isPlaying ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_showAsPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 64),
      onPressed: () {
        widget.onInteraction?.call();
        final currentIsPlaying = _showAsPlaying;
        // Запоминаем намерение пользователя
        setState(() {
          _userIntent = !currentIsPlaying;
        });
        // Вызываем соответствующее действие
        if (currentIsPlaying) {
          widget.controller.pause();
        } else {
          widget.controller.play();
        }
      },
    );
  }
}
