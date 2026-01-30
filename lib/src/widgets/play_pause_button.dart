import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

class PlayPauseButton extends StatefulWidget {
  final RhsPlayerController controller;

  const PlayPauseButton({super.key, required this.controller});

  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton> {
  RhsNativeEvents? _events;
  bool? _optimisticState;

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
      // Слушаем изменения состояния
      events.state.addListener(_onStateChanged);
      _onStateChanged();
    } else if (events == null) {
      // Если события еще не готовы, проверяем периодически
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _checkEvents();
        }
      });
    }
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {
      // Сбрасываем оптимистичное состояние, когда реальное состояние обновилось
      final realIsPlaying = _events?.state.value.isPlaying ?? false;
      if (_optimisticState != null && _optimisticState == realIsPlaying) {
        _optimisticState = null;
      }
    });
  }

  @override
  void dispose() {
    _events?.state.removeListener(_onStateChanged);
    super.dispose();
  }

  bool get _isPlaying {
    // Используем оптимистичное состояние, если оно есть, иначе реальное
    if (_optimisticState != null) {
      return _optimisticState!;
    }
    return _events?.state.value.isPlaying ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 64),
      onPressed: () {
        final currentIsPlaying = _isPlaying;
        // Оптимистично обновляем состояние сразу
        setState(() {
          _optimisticState = !currentIsPlaying;
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
