/// Top-level library export for rhs_player.
///
/// Import `package:rhs_player/rhs_player.dart` for the public API that bundles
/// media sources, controllers, and ready-made widgets.
// ignore: unnecessary_library_name
library rhs_player;

export 'src/core/media_source.dart';
export 'src/core/drm.dart';
export 'src/platform/native_player_controller.dart';
export 'src/platform/native_player_view.dart';
export 'src/platform/native_tracks.dart';
export 'src/platform/playback_options.dart';
export 'src/ui/native_fullscreen.dart';
export 'src/ui/native_controls.dart';
export 'src/ui/modern_player.dart';
import 'rhs_player_platform_interface.dart';

/// Simple facade around the platform interface. Primarily used by the
/// federated example tests; most clients should use the controller APIs
/// directly instead of this class.
class RhsPlayer {
  /// Returns the platform version reported by the host platform plugin.
  Future<String?> getPlatformVersion() {
    return RhsPlayerPlatform.instance.getPlatformVersion();
  }
}
