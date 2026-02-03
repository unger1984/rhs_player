# Project Debug Rules (Non-Obvious Only)

- Extensive logging with android.util.Log.d in native code
- Video track selection requires double approach (override + max size)
- Ready fallback timer (700ms) for edge cases in playback start
- Audio suppression during buffering to prevent audio glitches
- SharedPlayerEntry reference counting for memory management
- WeakReference for attached views to prevent memory leaks
- Events are pushed from native side (no polling)
- Track events sent immediately when available
- Data saver mode applies bitrate limits through track selection
- Picture-in-Picture requires Android O+ and activity context
- DRM config comes from Flutter side (native must not store keys)
- Custom HTTP client provider for network requests
- MediaSessionCompat integration for system integration