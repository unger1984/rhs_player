/// Верхнеуровневая библиотека экспорта для rhs_player.
///
/// Импортируйте `package:rhs_player/rhs_player.dart` для получения публичного API,
/// который объединяет источники медиа, контроллеры и готовые виджеты.
// ignore: unnecessary_library_name
library rhs_player;

// Core models
export 'src/media/media_source.dart';
export 'src/media/drm_config.dart';
export 'src/playback/playback_state.dart';
export 'src/playback/playback_events.dart';
export 'src/playback/playback_options.dart';
export 'src/tracks/track_models.dart';
export 'src/tracks/track_events.dart';

// Player API
export 'src/player/player_controller.dart';
export 'src/player/player_view.dart';

// UI Widgets
export 'src/widgets/audio_track_button.dart';
export 'src/widgets/buffering_indicator.dart';
export 'src/widgets/error_display.dart';
export 'src/widgets/forward_button.dart';
export 'src/widgets/fullscreen_button.dart';
export 'src/widgets/play_pause_button.dart';
export 'src/widgets/progress_bar.dart';
export 'src/widgets/quality_button.dart';
export 'src/widgets/rewind_button.dart';
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
