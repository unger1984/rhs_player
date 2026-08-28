/// Поддерживаемые схемы DRM для нативных плееров.
enum RhsDrmType {
  /// Нет DRM защиты
  none,

  /// Widevine DRM (Google)
  widevine,

  /// ClearKey DRM (открытый ключ)
  clearKey,

  /// Apple FairPlay Streaming для CBCS-HLS на iOS.
  fairPlay,
}

/// Набор конфигурации DRM, передаваемый движку нативного плеера.
///
/// Объект конфигурации используется на Android (Widevine / ClearKey)
/// и iOS (FairPlay Streaming).
/// Значения передаются без изменений, поэтому форматы заголовков и токенов,
/// специфичные для провайдера, могут использоваться без модификации.
class RhsDrmConfig {
  /// Схема DRM для активации. Используйте [RhsDrmType.none] для незащищенного контента.
  final RhsDrmType type;

  /// Дополнительная конечная точка сервера лицензий (например, URL лицензии Widevine).
  final String? licenseUrl;

  /// Дополнительные HTTP заголовки, добавляемые к запросам лицензий.
  final Map<String, String>? headers;

  /// JSON полезная нагрузка для ClearKey на Android. Значение передается
  /// непосредственно в ExoPlayer, поэтому оно должно содержать пары
  /// ключ/значение в кодировке base64.
  final String?
  clearKey; // JSON как требуется ExoPlayer при использовании ClearKey

  /// Дополнительный идентификатор контента, используемый некоторыми серверами лицензий.
  final String? contentId;

  /// URL DER-сертификата FairPlay Application Certificate.
  /// Используется только при [type] == [RhsDrmType.fairPlay].
  final String? certificateUrl;

  /// Создает конфигурацию DRM.
  const RhsDrmConfig({
    required this.type,
    this.licenseUrl,
    this.headers,
    this.clearKey,
    this.contentId,
    this.certificateUrl,
  });

  /// Указывает, включена ли DRM для текущего медиа.
  bool get isDrm => type != RhsDrmType.none;

  @override
  String toString() =>
      'RhsDrmConfig(type: $type, licenseUrl: $licenseUrl, certificateUrl: $certificateUrl, hasHeaders: ${headers?.isNotEmpty == true}, contentId: $contentId, clearKey: ${clearKey != null ? "***" : null})';
}
