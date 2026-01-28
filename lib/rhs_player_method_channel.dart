import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'rhs_player_platform_interface.dart';

/// An implementation of [RhsPlayerPlatform] that uses method channels.
class MethodChannelRhsPlayer extends RhsPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('rhs_player');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
