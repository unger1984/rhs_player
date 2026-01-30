/// Поддерживаемые схемы DRM для нативных плееров.
enum RhsDrmType { 
  /// Нет DRM защиты
  none, 
  
  /// Widevine DRM (Google)
  widevine, 
  
  /// ClearKey DRM (открытый ключ)
  clearKey 
}

/// Набор конфигурации DRM, передаваемый движкам нативных плееров.
///
/// Один и тот же объект конфигурации используется на Android (Widevine / ClearKey) 
/// и iOS (AVContentKey). Значения передаются без изменений, поэтому форматы 
/// заголовков и токенов, специфичные для провайдера, могут использоваться 
/// без модификации.
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
  final String? clearKey; // JSON как требуется ExoPlayer при использовании ClearKey

  /// Дополнительный идентификатор контента, используемый некоторыми серверами лицензий.
  final String? contentId;

  /// Создает конфигурацию DRM.
  const RhsDrmConfig({required this.type, this.licenseUrl, this.headers, this.clearKey, this.contentId});

  /// Указывает, включена ли DRM для текущего медиа.
  bool get isDrm => type != RhsDrmType.none;

  @override
  String toString() =>
      'RhsDrmConfig(type: $type, licenseUrl: $licenseUrl, hasHeaders: ${headers?.isNotEmpty == true}, contentId: $contentId, clearKey: ${clearKey != null ? "***" : null})';
}
