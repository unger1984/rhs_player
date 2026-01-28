import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Snapshot of the current playback position reported by the native layer.
class RhsPlaybackState {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isBuffering;

  const RhsPlaybackState({
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isBuffering,
  });
}

/// Listens to the platform event channel and exposes playback state updates.
class RhsNativeEvents {
  final int viewId;
  late final EventChannel _eventChannel;
  StreamSubscription? _sub;

  final ValueNotifier<RhsPlaybackState> state = ValueNotifier(
    const RhsPlaybackState(position: Duration.zero, duration: Duration.zero, isPlaying: false, isBuffering: true),
  );

  // Emits non-null when native side reports an error; clear when playback resumes.
  final ValueNotifier<String?> error = ValueNotifier(null);

  RhsNativeEvents(this.viewId) {
    _eventChannel = EventChannel('rhsplayer/events_$viewId');
  }

  void start() {
    _sub?.cancel();
    _sub = _eventChannel.receiveBroadcastStream().listen(_onEvent, onError: (_) {});
  }

  void _onEvent(dynamic evt) {
    if (evt is Map) {
      final posMs = (evt['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (evt['durationMs'] as num?)?.toInt() ?? 0;
      final playing = evt['isPlaying'] == true;
      final buffering = evt['isBuffering'] == true;
      final errMsg = evt['error'] as String?;
      if (errMsg != null && errMsg.isNotEmpty) {
        error.value = errMsg;
      } else if (playing) {
        // Clear error once playback resumes
        error.value = null;
      }
      state.value = RhsPlaybackState(
        position: Duration(milliseconds: posMs),
        duration: Duration(milliseconds: durMs),
        isPlaying: playing,
        isBuffering: buffering,
      );
    }
  }

  void dispose() {
    _sub?.cancel();
    state.dispose();
    error.dispose();
  }
}
