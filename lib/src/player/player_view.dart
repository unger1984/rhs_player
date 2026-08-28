import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter/services.dart' as services;

import 'player_controller.dart';

/// Отображает видео текстуру с возможностью наложения UI элементов.
class RhsPlayerView extends StatelessWidget {
  /// Контроллер для управления воспроизведением
  final RhsPlayerController controller;

  /// Режим масштабирования видео
  final BoxFit boxFit;

  /// Виджет overlay (например, контролы), который будет отображаться поверх видео
  final Widget? overlay;

  const RhsPlayerView({
    super.key,
    required this.controller,
    this.boxFit = BoxFit.contain,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    const viewType = 'rhsplayer/native_view';
    final creationParams = controller.creationParams;

    final Widget platformView;
    if (defaultTargetPlatform == TargetPlatform.android) {
      platformView = PlatformViewLink(
        viewType: viewType,
        surfaceFactory: (context, controller) {
          return AndroidViewSurface(
            controller: controller as services.AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: rendering.PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          final nativeController =
              services.PlatformViewsService.initSurfaceAndroidView(
                id: params.id,
                viewType: viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: creationParams,
                creationParamsCodec: const services.StandardMessageCodec(),
              );
          nativeController.addOnPlatformViewCreatedListener(
            params.onPlatformViewCreated,
          );
          nativeController.addOnPlatformViewCreatedListener((id) {
            controller.attachViewId(id);
            controller.setBoxFit(boxFit);
          });
          nativeController.create();
          return nativeController;
        },
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      platformView = UiKitView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const services.StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          controller.attachViewId(id);
          controller.setBoxFit(boxFit);
        },
      );
    } else {
      platformView = const SizedBox.shrink();
    }

    // Если есть overlay, размещаем его поверх видео
    final overlayWidget = overlay;
    if (overlayWidget != null) {
      return Stack(children: [platformView, overlayWidget]);
    }

    return platformView;
  }
}
