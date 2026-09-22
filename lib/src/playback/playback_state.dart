/// Снимок состояния воспроизведения: позиция, буфер, воспроизведение или ошибка.
///
/// В один момент времени либо воспроизведение (position, isPlaying, …), либо ошибка
/// ([error] != null). Одновременно playing и error быть не может.
class RhsPlaybackState {
  /// Текущая позиция воспроизведения
  final Duration position;

  /// Общая продолжительность медиа
  final Duration duration;

  /// Позиция до которой загружены данные (буфер)
  final Duration bufferedPosition;

  /// Флаг воспроизведения
  final bool isPlaying;

  /// Флаг буферизации
  final bool isBuffering;

  /// Сообщение об ошибке; при не null воспроизведение в состоянии ошибки
  final String? error;

  /// Дополнительная нативная диагностика ошибки, если её предоставила платформа.
  final String? errorDetails;

  const RhsPlaybackState({
    required this.position,
    required this.duration,
    required this.bufferedPosition,
    required this.isPlaying,
    required this.isBuffering,
    this.error,
    this.errorDetails,
  });

  @override
  String toString() {
    // TODO: implement toString
    return 'RhsPlaybackState(position: $position, duration: $duration, bufferedPosition: $bufferedPosition, isPlaying: $isPlaying, isBuffering: $isBuffering, error: $error, errorDetails: $errorDetails)';
  }
}
