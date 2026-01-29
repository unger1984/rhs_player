import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as services;
import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter/gestures.dart';

import 'player_controller.dart';

/// Отображает только видео текстуру без элементов управления и жестов.
class RhsPlayerView extends StatefulWidget {
  /// Контроллер для управления воспроизведением
  final RhsPlayerController controller;

  /// Режим масштабирования видео
  final BoxFit boxFit;

  const RhsPlayerView({super.key, required this.controller, this.boxFit = BoxFit.contain});

  @override
  State<RhsPlayerView> createState() => _RhsPlayerViewState();
}

class _RhsPlayerViewState extends State<RhsPlayerView> {
  @override
  Widget build(BuildContext context) {
    const viewType = 'rhsplayer/native_view';
    final creationParams = widget.controller.creationParams;

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
            widget.controller.attachViewId(id);
            widget.controller.setBoxFit(widget.boxFit);
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
          widget.controller.attachViewId(id);
          widget.controller.setBoxFit(widget.boxFit);
        },
      );
    } else {
      platformView = const SizedBox.shrink();
    }

    return platformView;
  }

  @override
  void didUpdateWidget(covariant RhsPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boxFit != widget.boxFit) {
      widget.controller.setBoxFit(widget.boxFit);
    }
  }
}
