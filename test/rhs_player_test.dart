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
    expect(drm['fairPlayLicenseFormat'], 'playerNow');
    await controller.dispose();
  });

  test('passes Kinescope FairPlay format to the native player', () async {
    final controller = RhsPlayerController.single(
      const RhsMediaSource(
        'https://example.com/master.m3u8',
        drm: RhsDrmConfig(
          type: RhsDrmType.fairPlay,
          licenseUrl: 'https://example.com/license',
          certificateUrl: 'https://example.com/certificate.der',
          fairPlayLicenseFormat: RhsFairPlayLicenseFormat.kinescope,
        ),
      ),
    );
    final playlist = controller.creationParams['playlist'] as List<Object?>;
    final source = playlist.single as Map<String, Object?>;
    final drm = source['drm'] as Map<String, Object?>;
    expect(drm['fairPlayLicenseFormat'], 'kinescope');
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

  testWidgets('preserves native error details through status and clears them', (
    tester,
  ) async {
    const viewId = 52;
    const eventChannelName = 'rhsplayer/events_$viewId';
    const tracksChannelName = 'rhsplayer/tracks_$viewId';
    const cuesChannelName = 'rhsplayer/cues_$viewId';
    const viewChannel = MethodChannel('rhsplayer/view_$viewId');
    const codec = StandardMethodCodec();
    final messenger = tester.binding.defaultBinaryMessenger;

    Future<ByteData?> handleListen(ByteData? _) {
      return Future.value(codec.encodeSuccessEnvelope(null));
    }

    messenger.setMockMessageHandler(eventChannelName, handleListen);
    messenger.setMockMessageHandler(tracksChannelName, handleListen);
    messenger.setMockMessageHandler(cuesChannelName, handleListen);
    messenger.setMockMethodCallHandler(viewChannel, (call) async => <Object>[]);

    final controller = RhsPlayerController.single(
      const RhsMediaSource('https://example.com/video.m3u8'),
    );
    controller.attachViewId(viewId);
    await tester.pump();

    await messenger.handlePlatformMessage(
      eventChannelName,
      codec.encodeSuccessEnvelope(const <String, Object>{
        'positionMs': 0,
        'durationMs': 0,
        'bufferedPositionMs': 0,
        'isBuffering': false,
        'isPlaying': false,
        'error': 'ERROR_CODE_DRM_PROVISIONING_FAILED',
        'errorDetails': 'PlaybackException(code=6002)',
      }),
      (_) {},
    );
    await tester.pump();

    final errorStatus = controller.currentPlayerStatus;
    expect(errorStatus, isA<RhsPlayerStatusError>());
    expect(
      (errorStatus as RhsPlayerStatusError).message,
      'ERROR_CODE_DRM_PROVISIONING_FAILED',
    );
    expect(errorStatus.errorDetails, 'PlaybackException(code=6002)');

    await messenger.handlePlatformMessage(
      eventChannelName,
      codec.encodeSuccessEnvelope(const <String, Object>{
        'positionMs': 1000,
        'durationMs': 5000,
        'bufferedPositionMs': 2000,
        'isBuffering': false,
        'isPlaying': false,
        'error': 'ERROR_CODE_IO_NETWORK_CONNECTION_FAILED',
      }),
      (_) {},
    );
    await tester.pump();

    final legacyErrorStatus = controller.currentPlayerStatus;
    expect(legacyErrorStatus, isA<RhsPlayerStatusError>());
    expect((legacyErrorStatus as RhsPlayerStatusError).errorDetails, isNull);

    await messenger.handlePlatformMessage(
      eventChannelName,
      codec.encodeSuccessEnvelope(const <String, Object>{
        'positionMs': 1000,
        'durationMs': 5000,
        'bufferedPositionMs': 2000,
        'isBuffering': false,
        'isPlaying': true,
      }),
      (_) {},
    );
    await tester.pump();

    expect(controller.currentPlayerStatus, isA<RhsPlayerStatusPlaying>());

    await controller.dispose();
    messenger.setMockMessageHandler(eventChannelName, null);
    messenger.setMockMessageHandler(tracksChannelName, null);
    messenger.setMockMessageHandler(cuesChannelName, null);
    messenger.setMockMethodCallHandler(viewChannel, null);
  });
}
