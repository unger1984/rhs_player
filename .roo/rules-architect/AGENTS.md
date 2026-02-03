# Project Architecture Rules (Non-Obvious Only)

- Strict 1:1 mapping: 1 Controller = 1 native player
- All logic lives in Controller, no state in Widget
- Use TextureRegistry only (no SurfaceView / PlatformView for video)
- No singleton ExoPlayer instances allowed
- SharedPlayerRegistry with reference counting for memory management
- Explicit lifecycle: create → release
- Separate event channels for different data types:
  - Playback state (position, duration, buffering, playing, error)
  - Track information (video/audio/subtitle tracks)
- No polling - native side pushes updates
- Method channels are view-specific (rhsplayer/view_$id)
- attachViewId() method binds controller to native view ID
- Video track selection requires double approach: override + max size/bitrate
- Audio suppression during buffering to prevent audio glitches
- Ready fallback timer for edge cases in playback start
- Data saver mode applies bitrate limits through track selection