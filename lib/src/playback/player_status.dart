import 'package:flutter/foundation.dart';

@immutable
sealed class RhsPlayerStatus {
  const RhsPlayerStatus();
}

class RhsPlayerStatusLoading extends RhsPlayerStatus {
  const RhsPlayerStatusLoading();
}

class RhsPlayerStatusPlaying extends RhsPlayerStatus {
  const RhsPlayerStatusPlaying();
}

class RhsPlayerStatusPaused extends RhsPlayerStatus {
  const RhsPlayerStatusPaused();
}

class RhsPlayerStatusEnded extends RhsPlayerStatus {
  const RhsPlayerStatusEnded();
}

class RhsPlayerStatusError extends RhsPlayerStatus {
  final String message;
  const RhsPlayerStatusError(this.message);
}
