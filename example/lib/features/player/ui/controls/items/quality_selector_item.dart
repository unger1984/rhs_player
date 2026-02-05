import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/shared/ui/theme/app_colors.dart';
import 'package:rhs_player_example/shared/ui/theme/app_sizes.dart';
import 'package:rhs_player_example/shared/ui/theme/focus_decoration.dart';

/// Радиус скругления открытого меню (меньше, чем у кнопки-пилюли).
const double _kMenuBorderRadius = AppSizes.buttonBorderRadius;

/// Диалог выбора качества. Один Focus на всё меню — стрелки меняют индекс, Enter выбирает.
class _QualityMenuDialog extends StatefulWidget {
  final List<RhsVideoTrack> tracks;
  final String? selectedTrackId;
  final Offset anchorTopLeft;
  final Size anchorSize;
  final void Function(FocusNode?)? onRegisterOverlayFocus;

  const _QualityMenuDialog({
    required this.tracks,
    required this.selectedTrackId,
    required this.anchorTopLeft,
    required this.anchorSize,
    this.onRegisterOverlayFocus,
  });

  @override
  State<_QualityMenuDialog> createState() => _QualityMenuDialogState();
}

class _QualityMenuDialogState extends State<_QualityMenuDialog> {
  late int _focusedIndex;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.onRegisterOverlayFocus?.call(_focusNode);
    final idx = widget.tracks.indexWhere(
      (t) => t.id == widget.selectedTrackId || t.selected,
    );
    _focusedIndex = idx >= 0 ? idx : 0;
    // Запрашиваем фокус в меню после нескольких кадров (диалог уже точно в дереве).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          log(
            'QualityMenu: requesting focus on menu, hasFocus before: ${_focusNode.hasFocus}',
          );
          _focusNode.requestFocus();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            log(
              'QualityMenu: hasFocus after requestFocus: ${_focusNode.hasFocus}',
            );
          });
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
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    log(
      'QualityMenu: handleKey ${event.logicalKey}, current index: $_focusedIndex',
    );
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        if (_focusedIndex < widget.tracks.length - 1) {
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
        Navigator.of(context).pop(widget.tracks[_focusedIndex].id);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Меню открывается вверх: нижний край меню у верхнего края кнопки минус отступ.
    final bottomOffset = screenHeight - widget.anchorTopLeft.dy + 4.r;

    return FocusScope(
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Positioned(
              left: widget.anchorTopLeft.dx,
              bottom: bottomOffset,
              width: widget.anchorSize.width,
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKey,
                child: Material(
                  color: AppColors.buttonBgNormal,
                  borderRadius: BorderRadius.circular(_kMenuBorderRadius.r),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < widget.tracks.length; i++)
                        _QualityMenuItem(
                          track: widget.tracks[i],
                          isSelected:
                              widget.tracks[i].id == widget.selectedTrackId ||
                              widget.tracks[i].selected,
                          hasFocus: i == _focusedIndex,
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

class _QualityMenuItem extends StatelessWidget {
  final RhsVideoTrack track;
  final bool isSelected;
  final bool hasFocus;
  final VoidCallback onTap;

  const _QualityMenuItem({
    required this.track,
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
          track.qualityLabel,
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

/// Элемент управления в виде «пилюли»: иконка + текущее качество (720p).
/// По нажатию открывает меню выбора видеотрека.
class QualitySelectorItem extends StatefulWidget {
  final RhsPlayerController controller;
  final FocusNode focusNode;
  final void Function(FocusNode?)? onRegisterOverlayFocus;
  final VoidCallback? onMenuOpened;
  final VoidCallback? onMenuClosed;

  const QualitySelectorItem({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onRegisterOverlayFocus,
    this.onMenuOpened,
    this.onMenuClosed,
  });

  @override
  State<QualitySelectorItem> createState() => _QualitySelectorItemState();
}

class _QualitySelectorItemState extends State<QualitySelectorItem> {
  bool _pressed = false;
  bool _hovered = false;

  String _currentLabel(List<RhsVideoTrack> tracks) {
    final id = widget.controller.selectedVideoTrackId;
    if (id != null && id.isNotEmpty) {
      final t = tracks.firstWhereOrNull((t) => t.id == id);
      if (t != null) return t.qualityLabel;
    }
    final selected = tracks.firstWhereOrNull((t) => t.selected);
    if (selected != null) return selected.qualityLabel;
    if (tracks.isNotEmpty) return tracks.first.qualityLabel;
    return '—';
  }

  Future<void> _openMenu() async {
    final tracks = await widget.controller.getVideoTracks();
    if (!mounted || tracks.isEmpty) return;

    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final position = box.localToGlobal(Offset.zero, ancestor: overlay);
    final size = box.size;
    final selectedId = widget.controller.selectedVideoTrackId;

    // Уведомляем родителя, что меню открыто
    widget.onMenuOpened?.call();

    // Не вызываем unfocus() — иначе фокус сразу уходит на play/pause. Забираем фокус в меню через requestFocus в диалоге.
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => _QualityMenuDialog(
        tracks: tracks,
        selectedTrackId: selectedId,
        anchorTopLeft: position,
        anchorSize: size,
        onRegisterOverlayFocus: widget.onRegisterOverlayFocus,
      ),
    );

    // Уведомляем родителя, что меню закрыто
    widget.onMenuClosed?.call();

    if (selected != null && mounted) {
      await widget.controller.selectVideoTrack(selected);
      // Убираем фокус с кнопки после выбора трека, чтобы она не оставалась подсвеченной
      widget.focusNode.unfocus();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = widget.controller.videoTracks;
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
                width: 240.w,
                height: 96.h,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(99.r),
                  boxShadow: showGlow ? buildFocusGlow() : null,
                ),
                child: notifier != null
                    ? ValueListenableBuilder<List<RhsVideoTrack>>(
                        valueListenable: notifier,
                        builder: (_, tracks, _) {
                          final label = _currentLabel(tracks);
                          return Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              ImageIcon(
                                AssetImage('assets/controls/quality.png'),
                                color: Colors.white,
                                size: 56.r,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : SizedBox(),
              );
            },
          ),
        ),
      ),
    );
  }
}
