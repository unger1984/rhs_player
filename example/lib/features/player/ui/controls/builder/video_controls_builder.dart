import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player_example/features/player/ui/actions/player_intents.dart';
import 'package:rhs_player_example/features/player/ui/controls/core/control_row.dart';
import 'package:rhs_player_example/features/player/ui/controls/navigation/navigation_manager.dart';

/// Callback'и навигации для элементов управления (фокус, перехват стрелок)
class VideoControlsNavigation extends InheritedWidget {
  const VideoControlsNavigation({
    super.key,
    required this.onNavigateUp,
    required this.onNavigateDown,
    required this.requestInitialFocus,
    required this.scheduleFocusRestore,
    required this.requestFocusOnId,
    required super.child,
  });

  final VoidCallback onNavigateUp;
  final VoidCallback onNavigateDown;

  /// Перевести фокус на начальный элемент.
  final VoidCallback requestInitialFocus;

  /// Запланировать восстановление фокуса на элемент с [id] после следующего обновления рядов.
  final void Function(String id) scheduleFocusRestore;

  /// Сразу перевести фокус на элемент с [id].
  final void Function(String id) requestFocusOnId;

  static VideoControlsNavigation? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<VideoControlsNavigation>();
  }

  @override
  bool updateShouldNotify(VideoControlsNavigation oldWidget) {
    return onNavigateUp != oldWidget.onNavigateUp ||
        onNavigateDown != oldWidget.onNavigateDown ||
        requestInitialFocus != oldWidget.requestInitialFocus ||
        scheduleFocusRestore != oldWidget.scheduleFocusRestore ||
        requestFocusOnId != oldWidget.requestFocusOnId;
  }
}

/// Колбэки навигации (фокус), передаются наружу через [onNavReady].
typedef NavCallbacks = ({
  void Function(String id) requestFocusOnId,
  void Function(String id) scheduleFocusRestore,
  void Function(FocusNode?) registerOverlayFocusNode,
  String? Function() getFocusedItemId,
});

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

  /// Видимость контролов (верхняя группа вверх, нижняя вниз при false).
  final bool controlsVisible;

  /// Показывать ряд с ProgressSlider (контролы открыты или идёт перемотка).
  final bool showProgressSlider;

  /// Вызывается при инициализации билдера; передаёт наружу [requestFocusOnId] и [scheduleFocusRestore],
  /// чтобы родитель мог переводить фокус (контекст родителя не видит VideoControlsNavigation).
  final void Function(NavCallbacks callbacks)? onNavReady;

  /// Вызывается при любом нажатии клавиши (для сброса таймера автоскрытия и показа контролов).
  final VoidCallback? onControlsInteraction;

  /// Вызывается при нажатии Info/Menu для переключения видимости контролов.
  final VoidCallback? onToggleVisibilityRequested;

  /// При скрытых контролах: влево/вправо вызывают перемотку.
  final VoidCallback? onSeekBackward;
  final VoidCallback? onSeekForward;

  /// Вызывается при нажатии Вниз, когда фокус на последнем ряду (карусель) — скрыть контролы.
  final VoidCallback? onHideControlsWhenDownFromLastRow;

  /// Key ряда карусели (для определения «клик вне карусели» в развёрнутом режиме).
  final GlobalKey? carouselRowKey;

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
    this.controlsVisible = true,
    this.showProgressSlider = true,
    this.onNavReady,
    this.onControlsInteraction,
    this.onToggleVisibilityRequested,
    this.onSeekBackward,
    this.onSeekForward,
    this.onHideControlsWhenDownFromLastRow,
    this.carouselRowKey,
  });

  @override
  State<VideoControlsBuilder> createState() => _VideoControlsBuilderState();
}

class _VideoControlsBuilderState extends State<VideoControlsBuilder> {
  late final NavigationManager _navigationManager;
  late final FocusNode _rootFocusNode;
  String? _pendingFocusRestoreId;

