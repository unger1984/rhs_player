# rhs_player Architecture

## Flutter API
- RhsPlayerController
  - play / pause / seek
  - addProgressListener
  - addBufferingListener
  - addPlaybackStateListener
  - addTracksListener
  - addErrorListener
  - dispose

- RhsPlayerView
  - displays video texture only
  - no controls
  - no gestures

## Android
- Each controller owns one ExoPlayer (Media3)
- Video rendered via TextureRegistry
- Events sent via EventChannel
- Commands via MethodChannel

## Features
- DRM (Media3)
- Manual quality selection
