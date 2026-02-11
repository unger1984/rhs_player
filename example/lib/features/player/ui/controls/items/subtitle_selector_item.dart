import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/shared/ui/theme/app_colors.dart';
import 'package:rhs_player_example/shared/ui/theme/app_sizes.dart';
import 'package:rhs_player_example/shared/ui/theme/focus_decoration.dart';

const double _kMenuBorderRadius = AppSizes.buttonBorderRadius;
const double _kButtonBorderRadius = AppSizes.buttonBorderRadius;
const double _kButtonHeight = 76;

String _trackLabel(RhsSubtitleTrack t) => t.language ?? t.label ?? t.id;

/// Диалог выбора субтитров. Пункт «Выкл» + список треков.
class _SubtitleMenuDialog extends StatefulWidget {
  final List<RhsSubtitleTrack> tracks;
  final String? selectedTrackId;
  final Offset anchorTopLeft;
  final Size anchorSize;
  final void Function(FocusNode?)? onRegisterOverlayFocus;

  const _SubtitleMenuDialog({
    required this.tracks,
    required this.selectedTrackId,
    required this.anchorTopLeft,
    required this.anchorSize,
    this.onRegisterOverlayFocus,
  });

  @override
  State<_SubtitleMenuDialog> createState() => _SubtitleMenuDialogState();
}

class _SubtitleMenuDialogState extends State<_SubtitleMenuDialog> {
  late int _focusedIndex;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.onRegisterOverlayFocus?.call(_focusNode);
    final idx = widget.selectedTrackId == null
        ? 0
        : widget.tracks.indexWhere(
            (t) => t.id == widget.selectedTrackId || t.selected,
          );
    _focusedIndex = idx >= 0 ? idx : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusNode.requestFocus();
        });
      });
    });
  }

  @override
  void dispose() {
    widget.onRegisterOverlayFocus?.call(null);
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        if (_focusedIndex < widget.tracks.length) {
          setState(() => _focusedIndex++);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.arrowUp:
        if (_focusedIndex > 0) {
          setState(() => _focusedIndex--);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        // '' = выкл, иначе id трека
        final id = _focusedIndex == 0
            ? ''
            : widget.tracks[_focusedIndex - 1].id;
        Navigator.of(context).pop(id);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        Navigator.of(context).pop();
        return KeyEventResult.ignored;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuTop = widget.anchorTopLeft.dy + widget.anchorSize.height + 4.r;

    return FocusScope(
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Positioned(
              left: widget.anchorTopLeft.dx,
              top: menuTop,
              width: widget.anchorSize.width,
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKey,
                child: Material(
                  color: AppColors.buttonBgNormal,
                  borderRadius: BorderRadius.circular(_kMenuBorderRadius.r),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _SubtitleMenuItem(
                        label: 'Выкл',
                        isSelected: widget.selectedTrackId == null,
                        hasFocus: _focusedIndex == 0,
                        onTap: () => Navigator.of(context).pop(''),
                      ),
                      for (var i = 0; i < widget.tracks.length; i++)
                        _SubtitleMenuItem(
                          label: _trackLabel(widget.tracks[i]),
                          isSelected:
                              widget.tracks[i].id == widget.selectedTrackId ||
                              widget.tracks[i].selected,
                          hasFocus: i + 1 == _focusedIndex,
                          onTap: () =>
                              Navigator.of(context).pop(widget.tracks[i].id),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtitleMenuItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool hasFocus;
  final VoidCallback onTap;

  const _SubtitleMenuItem({
    required this.label,
    required this.isSelected,
    required this.hasFocus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: hasFocus ? AppColors.buttonBgHover : null,
          borderRadius: BorderRadius.circular(_kMenuBorderRadius.r),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected || hasFocus ? Colors.white : Colors.white70,
            fontSize: 32.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Кнопка выбора субтитров. Аналог SoundtrackSelectorItem.
class SubtitleSelectorItem extends StatefulWidget {
  final RhsPlayerController controller;
  final FocusNode focusNode;
  final void Function(FocusNode?)? onRegisterOverlayFocus;
  final VoidCallback? onMenuOpened;
  final VoidCallback? onMenuClosed;

  const SubtitleSelectorItem({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onRegisterOverlayFocus,
    this.onMenuOpened,
    this.onMenuClosed,
  });

  @override
  State<SubtitleSelectorItem> createState() => _SubtitleSelectorItemState();
}

class _SubtitleSelectorItemState extends State<SubtitleSelectorItem> {
  bool _pressed = false;
  bool _hovered = false;

  String _currentLabel(List<RhsSubtitleTrack> tracks, String? selectedId) {
    if (selectedId == null) return 'Выкл';
    final selected = tracks.firstWhereOrNull((t) => t.id == selectedId);
    if (selected != null) return _trackLabel(selected);
    return 'Выкл';
  }

  Future<void> _openMenu() async {
    final tracks = await widget.controller.getSubtitleTracks();
    if (!mounted) return;

    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final position = box.localToGlobal(Offset.zero, ancestor: overlay);
    final size = box.size;
    final selectedId = tracks.firstWhereOrNull((t) => t.selected)?.id;

    widget.onMenuOpened?.call();

    // '' = выкл, non-empty = id трека, null = отмена
    final selected = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => _SubtitleMenuDialog(
        tracks: tracks,
        selectedTrackId: selectedId,
        anchorTopLeft: position,
        anchorSize: size,
        onRegisterOverlayFocus: widget.onRegisterOverlayFocus,
      ),
    );

    widget.onMenuClosed?.call();

    if (selected != null && mounted) {
      await widget.controller.selectSubtitleTrack(
        selected.isEmpty ? null : selected,
      );
      widget.focusNode.unfocus();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = widget.controller.subtitleTracks;
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (event is KeyDownEvent) {
            setState(() => _pressed = true);
            _openMenu();
            return KeyEventResult.handled;
          }
          if (event is KeyUpEvent) {
            setState(() => _pressed = false);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _openMenu,
          child: Builder(
            builder: (context) {
              final focused = Focus.of(context).hasFocus;
              final showGlow = focused || _pressed;
              final bg = _pressed
                  ? AppColors.buttonBgPressed
                  : _hovered
                  ? AppColors.buttonBgHover
                  : AppColors.buttonBgNormal;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 260.w,
                height: _kButtonHeight.h,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(_kButtonBorderRadius.r),
                  boxShadow: showGlow ? buildFocusGlow() : null,
                ),
                child: notifier != null
                    ? ValueListenableBuilder<List<RhsSubtitleTrack>>(
                        valueListenable: notifier,
                        builder: (_, tracks, _) {
                          final selectedId = tracks
                              .firstWhereOrNull((t) => t.selected)
                              ?.id;
                          final label = _currentLabel(tracks, selectedId);
                          return Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                Icons.subtitles,
                                color: Colors.white,
                                size: 48.r,
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : const SizedBox(),
              );
            },
          ),
        ),
      ),
    );
  }
}
