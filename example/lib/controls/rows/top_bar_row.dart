import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player_example/controls/core/control_row.dart';

/// Верхняя панель фиксированной высоты и цвета с отступом слева
class TopBarRow extends BaseControlRow {
  final double height;
  final Color backgroundColor;
  final double leftPadding;
  final String? title;

  TopBarRow({
    required super.id,
    required super.index,
    required super.items,
    this.height = 124,
    this.backgroundColor = const Color(0xFF201B2E),
    this.leftPadding = 120,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: height.h,
          width: double.infinity,
          color: backgroundColor,
        ),
        Container(
          height: height.h,
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: leftPadding.w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) items[i].build(context),
              if (title != null) ...[
                SizedBox(width: 24.w),
                Text(
                  title!,
                  style: TextStyle(color: Colors.white, fontSize: 32.sp),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
