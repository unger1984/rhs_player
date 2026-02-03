import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player_example/controls/core/control_row.dart';

/// Ряд с одним элементом на всю ширину (слайдер)
class FullWidthRow extends BaseControlRow {
  final EdgeInsets? padding;

  FullWidthRow({
    required super.id,
    required super.index,
    required super.items,
    this.padding,
  }) : assert(
         items.length == 1,
         'FullWidthRow должен содержать только один элемент',
       );

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? EdgeInsets.symmetric(horizontal: 20.w);
    return Padding(
      padding: effectivePadding,
      child: items.first.build(context),
    );
  }
}
