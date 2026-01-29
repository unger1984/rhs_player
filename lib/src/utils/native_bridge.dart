import 'package:flutter/services.dart';

/// Мост для взаимодействия с нативными функциями платформы.
class NativeBridge {
  /// Канал связи с нативным кодом
  static const _channel = MethodChannel('rhsplayer/channel');

  /// Устанавливает уровень громкости
  static Future<double> setVolume(double delta) async {
    final result = await _channel.invokeMethod<double>('setVolume', {'value': delta});
    return (result ?? 0.0).clamp(0.0, 1.0);
  }

  /// Устанавливает уровень яркости
  static Future<double> setBrightness(double delta) async {
    final result = await _channel.invokeMethod<double>('setBrightness', {'value': delta});
    return (result ?? 0.0).clamp(0.0, 1.0);
  }
}
