import 'drm_config.dart';

/// Определение одного медиа элемента для нативного плеера.
class RhsMediaSource {
  /// URL потока или манифеста (HLS/DASH/MP4/и т.д.).
  final String url;

  /// Дополнительные HTTP заголовки, применяемые к запросу медиа.
  final Map<String, String>? headers;

  /// Когда `true`, включает настройку потокового вещания, 
  /// такую как буферизация с низкой задержкой.
  final bool isLive;

  /// Конфигурация DRM для элемента.
  final RhsDrmConfig drm;

  /// Дополнительный VTT спрайт для отображения миниатюр при перемотке.
  final String? thumbnailVttUrl;

  /// Дополнительные заголовки для запросов миниатюр.
  final Map<String, String>? thumbnailHeaders;

  /// Создает определение медиа источника.
  const RhsMediaSource(
    this.url, {
    this.headers,
    this.isLive = false,
    this.drm = const RhsDrmConfig(type: RhsDrmType.none),
    this.thumbnailVttUrl,
    this.thumbnailHeaders,
  });

  /// `true`, если URL выглядит как манифест HLS.
  bool get isM3U8 => url.toLowerCase().endsWith('.m3u8');

  /// `true`, если URL заканчивается на `.m3u`.
  bool get isM3U => url.toLowerCase().endsWith('.m3u');
}
