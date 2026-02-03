import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player_example/controls/core/control_row.dart';
import 'package:rhs_player_example/controls/core/focusable_item.dart';

/// Верхняя панель фиксированной высоты и цвета с отступами слева и справа.
/// [leftItems] — элементы слева (кнопка назад и т.д.), [rightItems] — справа (саундтрек и т.д.).
class TopBarRow extends BaseControlRow {
  final List<FocusableItem> _leftItems;
  final List<FocusableItem>? _rightItems;
  final double height;
  final Color backgroundColor;
  final double horizontalPadding;
  final String? title;

  TopBarRow({
    required super.id,
    required super.index,
    required List<FocusableItem> leftItems,
    List<FocusableItem>? rightItems,
    this.height = 124,
    this.backgroundColor = const Color(0xFF201B2E),
    this.horizontalPadding = 120,
    this.title,
  }) : _leftItems = leftItems,
       _rightItems = rightItems,
       super(items: [...leftItems, ...?rightItems]);

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
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _leftItems.length; i++)
                    _leftItems[i].build(context),
                  if (title != null) ...[
                    SizedBox(width: 24.w),
                    Text(
                      title!,
                      style: TextStyle(color: Colors.white, fontSize: 32.sp),
                    ),
                  ],
                ],
              ),
              if (_rightItems != null && _rightItems.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _rightItems.length; i++)
                      _rightItems[i].build(context),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
