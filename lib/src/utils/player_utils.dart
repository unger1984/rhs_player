import 'package:flutter/material.dart';

/// Форматирует [Duration] в строку MM:SS или HH:MM:SS.
String defaultFormatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// Тема для выпадающих меню плеера (светлое выделение на тёмном фоне).
ThemeData playerMenuTheme(BuildContext context) {
  return Theme.of(context).copyWith(
    highlightColor: Colors.white.withValues(alpha: 0.25),
    hoverColor: Colors.white.withValues(alpha: 0.2),
    focusColor: Colors.white.withValues(alpha: 0.3),
    splashColor: Colors.white.withValues(alpha: 0.15),
  );
}
