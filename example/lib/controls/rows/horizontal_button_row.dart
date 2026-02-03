import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player_example/controls/core/control_row.dart';

/// Ряд с горизонтальным расположением элементов (кнопки)
class HorizontalButtonRow extends BaseControlRow {
  final MainAxisAlignment alignment;
  final double spacing;

  HorizontalButtonRow({
    required super.id,
    required super.index,
    required super.items,
    this.alignment = MainAxisAlignment.center,
    this.spacing = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          items[i].build(context),
          if (i < items.length - 1) SizedBox(width: spacing.w),
        ],
      ],
    );
  }
}
