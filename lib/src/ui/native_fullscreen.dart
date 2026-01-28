import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/native_player_controller.dart';
import 'modern_player.dart';

/// Fullscreen route that reuses the underlying controller.
class RhsNativeFullscreenPage extends StatefulWidget {
  final RhsNativePlayerController controller;
  final ValueNotifier<BoxFit> boxFitNotifier;
  final Widget? overlay;

  const RhsNativeFullscreenPage({super.key, required this.controller, required this.boxFitNotifier, this.overlay});

  @override
  State<RhsNativeFullscreenPage> createState() => _RhsNativeFullscreenPageState();
}

class _RhsNativeFullscreenPageState extends State<RhsNativeFullscreenPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: RhsModernPlayer(
          controller: widget.controller,
          overlay: widget.overlay,
          isFullscreen: true,
          autoFullscreen: false,
        ),
      ),
    );
  }
}
