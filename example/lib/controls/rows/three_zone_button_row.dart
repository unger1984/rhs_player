import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player_example/controls/core/control_row.dart';
import 'package:rhs_player_example/controls/core/focusable_item.dart';

/// Ряд с тремя зонами: слева, по центру, справа (для кнопок избранное | play/rewind | переключение)
class ThreeZoneButtonRow extends BaseControlRow {
  final List<FocusableItem> leftItems;
  final List<FocusableItem> centerItems;
  final List<FocusableItem> rightItems;
  final double spacing;
  final double horizontalPadding;

  ThreeZoneButtonRow({
    required super.id,
    required super.index,
    required this.leftItems,
    required this.centerItems,
    required this.rightItems,
    this.spacing = 40,
    this.horizontalPadding = 120,
  }) : super(items: [...leftItems, ...centerItems, ...rightItems]);

  Widget _buildZone(BuildContext context, List<FocusableItem> zoneItems) {
    if (zoneItems.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < zoneItems.length; i++) ...[
          zoneItems[i].build(context),
          if (i < zoneItems.length - 1) SizedBox(width: spacing.w),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildZone(context, leftItems),
          _buildZone(context, centerItems),
          _buildZone(context, rightItems),
        ],
      ),
    );
  }
}