  /// Id элемента с фокусом перед скрытием контролов (для восстановления при показе).
  String? _focusedIdBeforeHide;

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode();
    _navigationManager = NavigationManager(
      rows: widget.rows,
      initialFocusNode: widget.initialFocusNode,
      initialFocusId: widget.initialFocusId,
      onDownFromLastRow: widget.onHideControlsWhenDownFromLastRow,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationManager.requestInitialFocus();
      widget.onNavReady?.call((
        requestFocusOnId: _navigationManager.requestFocusOnId,
        scheduleFocusRestore: (id) =>
            setState(() => _pendingFocusRestoreId = id),
        registerOverlayFocusNode: _navigationManager.setOverlayFocusNode,
        getFocusedItemId: _navigationManager.getFocusedItemId,
      ));
    });
  }

  @override
  void didUpdateWidget(covariant VideoControlsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onHideControlsWhenDownFromLastRow !=
        oldWidget.onHideControlsWhenDownFromLastRow) {
      _navigationManager.onDownFromLastRow =
          widget.onHideControlsWhenDownFromLastRow;
    }
    if (widget.rows != oldWidget.rows) {
      final idToRestore =
          _pendingFocusRestoreId ?? _navigationManager.getFocusedItemId();
      _pendingFocusRestoreId = null;
      _navigationManager.setRows(widget.rows);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigationManager.requestFocusOnId(idToRestore);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigationManager.requestFocusOnId(idToRestore);
        });
      });
    }
    // При скрытии контролов снимаем фокус с элемента и переносим на корень.
    // Делаем unfocus в первом кадре, requestFocus на корень — во втором, иначе фокус
    // после unfocus карусели/слайдера может перейти к другому дочернему элементу.
    if (widget.controlsVisible != oldWidget.controlsVisible) {
      if (!widget.controlsVisible) {
        _focusedIdBeforeHide = _navigationManager.getFocusedItemId();
        // Сразу переводим фокус на root, не дожидаясь postFrameCallback
        _rootFocusNode.requestFocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // Убеждаемся что фокус на root
          if (!_rootFocusNode.hasFocus) {
            _rootFocusNode.requestFocus();
          }
        });
      } else {
        final idToRestore = _focusedIdBeforeHide ?? widget.initialFocusId;
        _focusedIdBeforeHide = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _navigationManager.requestFocusOnId(idToRestore);
        });
      }
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
      requestFocusOnId: (id) => _navigationManager.requestFocusOnId(id),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // Показать контролы через Actions
          Actions.maybeInvoke<ShowControlsIntent>(
            context,
            const ShowControlsIntent(),
          );
        },
        onTapDown: (details) {
          // Показать контролы через Actions
          Actions.maybeInvoke<ShowControlsIntent>(
            context,
            const ShowControlsIntent(),
          );
          if (!widget.controlsVisible) return;
          if (widget.rows.length < 3) return;
          final carouselItemId = widget.rows.last.items.first.id;
          if (_navigationManager.getFocusedItemId() != carouselItemId) return;
          final key = widget.carouselRowKey;
          if (key?.currentContext == null) return;
          final box = key!.currentContext!.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.globalPosition);
          if (!box.size.contains(local)) {
            _navigationManager.requestInitialFocus();
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -500 &&
              widget.controlsVisible &&
              widget.rows.length > 2) {
            final lastRow = widget.rows.last;
            if (lastRow.items.isNotEmpty) {
              _navigationManager.requestFocusOnId(lastRow.items.first.id);
            }
          }
        },
        child: ExcludeFocus(
          excluding: !widget.controlsVisible,
          child: FocusScope(
            child: Focus(
              focusNode: _rootFocusNode,
              onKeyEvent: (FocusNode node, KeyEvent event) {
                // Любое нажатие клавиши при видимых контролах сбрасывает таймер автоскрытия
                if (event is KeyDownEvent && widget.controlsVisible) {
                  widget.onControlsInteraction?.call();
                }

                // Обработка клавиш делегирована Shortcuts/Actions (выше в дереве).
                // Здесь только навигация между элементами через NavigationManager.
                return _navigationManager.handleKey(
                  node,
                  event,
                  controlsVisible: widget.controlsVisible,
                );
              },
              child: Container(
                color: widget.backgroundColor ?? Colors.transparent,
                padding: widget.padding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: widget.crossAxisAlignment,
                  children: [
                    if (widget.rows.isNotEmpty) ...[
                      AnimatedSlide(
                        offset: Offset(0, widget.controlsVisible ? 0 : -1),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: widget.rows.first.build(context),
                      ),
                      const Spacer(),
                      if (widget.showProgressSlider && widget.rows.length > 1)
                        AnimatedSlide(
                          offset: Offset.zero,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: widget.rows[1].build(context),
                        ),
                      if (widget.rows.length > 2) ...[
                        SizedBox(height: widget.spacing.h),
                        AnimatedSlide(
                          offset: Offset(0, widget.controlsVisible ? 0 : 1),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: widget.crossAxisAlignment,
                            children: [
                              for (var i = 2; i < widget.rows.length; i++) ...[
                                if (i > 2) SizedBox(height: widget.spacing.h),
                                widget.rows[i].build(context),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
