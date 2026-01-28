# rhs_player example

This example shows how to use the native player with modern controls.

## Run

```
cd example
flutter run
```

## Quick Start Snippet

```
final ctrl = RhsNativePlayerController.single(
  RhsMediaSource(
    'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    // thumbnailVttUrl: 'https://example.com/thumbs.vtt',
  ),
  autoPlay: true,
);

AspectRatio(
  aspectRatio: 16 / 9,
  child: RhsModernPlayer(
    controller: ctrl,
    doubleTapSeek: Duration(seconds: 10),
    autoHideAfter: Duration(seconds: 3),
  ),
)
```
