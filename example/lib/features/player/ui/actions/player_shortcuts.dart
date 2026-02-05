import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:rhs_player_example/features/player/ui/actions/player_intents.dart';

/// Маппинг клавиш на Intent для управления плеером.
/// Возвращает разные биндинги в зависимости от видимости контролов.
Map<ShortcutActivator, Intent> buildPlayerShortcuts({
  required bool controlsVisible,
}) {
  return {
    // ========== Клавиши при скрытых контролах ==========
    if (!controlsVisible) ...{
      // OK/Enter — показать контролы с фокусом на play/pause
      const SingleActivator(LogicalKeyboardKey.select):
          const ShowControlsIntent(resetFocus: true),
      const SingleActivator(LogicalKeyboardKey.enter): const ShowControlsIntent(
        resetFocus: true,
      ),

      // Стрелки вверх/вниз — показать контролы
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          const ShowControlsIntent(resetFocus: true),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          const ShowControlsIntent(resetFocus: true),

      // Стрелки влево/вправо — перемотка (обработка с повтором в приоритетном хендлере)
      // Эти биндинги нужны для случая, когда priority handler не перехватил событие
      const SingleActivator(LogicalKeyboardKey.arrowLeft):
          const SeekBackwardIntent(Duration(seconds: 10)),
      const SingleActivator(LogicalKeyboardKey.arrowRight):
          const SeekForwardIntent(Duration(seconds: 10)),
    },

    // ========== Глобальные клавиши (работают всегда) ==========

    // Info/Menu — переключить видимость контролов
    const SingleActivator(LogicalKeyboardKey.info):
        const ToggleControlsVisibilityIntent(),
    const SingleActivator(LogicalKeyboardKey.contextMenu):
        const ToggleControlsVisibilityIntent(),
  };
}

/// Маппинг клавиш для приоритетного обработчика (перехватывает события ДО фокусов).
/// Используется для обработки клавиш при скрытых контролах с особой логикой.
Map<LogicalKeyboardKey, Intent> buildPriorityShortcuts({
  required bool controlsVisible,
}) {
  if (controlsVisible) return {};

  return {
    // При скрытых контролах перехватываем все навигационные клавиши
    LogicalKeyboardKey.select: const ShowControlsIntent(resetFocus: true),
    LogicalKeyboardKey.enter: const ShowControlsIntent(resetFocus: true),
    LogicalKeyboardKey.arrowUp: const ShowControlsIntent(resetFocus: true),
    LogicalKeyboardKey.arrowDown: const ShowControlsIntent(resetFocus: true),
    // Стрелки влево/вправо для перемотки обрабатываются специально (с повтором)
    LogicalKeyboardKey.arrowLeft: const SeekBackwardIntent(
      Duration(seconds: 10),
    ),
    LogicalKeyboardKey.arrowRight: const SeekForwardIntent(
      Duration(seconds: 10),
    ),
  };
}
