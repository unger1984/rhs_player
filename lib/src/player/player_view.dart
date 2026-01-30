import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as services;
import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter/gestures.dart';

import 'player_controller.dart';

/// Отображает только видео текстуру без элементов управления и жестов.
class RhsPlayerView extends StatelessWidget {
  /// Контроллер для управления воспроизведением
  final RhsPlayerController controller;

  /// Режим масштабирования видео
  final BoxFit boxFit;

  const RhsPlayerView({super.key, required this.controller, this.boxFit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    const viewType = 'rhsplayer/native_view';
    final creationParams = controller.creationParams;

    Widget platformView;
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
          final controller = services.PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const services.StandardMessageCodec(),
          );
          controller.addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
          controller.addOnPlatformViewCreatedListener((id) {
            this.controller.attachViewId(id);
            this.controller.setBoxFit(boxFit);
          });
          controller.create();
          return controller;
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

    return platformView;
  }
}
