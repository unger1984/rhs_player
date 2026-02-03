import 'package:flutter/material.dart';
import 'package:rhs_player_example/controls/core/control_row.dart';
import 'package:rhs_player_example/controls/navigation/navigation_manager.dart';

/// Билдер для декларативного построения системы управления
class VideoControlsBuilder extends StatefulWidget {
  final List<ControlRow> rows;
  final FocusNode? initialFocusNode;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  const VideoControlsBuilder({
    super.key,
    required this.rows,
    this.initialFocusNode,
    this.backgroundColor,
    this.padding,
    this.mainAxisAlignment = MainAxisAlignment.end,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.spacing = 20,
  });

  @override
  State<VideoControlsBuilder> createState() => _VideoControlsBuilderState();
}

class _VideoControlsBuilderState extends State<VideoControlsBuilder> {
  late final NavigationManager _navigationManager;
  late final FocusNode _rootFocusNode;

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode();
    _navigationManager = NavigationManager(
      rows: widget.rows,
      initialFocusNode: widget.initialFocusNode,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationManager.requestInitialFocus();
    });
  }

  @override
  void dispose() {
    _navigationManager.dispose();
    _rootFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _rootFocusNode,
      onKeyEvent: _navigationManager.handleKey,
      child: Container(
        color: widget.backgroundColor ?? Colors.black.withAlpha(128),
        padding: widget.padding,
        child: Column(
          mainAxisAlignment: widget.mainAxisAlignment,
          crossAxisAlignment: widget.crossAxisAlignment,
          children: [
            for (var i = 0; i < widget.rows.length; i++) ...[
              widget.rows[i].build(context),
              if (i < widget.rows.length - 1) SizedBox(height: widget.spacing),
            ],
          ],
        ),
      ),
    );
  }
}
