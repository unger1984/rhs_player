import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';

/// Оверлей субтитров: полупрозрачная тёмная подложка со скруглёнными углами,
/// текст до 3 строк.
/// При [controlsVisible] false — субтитры опускаются ниже. При [controlsExpanded] — выше.
class SubtitleOverlay extends StatelessWidget {
  final RhsPlayerController controller;

  /// При false контролы скрыты — субтитры опускаются ниже.
  final ValueListenable<bool>? controlsVisible;

  /// При true контролы раскрыты (карусель expanded) — субтитры выше.
  final ValueListenable<bool>? controlsExpanded;

  const SubtitleOverlay({
    super.key,
    required this.controller,
    this.controlsVisible,
    this.controlsExpanded,
  });

  static final _alwaysTrue = ValueNotifier(true);
  static final _alwaysFalse = ValueNotifier(false);

  /// Скрыты: 80. Peek: 360. Expanded: 580.
  static const _hiddenBottom = 80.0;
  static const _peekBottom = 360.0;
  static const _expandedBottom = 580.0;

  double _bottom({required bool visible, required bool expanded}) {
    if (!visible) return _hiddenBottom;
    return expanded ? _expandedBottom : _peekBottom;
  }

  @override
  Widget build(BuildContext context) {
    final cuesNotifier = controller.subtitleCues;
    if (cuesNotifier == null) return const SizedBox.shrink();

    final content = Align(
      alignment: Alignment.bottomCenter,
      child: ValueListenableBuilder<String>(
        valueListenable: cuesNotifier,
        builder: (context, text, _) {
          if (text.isEmpty) return const SizedBox.shrink();
          final lines = text.split('\n').take(3).toList();
          if (lines.isEmpty) return const SizedBox.shrink();
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              lines.join('\n'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32.sp,
                height: 1.3,
              ),
            ),
          );
        },
      ),
    );

    final effectiveVisible = controlsVisible ?? _alwaysTrue;
    final effectiveExpanded = controlsExpanded ?? _alwaysFalse;

    return ValueListenableBuilder<bool>(
      valueListenable: effectiveVisible,
      builder: (_, visible, _) => ValueListenableBuilder<bool>(
        valueListenable: effectiveExpanded,
        builder: (_, expanded, _) => Positioned(
          left: 48.w,
          right: 48.w,
          bottom: _bottom(visible: visible, expanded: expanded).h,
          child: content,
        ),
      ),
    );
  }
}
