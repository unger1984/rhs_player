import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';

/// Стиль фокуса как у [ControlButton]
List<BoxShadow> _focusGlow() => [
  BoxShadow(
    color: const Color(0xFFB3E5FC).withValues(alpha: 0.95),
    blurRadius: 20.r,
    spreadRadius: 4.r,
  ),
  BoxShadow(
    color: Colors.white.withValues(alpha: 0.6),
    blurRadius: 12.r,
    spreadRadius: 2.r,
  ),
];

const Color _kPillBg = Color(0xFF201B2E);
const Color _kPillBgHover = Color(0xFF2A303C);
const Color _kPillBgPressed = Color(0xFF0C0D1D);
const double _kMenuBorderRadius = 16;

/// Как у кнопки «назад» в TopBarRow
const double _kButtonBorderRadius = 16;
const double _kButtonHeight = 76;

String _trackLabel(RhsAudioTrack t) => t.language ?? t.label ?? t.id;

/// Диалог выбора аудиодорожки (саундтрек). Один фокус на меню — стрелки меняют индекс, Enter выбирает.
class _SoundtrackMenuDialog extends StatefulWidget {
  final List<RhsAudioTrack> tracks;
  final String? selectedTrackId;
  final Offset anchorTopLeft;
  final Size anchorSize;
  final void Function(FocusNode?)? onRegisterOverlayFocus;

  const _SoundtrackMenuDialog({
    required this.tracks,
    required this.selectedTrackId,
    required this.anchorTopLeft,
    required this.anchorSize,
    this.onRegisterOverlayFocus,
  });

  @override
  State<_SoundtrackMenuDialog> createState() => _SoundtrackMenuDialogState();
}

class _SoundtrackMenuDialogState extends State<_SoundtrackMenuDialog> {
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
          debugPrint(
            'SoundtrackMenu: requesting focus on menu, hasFocus before: ${_focusNode.hasFocus}',
          );
          _focusNode.requestFocus();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            debugPrint(
              'SoundtrackMenu: hasFocus after requestFocus: ${_focusNode.hasFocus}',
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
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    debugPrint(
      'SoundtrackMenu: handleKey ${event.logicalKey}, current index: $_focusedIndex',
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
    // Меню открывается вниз: верх меню под нижним краем кнопки
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
                  color: _kPillBg,
                  borderRadius: BorderRadius.circular(_kMenuBorderRadius.r),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      for (var i = 0; i < widget.tracks.length; i++)
                        _SoundtrackMenuItem(
                          label: _trackLabel(widget.tracks[i]),
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

class _SoundtrackMenuItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool hasFocus;
  final VoidCallback onTap;

  const _SoundtrackMenuItem({
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
          color: hasFocus ? _kPillBgHover : null,
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

/// Кнопка выбора саундтрека (аудиодорожки). Стиль как у кнопки «назад» — менее скруглённая.
class SoundtrackSelectorItem extends StatefulWidget {
  final RhsPlayerController controller;
  final FocusNode focusNode;
  final void Function(FocusNode?)? onRegisterOverlayFocus;

  const SoundtrackSelectorItem({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onRegisterOverlayFocus,
  });

  @override
  State<SoundtrackSelectorItem> createState() => _SoundtrackSelectorItemState();
}

class _SoundtrackSelectorItemState extends State<SoundtrackSelectorItem> {
  bool _pressed = false;
  bool _hovered = false;

  String _currentLabel(List<RhsAudioTrack> tracks) {
    final selected = tracks.firstWhereOrNull((t) => t.selected);
    if (selected != null) return _trackLabel(selected);
    if (tracks.isNotEmpty) return _trackLabel(tracks.first);
    return '—';
  }

  Future<void> _openMenu() async {
    final tracks = await widget.controller.getAudioTracks();
    if (!mounted || tracks.isEmpty) return;

    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final position = box.localToGlobal(Offset.zero, ancestor: overlay);
    final size = box.size;
    final selectedId = tracks.firstWhereOrNull((t) => t.selected)?.id;

    // Не вызываем unfocus() — иначе фокус сразу уходит на другой элемент. Забираем фокус в меню через requestFocus в диалоге.
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => _SoundtrackMenuDialog(
        tracks: tracks,
        selectedTrackId: selectedId,
        anchorTopLeft: position,
        anchorSize: size,
        onRegisterOverlayFocus: widget.onRegisterOverlayFocus,
      ),
    );

    if (selected != null && mounted) {
      await widget.controller.selectAudioTrack(selected);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = widget.controller.audioTracks;
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
                  ? _kPillBgPressed
                  : _hovered
                  ? _kPillBgHover
                  : _kPillBg;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 260.w,
                height: _kButtonHeight.h,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(_kButtonBorderRadius.r),
                  boxShadow: showGlow ? _focusGlow() : null,
                ),
                child: notifier != null
                    ? ValueListenableBuilder<List<RhsAudioTrack>>(
                        valueListenable: notifier,
                        builder: (_, tracks, _) {
                          final label = _currentLabel(tracks);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ImageIcon(
                                const AssetImage('assets/controls/music.png'),
                                color: Colors.white,
                                size: 48.r,
                              ),
                              SizedBox(width: 10.w),
                              Flexible(
                                child: Text(
                                  label,
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
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ImageIcon(
                            const AssetImage('assets/controls/music.png'),
                            color: Colors.white,
                            size: 48.r,
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            '—',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
