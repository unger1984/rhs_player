import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/features/player/ui/controls/rows/recommended_carousel_row.dart';

/// Модель медиа-контента (фильм, сериал и т.д.).
/// Бизнес-сущность, переиспользуемая между фичами.
class MediaItem {
  /// Уникальный идентификатор
  final String id;

  /// Название
  final String title;

  /// URL потока видео
  final String url;

  /// URL лицензии DRM (Widevine)
  final String? drmLicenseUrl;

  /// Виджет постера/превью (опционально)
  final Widget? poster;

  const MediaItem({
    required this.id,
    required this.title,
    required this.url,
    this.drmLicenseUrl,
    this.poster,
  });

  /// Преобразование в RhsMediaSource для плеера.
  RhsMediaSource toMediaSource() {
    return RhsMediaSource(
      url,
      drm: drmLicenseUrl != null && drmLicenseUrl!.isNotEmpty
          ? RhsDrmConfig(type: RhsDrmType.widevine, licenseUrl: drmLicenseUrl!)
          : const RhsDrmConfig(type: RhsDrmType.none),
    );
  }

  /// Преобразование в RecommendedCarouselItem для отображения в карусели.
  RecommendedCarouselItem toCarouselItem() {
    return RecommendedCarouselItem(
      title: title,
      image: poster ?? _defaultPoster(),
      mediaSource: toMediaSource(),
    );
  }

  /// Дефолтный постер-заглушка
  Widget _defaultPoster() {
    return Container(
      color: const Color(0xFF2A303C),
      child: Center(
        child: Icon(Icons.movie, color: Colors.white54, size: 48.r),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
