import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Класс для представления миниатюры в определенный период времени
class ThumbCue {
  /// Время начала отображения миниатюры
  final Duration start;
  
  /// Время окончания отображения миниатюры
  final Duration end;
  
  /// URI изображения миниатюры
  final Uri image;
  
  /// Координата X обрезки изображения
  final int? x;
  
  /// Координата Y обрезки изображения
  final int? y;
  
  /// Ширина обрезки изображения
  final int? w;
  
  /// Высота обрезки изображения
  final int? h;

  const ThumbCue({
    required this.start,
    required this.end,
    required this.image,
    this.x,
    this.y,
    this.w,
    this.h,
  });

  /// Проверяет, есть ли обрезка изображения
  bool get hasCrop => x != null && y != null && w != null && h != null;
}

/// Кэш миниатюр
final _thumbCache = <String, List<ThumbCue>>{};

/// Очищает кэш миниатюр в памяти.
void clearThumbnailCache() => _thumbCache.clear();

/// Загружает миниатюры из VTT файла
Future<List<ThumbCue>> fetchVttThumbnails(
  String url, {
  Map<String, String>? headers,
  bool cache = true,
}) async {
  final cacheKey = _cacheKey(url, headers);
  if (cache && _thumbCache.containsKey(cacheKey)) {
    return _thumbCache[cacheKey]!;
  }
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse(url));
  headers?.forEach((k, v) => req.headers.set(k, v));
  final resp = await req.close();
  if (resp.statusCode != 200) {
    throw StateError('Failed to fetch thumbnails VTT: HTTP ${resp.statusCode}');
  }
  final text = await utf8.decodeStream(resp);
  final cues = parseWebVtt(text, base: Uri.parse(url));
  if (cache) {
    _thumbCache[cacheKey] = cues;
  }
  return cues;
}

/// Генерирует ключ для кэширования миниатюр
String _cacheKey(String url, Map<String, String>? headers) {
  if (headers == null || headers.isEmpty) return url;
  final sorted =
      headers.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final buffer = StringBuffer(url);
  for (final entry in sorted) {
    buffer
      ..write('|')
      ..write(entry.key)
      ..write('=')
      ..write(entry.value);
  }
  return buffer.toString();
}

/// Парсит WebVTT файл и извлекает миниатюры
List<ThumbCue> parseWebVtt(String input, {Uri? base}) {
  final lines = const LineSplitter().convert(input);
  final result = <ThumbCue>[];
  Duration? start;
  Duration? end;
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('WEBVTT')) continue;
    if (line.contains('-->')) {
      final parts = line.split('-->');
      start = _parseVttTime(parts[0].trim());
      end = _parseVttTime(parts[1].trim());
      continue;
    }
    if (start != null && end != null) {
      // Ожидаем URL изображения, возможно с #xywh=x,y,w,h
      final uri = base == null ? Uri.parse(line) : base.resolve(line);
      int? x, y, w, h;
      if (uri.fragment.startsWith('xywh=')) {
        final vals = uri.fragment.substring(5).split(',');
        if (vals.length == 4) {
          x = int.tryParse(vals[0]);
          y = int.tryParse(vals[1]);
          w = int.tryParse(vals[2]);
          h = int.tryParse(vals[3]);
        }
      }
      final clean = uri.replace(fragment: '');
      result.add(
        ThumbCue(start: start, end: end, image: clean, x: x, y: y, w: w, h: h),
      );
      start = null;
      end = null;
    }
  }
  return result;
}

/// Парсит время в формате VTT
Duration _parseVttTime(String s) {
  // 00:00:05.000 or 00:05.000
  final parts = s.split(':');
  int h = 0, m = 0;
  double sec = 0;
  if (parts.length == 3) {
    h = int.parse(parts[0]);
    m = int.parse(parts[1]);
    sec = double.parse(parts[2].replaceAll(',', '.'));
  } else if (parts.length == 2) {
    m = int.parse(parts[0]);
    sec = double.parse(parts[1].replaceAll(',', '.'));
  }
  final ms = (sec * 1000).round();
  return Duration(hours: h, minutes: m, milliseconds: ms);
}
