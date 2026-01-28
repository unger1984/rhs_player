import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'rhs_player_method_channel.dart';

abstract class RhsPlayerPlatform extends PlatformInterface {
  /// Constructs RhsPlayerPlatform.
  RhsPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static RhsPlayerPlatform _instance = MethodChannelRhsPlayer();

  /// The default instance of [RhsPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelRhsPlayer].
  static RhsPlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RhsPlayerPlatform] when
  /// they register themselves.
  static set instance(RhsPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
