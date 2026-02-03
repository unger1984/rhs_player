import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/progress_slider.dart';
import 'package:rhs_player_example/controls_row.dart';

/// Виджет управления видео с поддержкой Android TV пульта
class VideoControls extends StatefulWidget {
  final RhsPlayerController controller;
  final VoidCallback onSwitchSource;

  const VideoControls({
    super.key,
    required this.controller,
    required this.onSwitchSource,
  });

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  late final FocusNode _sliderFocusNode;
  late final FocusNode _rewindButtonFocusNode;
  late final FocusNode _playButtonFocusNode;
  late final FocusNode _forwardButtonFocusNode;
  late final FocusNode _switchButtonFocusNode;
  late final FocusNode _rootFocusNode;

  @override
  void initState() {
    super.initState();
    _sliderFocusNode = FocusNode();
    _rewindButtonFocusNode = FocusNode();
    _playButtonFocusNode = FocusNode();
    _forwardButtonFocusNode = FocusNode();
    _switchButtonFocusNode = FocusNode();
    _rootFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sliderFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _sliderFocusNode.dispose();
    _rewindButtonFocusNode.dispose();
    _playButtonFocusNode.dispose();
    _forwardButtonFocusNode.dispose();
    _switchButtonFocusNode.dispose();
    _rootFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _rootFocusNode,
      onKeyEvent: _handleNavigation,
      child: Container(
        color: Colors.black.withAlpha(128),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ProgressSlider(
              controller: widget.controller,
              focusNode: _sliderFocusNode,
              onSeekBackward: _seekBackward,
              onSeekForward: _seekForward,
            ),
            ControlsRow(
              controller: widget.controller,
              onSwitchSource: widget.onSwitchSource,
              rewindFocusNode: _rewindButtonFocusNode,
              playFocusNode: _playButtonFocusNode,
              forwardFocusNode: _forwardButtonFocusNode,
              switchFocusNode: _switchButtonFocusNode,
              onSeekBackward: _seekBackward,
              onSeekForward: _seekForward,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  KeyEventResult _handleNavigation(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus == null) {
      _sliderFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        return _handleArrowDown(currentFocus);
      case LogicalKeyboardKey.arrowUp:
        return _handleArrowUp(currentFocus);
      case LogicalKeyboardKey.arrowLeft:
        return _handleArrowLeft(currentFocus);
      case LogicalKeyboardKey.arrowRight:
        return _handleArrowRight(currentFocus);
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleArrowDown(FocusNode currentFocus) {
    if (currentFocus == _sliderFocusNode) {
      _playButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleArrowUp(FocusNode currentFocus) {
    if (currentFocus == _rewindButtonFocusNode ||
        currentFocus == _playButtonFocusNode ||
        currentFocus == _forwardButtonFocusNode ||
        currentFocus == _switchButtonFocusNode) {
      _sliderFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleArrowLeft(FocusNode currentFocus) {
    if (currentFocus == _playButtonFocusNode) {
      _rewindButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    } else if (currentFocus == _forwardButtonFocusNode) {
      _playButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    } else if (currentFocus == _switchButtonFocusNode) {
      _forwardButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleArrowRight(FocusNode currentFocus) {
    if (currentFocus == _rewindButtonFocusNode) {
      _playButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    } else if (currentFocus == _playButtonFocusNode) {
      _forwardButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    } else if (currentFocus == _forwardButtonFocusNode) {
      _switchButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
}
