/// A data class that holds the current position and total duration of the media.
class RhsPositionData {
  /// The current playback position.
  final Duration position;

  /// The total duration of the media.
  final Duration duration;

  const RhsPositionData(this.position, this.duration);
}
