import 'package:flutter/material.dart';
import 'package:rhs_player_example/controls/core/control_row.dart';
import 'package:rhs_player_example/controls/navigation/navigation_manager.dart';

/// Callback'и навигации для элементов управления (фокус, перехват стрелок)
class VideoControlsNavigation extends InheritedWidget {
  const VideoControlsNavigation({
    super.key,
    required this.onNavigateUp,
    required this.onNavigateDown,
    required this.requestInitialFocus,
    required this.scheduleFocusRestore,
    required super.child,
  });

  final VoidCallback onNavigateUp;
  final VoidCallback onNavigateDown;

  /// Перевести фокус на начальный элемент.
  final VoidCallback requestInitialFocus;

  /// Запланировать восстановление фокуса на элемент с [id] после следующего обновления рядов.
  final void Function(String id) scheduleFocusRestore;

  static VideoControlsNavigation? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<VideoControlsNavigation>();
  }

  @override
  bool updateShouldNotify(VideoControlsNavigation oldWidget) {
    return onNavigateUp != oldWidget.onNavigateUp ||
        onNavigateDown != oldWidget.onNavigateDown ||
        requestInitialFocus != oldWidget.requestInitialFocus ||
        scheduleFocusRestore != oldWidget.scheduleFocusRestore;
  }
}

/// Билдер для декларативного построения системы управления
class VideoControlsBuilder extends StatefulWidget {
  final List<ControlRow> rows;
  final FocusNode? initialFocusNode;
  final String? initialFocusId;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  const VideoControlsBuilder({
    super.key,
    required this.rows,
    this.initialFocusNode,
    this.initialFocusId,
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
  String? _pendingFocusRestoreId;

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode();
    _navigationManager = NavigationManager(
      rows: widget.rows,
      initialFocusNode: widget.initialFocusNode,
      initialFocusId: widget.initialFocusId,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationManager.requestInitialFocus();
    });
  }

  @override
  void didUpdateWidget(covariant VideoControlsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rows != oldWidget.rows) {
      final idToRestore =
          _pendingFocusRestoreId ?? _navigationManager.getFocusedItemId();
      _pendingFocusRestoreId = null;
      _navigationManager.setRows(widget.rows);
      _navigationManager.requestFocusOnId(idToRestore);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigationManager.requestFocusOnId(idToRestore);
      });
    }
  }

  @override
  void dispose() {
    _navigationManager.dispose();
    _rootFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VideoControlsNavigation(
      onNavigateUp: () => _navigationManager.navigateUp(null),
      onNavigateDown: () => _navigationManager.navigateDown(null),
      requestInitialFocus: () => _navigationManager.requestInitialFocus(),
      scheduleFocusRestore: (id) => setState(() => _pendingFocusRestoreId = id),
      child: FocusScope(
        child: Focus(
          focusNode: _rootFocusNode,
          onKeyEvent: _navigationManager.handleKey,
          child: Container(
            color: widget.backgroundColor ?? Colors.black.withAlpha(128),
            padding: widget.padding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: widget.crossAxisAlignment,
              children: [
                if (widget.rows.isNotEmpty) ...[
                  widget.rows.first.build(context),
                  const Spacer(),
                  for (var i = 1; i < widget.rows.length; i++) ...[
                    if (i > 1) SizedBox(height: widget.spacing),
                    widget.rows[i].build(context),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
