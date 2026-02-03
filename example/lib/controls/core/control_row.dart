import 'package:flutter/material.dart';
import 'package:rhs_player_example/controls/core/focusable_item.dart';

/// Абстрактный ряд элементов управления
abstract class ControlRow {
  /// Уникальный идентификатор ряда
  String get id;

  /// Индекс ряда (для определения порядка)
  int get index;

  /// Список фокусируемых элементов в ряду
  List<FocusableItem> get items;

  /// Построение виджета ряда
  Widget build(BuildContext context);

  /// Получить элемент по индексу
  FocusableItem? getItemAt(int index) {
    if (index < 0 || index >= items.length) return null;
    return items[index];
  }

  /// Найти индекс элемента по FocusNode
  int? findItemIndex(FocusNode focusNode) {
    for (var i = 0; i < items.length; i++) {
      if (items[i].focusNode == focusNode) return i;
    }
    return null;
  }

  /// Очистка ресурсов
  void dispose() {
    for (final item in items) {
      item.dispose();
    }
  }
}

/// Базовая реализация ряда
abstract class BaseControlRow implements ControlRow {
  @override
  final String id;

  @override
  final int index;

  @override
  final List<FocusableItem> items;

  BaseControlRow({required this.id, required this.index, required this.items});

  @override
  FocusableItem? getItemAt(int index) {
    if (index < 0 || index >= items.length) return null;
    return items[index];
  }

  @override
  int? findItemIndex(FocusNode focusNode) {
    for (var i = 0; i < items.length; i++) {
      if (items[i].focusNode == focusNode) return i;
    }
    return null;
  }

  @override
  void dispose() {
    for (final item in items) {
      item.dispose();
    }
  }
}
