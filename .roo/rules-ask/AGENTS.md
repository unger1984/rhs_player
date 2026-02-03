# Project Documentation Rules (Non-Obvious Only)

- Russian comments in source code - maintain consistency
- 1 Controller = 1 native player (strict 1:1 mapping)
- Controller holds ALL playback logic - no business logic in Widgets
- Events use ValueNotifier + BehaviorSubject for reactive programming
- Video tracks identified by "height:width:bitrate" string format
- Audio/subtitle tracks use "groupIndex:trackIndex" format
- Custom focus navigation system with Chain of Responsibility pattern
- Rows and items are structured in a grid for directional navigation
- ProgressSliderItem handles arrow keys for seeking
- Simultaneous mouse and remote control support for Android TV
- DRM config comes from Flutter side (native must not store keys)
- SharedPlayerRegistry manages player instances with reference counting
- Method channels are view-specific (rhsplayer/view_$id)
- No singleton ExoPlayer instances allowed