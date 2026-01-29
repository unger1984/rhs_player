# Project Rules for rhs_player

## Goal

Rewrite rhs_player as a thin Flutter <-> Android wrapper over ExoPlayer (Media3).

Expose:

- RhsPlayerController
- RhsPlayerView (video only, no controls)

No UI, no business logic, no compatibility with tha_player required.

---

## Architecture Rules (MANDATORY)

### Flutter

- 1 Controller = 1 native player
- All logic lives in Controller
- No state in Widget

### Android

- Use androidx.media3 ExoPlayer only
- Use Flutter TextureRegistry (no SurfaceView / PlatformView)
- No singleton ExoPlayer
- Explicit lifecycle: create → release

---

## Events Model (STRICT)

Expose separate listeners in Flutter:

- progress (position, duration)
- buffering
- playback state (loading, play / pause / ended)
- tracks (quality selection)
- error

Forbidden:

- polling with Timer
- one generic Map<String, dynamic> stream

---

## DRM

- DRM config comes from Flutter
- Native side must not store keys
- Use Media3 DRM APIs only

---

## Track Selection

- Use DefaultTrackSelector
- Expose available video tracks
- Allow manual quality selection
- Support auto quality mode

---

## Forbidden Anti-Patterns

- Singleton ExoPlayer
- UI in native code
- Stateful Widgets for playback logic
- Timers for progress
- Hidden side effects
- Logging DRM data

---

## Refactoring Rules

- Do NOT delete old code
- Add new components only
- Old RhsModernPlayer must remain untouched
