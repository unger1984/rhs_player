import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/entities/media/model/media_item.dart';

/// Репозиторий для работы с медиа-контентом.
/// Инкапсулирует логику загрузки и парсинга данных о фильмах.
class MediaRepository {
  /// Загрузка списка фильмов из JSON файла.
  /// В будущем может быть заменено на сетевой запрос.
  Future<List<MediaItem>> loadMediaItems() async {
    try {
      final json = await rootBundle.loadString('films.json');
      final list = jsonDecode(json) as List<dynamic>;

      final items = <MediaItem>[];
      for (final e in list) {
        final map = e as Map<String, dynamic>;
        final link = map['link'] as String? ?? '';
        final drmUrl = map['drm'] as String?;
        final drmType = _parseDrmType(map['drmType'] as String?, drmUrl);
        if (!_isSupportedOnCurrentPlatform(drmType)) continue;
        final drmCertificateUrl = map['certificate'] as String?;
        final title = map['title'] as String? ?? '';

        // Генерируем ID из URL для уникальности
        final id = link.hashCode.toString();

        items.add(
          MediaItem(
            id: id,
            title: title,
            url: link,
            drmLicenseUrl: (drmUrl != null && drmUrl.isNotEmpty)
                ? drmUrl
                : null,
            drmType: drmType,
            drmCertificateUrl: drmCertificateUrl,
          ),
        );
      }

      return items;
    } catch (e, st) {
      // В продакшене здесь должна быть более продвинутая обработка ошибок
      throw Exception('Failed to load media items: $e\n$st');
    }
  }

  RhsDrmType _parseDrmType(String? value, String? licenseUrl) {
    if (value == 'fairPlay') return RhsDrmType.fairPlay;
    if (value == 'clearKey') return RhsDrmType.clearKey;
    if (licenseUrl?.isNotEmpty == true) return RhsDrmType.widevine;
    return RhsDrmType.none;
  }

  bool _isSupportedOnCurrentPlatform(RhsDrmType drmType) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return drmType == RhsDrmType.fairPlay || drmType == RhsDrmType.none;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return drmType != RhsDrmType.fairPlay;
    }
    return drmType == RhsDrmType.none;
  }
}
