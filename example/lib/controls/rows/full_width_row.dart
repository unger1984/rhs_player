import 'package:flutter/material.dart';
import 'package:rhs_player_example/controls/core/control_row.dart';

/// Ряд с одним элементом на всю ширину (слайдер)
class FullWidthRow extends BaseControlRow {
  final EdgeInsets padding;

  FullWidthRow({
    required super.id,
    required super.index,
    required super.items,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  }) : assert(
         items.length == 1,
         'FullWidthRow должен содержать только один элемент',
       );

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: items.first.build(context));
  }
}
