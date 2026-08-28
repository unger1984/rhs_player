import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player/rhs_player_method_channel.dart';
import 'package:rhs_player/rhs_player_platform_interface.dart';

class MockRhsPlayerPlatform
    with MockPlatformInterfaceMixin
    implements RhsPlayerPlatform {
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

  test('serializes FairPlay configuration for the native player', () async {
    final controller = RhsPlayerController.single(
      const RhsMediaSource(
        'https://example.com/master.m3u8',
        drm: RhsDrmConfig(
          type: RhsDrmType.fairPlay,
          licenseUrl: 'https://example.com/license',
          certificateUrl: 'https://example.com/certificate.der',
        ),
      ),
    );

    final playlist = controller.creationParams['playlist'] as List<Object?>;
    final source = playlist.single as Map<String, Object?>;
    final drm = source['drm'] as Map<String, Object?>;

    expect(drm['type'], 'fairPlay');
    expect(drm['licenseUrl'], 'https://example.com/license');
    expect(drm['certificateUrl'], 'https://example.com/certificate.der');
    await controller.dispose();
  });

  testWidgets('sends a media source loaded before the native view attaches', (
    tester,
  ) async {
    const viewId = 41;
    const methodChannel = MethodChannel('rhsplayer/view_$viewId');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      methodChannel,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    final controller = RhsPlayerController.single(
      const RhsMediaSource('https://example.com/placeholder.mp4'),
    );
    const source = RhsMediaSource(
      'https://example.com/master.m3u8',
      drm: RhsDrmConfig(
        type: RhsDrmType.fairPlay,
        licenseUrl: 'https://example.com/license',
        certificateUrl: 'https://example.com/certificate.der',
      ),
    );

    await controller.loadMediaSource(source);
    expect(calls, isEmpty);

    controller.attachViewId(viewId);
    await tester.pump();

    final loadCall = calls.singleWhere(
      (call) => call.method == 'loadMediaSource',
    );
    final arguments = loadCall.arguments as Map<Object?, Object?>;
    final nativeSource = arguments['source'] as Map<Object?, Object?>;
    expect(nativeSource['url'], source.url);

    await controller.dispose();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      methodChannel,
      null,
    );
  });
}
