import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player_example/controls/core/control_row.dart';
import 'package:rhs_player_example/controls/core/focusable_item.dart';
import 'package:rhs_player_example/controls/core/key_handling_result.dart';

/// Менеджер навигации между элементами управления
class NavigationManager {
  final List<ControlRow> rows;
  final FocusNode? initialFocusNode;
  final String? initialFocusId;

  NavigationManager({
    required this.rows,
    this.initialFocusNode,
    this.initialFocusId,
  }) {
    _sortRows();
  }

  /// Сортировка рядов по индексу
  void _sortRows() {
    rows.sort((a, b) => a.index.compareTo(b.index));
  }

  /// Обработка клавиши с Chain of Responsibility
  KeyEventResult handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus == null) {
      _requestInitialFocus();
      return KeyEventResult.handled;
    }

    // Находим текущий элемент; если фокус ушёл за пределы контролов — возвращаем его
    final currentItem = _findItemByFocusNode(currentFocus);
    if (currentItem == null) {
      dev.log(
        'Текущий элемент не найден, возврат фокуса в контролы',
        name: 'NavigationManager',
      );
      _requestInitialFocus(deferred: true);
      return KeyEventResult.handled;
    }

    // Сначала даем элементу возможность обработать клавишу
    final handlingResult = currentItem.handleKey(event);

    // Если элемент обработал клавишу, не передаем дальше
    if (handlingResult == KeyHandlingResult.handled) {
      return KeyEventResult.handled;
    }

    // Tab/Shift+Tab не должны выносить фокус за пределы контролов
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      return KeyEventResult.handled;
    }

    // Если элемент не обработал или нужна навигация - обрабатываем навигацию
    return _handleNavigation(currentFocus, event);
  }

  /// Обработка навигационных клавиш
  KeyEventResult _handleNavigation(FocusNode currentFocus, KeyEvent event) {
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        return _navigateUp(currentFocus);
      case LogicalKeyboardKey.arrowDown:
        return _navigateDown(currentFocus);
      case LogicalKeyboardKey.arrowLeft:
        return _navigateLeft(currentFocus);
      case LogicalKeyboardKey.arrowRight:
        return _navigateRight(currentFocus);
      default:
        return KeyEventResult.ignored;
    }
  }

  /// Публичная навигация вверх (для вызова из элементов, перехватывающих фокус)
  KeyEventResult navigateUp(FocusNode? currentFocus) {
    final node = currentFocus ?? FocusManager.instance.primaryFocus;
    if (node == null) return KeyEventResult.ignored;
    return _navigateUp(node);
  }

  /// Навигация вверх (к предыдущему ряду)
  KeyEventResult _navigateUp(FocusNode currentFocus) {
    final position = _findPosition(currentFocus);
    if (position == null) {
      _requestInitialFocus(deferred: true);
      return KeyEventResult.handled;
    }

    final targetRowIndex = position.rowIndex - 1;
    if (targetRowIndex < 0) return KeyEventResult.handled;

    final targetRow = rows[targetRowIndex];
    final targetItemIndex = position.itemIndex.clamp(
      0,
      targetRow.items.length - 1,
    );
    final targetItem = targetRow.items[targetItemIndex];

    targetItem.focusNode.requestFocus();
    return KeyEventResult.handled;
  }

  /// Публичная навигация вниз (для вызова из элементов, перехватывающих фокус)
  KeyEventResult navigateDown(FocusNode? currentFocus) {
    final node = currentFocus ?? FocusManager.instance.primaryFocus;
    if (node == null) return KeyEventResult.ignored;
    return _navigateDown(node);
  }

  /// Навигация вниз (к следующему ряду)
  KeyEventResult _navigateDown(FocusNode currentFocus) {
    final position = _findPosition(currentFocus);
    if (position == null) {
      _requestInitialFocus(deferred: true);
      return KeyEventResult.handled;
    }

    final targetRowIndex = position.rowIndex + 1;
    if (targetRowIndex >= rows.length) return KeyEventResult.handled;

    final targetRow = rows[targetRowIndex];
    final targetItemIndex = position.itemIndex.clamp(
      0,
      targetRow.items.length - 1,
    );
    final targetItem = targetRow.items[targetItemIndex];

    targetItem.focusNode.requestFocus();
    return KeyEventResult.handled;
  }

  /// Навигация влево (к предыдущему элементу в ряду)
  KeyEventResult _navigateLeft(FocusNode currentFocus) {
    final position = _findPosition(currentFocus);
    if (position == null) {
      _requestInitialFocus(deferred: true);
      return KeyEventResult.handled;
    }

    final currentRow = rows[position.rowIndex];
    final targetItemIndex = position.itemIndex - 1;

    if (targetItemIndex < 0) return KeyEventResult.handled;

    final targetItem = currentRow.items[targetItemIndex];
    targetItem.focusNode.requestFocus();
    return KeyEventResult.handled;
  }

  /// Навигация вправо (к следующему элементу в ряду)
  KeyEventResult _navigateRight(FocusNode currentFocus) {
    final position = _findPosition(currentFocus);
    if (position == null) {
      _requestInitialFocus(deferred: true);
      return KeyEventResult.handled;
    }

    final currentRow = rows[position.rowIndex];
    final targetItemIndex = position.itemIndex + 1;

    if (targetItemIndex >= currentRow.items.length) {
      return KeyEventResult.handled;
    }

    final targetItem = currentRow.items[targetItemIndex];
    targetItem.focusNode.requestFocus();
    return KeyEventResult.handled;
  }

  /// Найти позицию элемента (ряд и индекс в ряду)
  _ItemPosition? _findPosition(FocusNode focusNode) {
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final itemIndex = row.findItemIndex(focusNode);
      if (itemIndex != null) {
        return _ItemPosition(rowIndex: rowIndex, itemIndex: itemIndex);
      }
    }
    return null;
  }

  /// Найти элемент по FocusNode
  FocusableItem? _findItemByFocusNode(FocusNode focusNode) {
    for (final row in rows) {
      for (final item in row.items) {
        if (item.focusNode == focusNode) return item;
      }
    }
    return null;
  }

  /// Найти элемент по id
  FocusableItem? _findItemById(String id) {
    for (final row in rows) {
      for (final item in row.items) {
        if (item.id == id) return item;
      }
    }
    return null;
  }

  /// Запросить начальный фокус.
  /// [deferred] — при true запрос выполняется в следующем кадре (для восстановления
  /// из обработчика клавиш, иначе requestFocus может не примениться).
  void _requestInitialFocus({bool deferred = false}) {
    void doRequest() {
      if (initialFocusNode != null) {
        initialFocusNode!.requestFocus();
        return;
      }
      final byId = initialFocusId != null
          ? _findItemById(initialFocusId!)
          : null;
      if (byId != null) {
        byId.focusNode.requestFocus();
        return;
      }
      if (rows.isNotEmpty && rows.first.items.isNotEmpty) {
        rows.first.items.first.focusNode.requestFocus();
      }
    }

    if (deferred) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        doRequest();
        // Повторная попытка в следующем кадре, если фокус не перешёл в контролы
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final primary = FocusManager.instance.primaryFocus;
          if (primary != null && _findItemByFocusNode(primary) == null) {
            doRequest();
          }
        });
      });
    } else {
      doRequest();
    }
  }

  /// Запросить начальный фокус (публичный метод)
  void requestInitialFocus() {
    _requestInitialFocus();
  }

  /// Очистка ресурсов
  void dispose() {
    for (final row in rows) {
      row.dispose();
    }
  }
}

/// Позиция элемента в сетке управления
class _ItemPosition {
  final int rowIndex;
  final int itemIndex;

  _ItemPosition({required this.rowIndex, required this.itemIndex});
}
