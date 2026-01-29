/// Верхнеуровневая библиотека экспорта для rhs_player.
///
/// Импортируйте `package:rhs_player/rhs_player.dart` для получения публичного API,
/// который объединяет источники медиа, контроллеры и готовые виджеты.
// ignore: unnecessary_library_name
library rhs_player;

export 'src/core/media_source.dart';
export 'src/core/drm.dart';
export 'src/platform/player_controller.dart';
export 'src/platform/player_view.dart';
export 'src/platform/native_events.dart';
export 'src/platform/native_tracks.dart';
export 'src/platform/playback_options.dart';
export 'src/ui/native_fullscreen.dart';
export 'src/ui/native_controls.dart';
export 'src/ui/modern_player.dart';
import 'rhs_player_platform_interface.dart';

/// Простой фасад вокруг интерфейса платформы. В основном используется
/// федеративными тестами примеров; большинство клиентов должны использовать
/// API контроллера напрямую вместо этого класса.
class RhsPlayer {
  /// Возвращает версию платформы, сообщаемую плагином хост-платформы.
  Future<String?> getPlatformVersion() {
    return RhsPlayerPlatform.instance.getPlatformVersion();
  }
}
