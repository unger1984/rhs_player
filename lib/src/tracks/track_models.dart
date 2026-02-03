/// Метаданные, описывающие выбираемую видео дорожку, предоставляемую нативным плеером.
class RhsVideoTrack {
  /// Идентификатор дорожки
  final String id;

  /// Метка дорожки
  final String? label;

  /// Битрейт дорожки
  final int? bitrate;

  /// Ширина видео
  final int? width;

  /// Высота видео
  final int? height;

  /// Флаг выбранной дорожки
  final bool selected;

  const RhsVideoTrack({
    required this.id,
    required this.label,
    required this.bitrate,
    required this.width,
    required this.height,
    required this.selected,
  });

  /// Создает объект из карты данных
  factory RhsVideoTrack.fromMap(Map<dynamic, dynamic> map) {
    // ignore: no_leading_underscores_for_local_identifiers
    int? _int(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v.toString());
    }

    return RhsVideoTrack(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString(),
      bitrate: _int(map['bitrate']),
      width: _int(map['width']),
      height: _int(map['height']),
      selected: map['selected'] == true,
    );
  }

  /// Получает отображаемую метку дорожки
  String get displayLabel {
    final pieces = <String>[];
    if (label != null && label!.trim().isNotEmpty) {
      pieces.add(label!.trim());
    }
    final res = _resolutionLabel;
    if (res != null && !pieces.contains(res)) {
      pieces.add(res);
    }
    final br = _bitrateLabel;
    if (br != null && !pieces.contains(br)) {
      pieces.add(br);
    }
    if (pieces.isEmpty) {
      pieces.add(id);
    }
    return pieces.join(' • ');
  }

  /// Получает метку разрешения видео
  String? get _resolutionLabel {
    if (height == null || height == 0) return null;
    return '${height}p';
  }

  /// Получает короткое название качества для отображения на кнопке (1080p, 720p, 360p и т.д.)
  String get qualityLabel {
    if (height != null && height! > 0) {
      return '${height}p';
    }
    if (label != null && label!.trim().isNotEmpty) {
      return label!.trim();
    }
    // Пытаемся определить по битрейту
    if (bitrate != null && bitrate! > 0) {
      if (bitrate! >= 5000000) return '1080p';
      if (bitrate! >= 2500000) return '720p';
      if (bitrate! >= 1000000) return '480p';
      return '360p';
    }
    return 'HD';
  }

  /// Получает метку битрейта
  String? get _bitrateLabel {
    final br = bitrate;
    if (br == null || br <= 0) return null;
    final mbps = br / 1000000.0;
    if (mbps >= 1) {
      return '${mbps.toStringAsFixed(mbps >= 10 ? 0 : 1)} Mbps';
    }
    final kbps = br / 1000.0;
    return '${kbps.toStringAsFixed(0)} Kbps';
  }
}

/// Метаданные для аудио дорожки, которую пользователь может выбрать.
class RhsAudioTrack {
  /// Идентификатор дорожки
  final String id;

  /// Метка дорожки
  final String? label;

  /// Язык дорожки
  final String? language;

  /// Флаг выбранной дорожки
  final bool selected;

  const RhsAudioTrack({
    required this.id,
    this.label,
    this.language,
    required this.selected,
  });

  /// Создает объект из карты данных
  factory RhsAudioTrack.fromMap(Map<dynamic, dynamic> map) => RhsAudioTrack(
    id: map['id']?.toString() ?? '',
    label: map['label']?.toString(),
    language: map['language']?.toString(),
    selected: map['selected'] == true,
  );
}

/// Метаданные для дорожек закрытых подписей / субтитров.
class RhsSubtitleTrack {
  /// Идентификатор дорожки
  final String id;

  /// Метка дорожки
  final String? label;

  /// Язык дорожки
  final String? language;

  /// Флаг выбранной дорожки
  final bool selected;

  /// Флаг принудительных субтитров
  final bool isForced;

  const RhsSubtitleTrack({
    required this.id,
    this.label,
    this.language,
    required this.selected,
    this.isForced = false,
  });

  /// Создает объект из карты данных
  factory RhsSubtitleTrack.fromMap(Map<dynamic, dynamic> map) =>
      RhsSubtitleTrack(
        id: map['id']?.toString() ?? '',
        label: map['label']?.toString(),
        language: map['language']?.toString(),
        selected: map['selected'] == true,
        isForced: map['forced'] == true,
      );
}
