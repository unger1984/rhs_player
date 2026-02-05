import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';

/// Оверлей индикатора буферизации.
/// Показывается поверх видео во время загрузки контента.
class BufferingOverlay extends StatelessWidget {
  final RhsPlayerController controller;

  const BufferingOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RhsPlayerStatus>(
      stream: controller.playerStatusStream,
      builder: (context, snapshot) {
        if (snapshot.data is RhsPlayerStatusLoading) {
          return Center(
            child: SizedBox(
              width: 80.r,
              height: 80.r,
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
