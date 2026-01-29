import 'package:flutter/material.dart';

import '../platform/player_controller.dart';
import 'native_fullscreen.dart';

/// Минимальная панель управления, которая передает команды непосредственно
/// нативному плееру.
class RhsNativeControls extends StatelessWidget {
  /// Контроллер для управления воспроизведением
  final RhsPlayerController controller;

  /// Уведомитель режима масштабирования
  final ValueNotifier<BoxFit> boxFitNotifier;

  /// Дополнительный оверлей, который будет отображаться поверх плеера
  final Widget? overlay;

  const RhsNativeControls({super.key, required this.controller, required this.boxFitNotifier, this.overlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            onPressed: () => controller.play(),
          ),
          IconButton(
            icon: const Icon(Icons.pause, color: Colors.white),
            onPressed: () => controller.pause(),
          ),
          const Spacer(),
          PopupMenuButton<BoxFit>(
            tooltip: 'Resize',
            icon: const Icon(Icons.aspect_ratio, color: Colors.white),
            onSelected: (fit) {
              boxFitNotifier.value = fit;
              controller.setBoxFit(fit);
            },
            itemBuilder: (context) => [
              _fitItem('Contain', BoxFit.contain, boxFitNotifier.value),
              _fitItem('Cover', BoxFit.cover, boxFitNotifier.value),
              _fitItem('Fill', BoxFit.fill, boxFitNotifier.value),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RhsNativeFullscreenPage(controller: controller, boxFitNotifier: boxFitNotifier, overlay: overlay),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Создает элемент меню выбора режима масштабирования
  PopupMenuItem<BoxFit> _fitItem(String label, BoxFit value, BoxFit selected) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (value == selected) const Icon(Icons.check, size: 14) else const SizedBox(width: 14),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
