import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player/rhs_player_method_channel.dart';
import 'package:rhs_player/rhs_player_platform_interface.dart';

class MockRhsPlayerPlatform with MockPlatformInterfaceMixin implements RhsPlayerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final RhsPlayerPlatform initialPlatform = RhsPlayerPlatform.instance;

  test('$MethodChannelRhsPlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRhsPlayer>());
  });

  test('getPlatformVersion', () async {
    RhsPlayer rhsPlayerPlugin = RhsPlayer();
    MockRhsPlayerPlatform fakePlatform = MockRhsPlayerPlatform();
    RhsPlayerPlatform.instance = fakePlatform;

    expect(await rhsPlayerPlugin.getPlatformVersion(), '42');
  });
}
