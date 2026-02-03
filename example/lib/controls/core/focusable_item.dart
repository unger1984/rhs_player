import 'package:flutter/material.dart';
import 'package:rhs_player_example/controls/core/key_handling_result.dart';

/// Базовый интерфейс для любого элемента с фокусом
abstract class FocusableItem {
  /// Уникальный идентификатор элемента
  String get id;

  /// FocusNode для управления фокусом
  FocusNode get focusNode;

  /// Обработка клавиши элементом (Chain of Responsibility)
  /// Возвращает результат обработки
  KeyHandlingResult handleKey(KeyEvent event) {
    return KeyHandlingResult.notHandled;
  }

  /// Построение виджета элемента
  Widget build(BuildContext context);

  /// Очистка ресурсов
  void dispose();
}

/// Базовая реализация с автоматическим управлением FocusNode
abstract class BaseFocusableItem implements FocusableItem {
  @override
  final String id;

  @override
  final FocusNode focusNode;

  BaseFocusableItem({required this.id, FocusNode? focusNode})
    : focusNode = focusNode ?? FocusNode();

  @override
  KeyHandlingResult handleKey(KeyEvent event) {
    return KeyHandlingResult.notHandled;
  }

  @override
  void dispose() {
    focusNode.dispose();
  }
}
