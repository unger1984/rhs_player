import 'dart:convert';

import 'package:flutter/services.dart';
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
          ),
        );
      }

      return items;
    } catch (e, st) {
      // В продакшене здесь должна быть более продвинутая обработка ошибок
      throw Exception('Failed to load media items: $e\n$st');
    }
  }
}
