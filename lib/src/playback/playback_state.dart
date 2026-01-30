/// Снимок текущей позиции воспроизведения, сообщаемой нативным слоем.
class RhsPlaybackState {
  /// Текущая позиция воспроизведения
  final Duration position;
  
  /// Общая продолжительность медиа
  final Duration duration;
  
  /// Флаг воспроизведения
  final bool isPlaying;
  
  /// Флаг буферизации
  final bool isBuffering;

  const RhsPlaybackState({
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isBuffering,
  });
}
