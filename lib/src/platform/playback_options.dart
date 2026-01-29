/// Параметры конфигурации, влияющие на устойчивость воспроизведения и буферизацию.
class RhsPlaybackOptions {
  /// Максимальное количество автоматических попыток повтора перед 
  /// сообщением об ошибке. `-1` означает неограниченное количество попыток.
  final int maxRetryCount;

  /// Задержка перед первой попыткой повтора.
  final Duration initialRetryDelay;

  /// Максимальная задержка между попытками повтора.
  final Duration maxRetryDelay;

  /// Должен ли нативный плеер автоматически повторять попытки после 
  /// восстановимых ошибок (HTTP 5xx, таймауты сети и т.д.).
  final bool autoRetry;

  /// Дополнительный таймаут для повторной буферизации перед тем, 
  /// как считать воспроизведение застопорившимся.
  final Duration? rebufferTimeout;

  const RhsPlaybackOptions({
    this.maxRetryCount = 3,
    this.initialRetryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(seconds: 10),
    this.autoRetry = true,
    this.rebufferTimeout,
  });

  /// Сериализует этот экземпляр для нативных платформенных слоев.
  Map<String, dynamic> toMap() => {
    'maxRetryCount': maxRetryCount,
    'initialRetryDelayMs': initialRetryDelay.inMilliseconds,
    'maxRetryDelayMs': maxRetryDelay.inMilliseconds,
    'autoRetry': autoRetry,
    'rebufferTimeoutMs': rebufferTimeout?.inMilliseconds,
  };
}
