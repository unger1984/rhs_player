# rhs_player - Native Network Video Player Plugin

[AGENTS.md](AGENTS.md)

## Project Overview

rhs_player is a Flutter plugin that provides a native network-only video player specifically for Android. It uses ExoPlayer as the underlying engine and supports advanced features like DRM (Widevine, ClearKey), track selection, buffering indicators, and Android TV remote navigation. The plugin was forked from [tha_player](https://github.com/thethtwe-dev/tha_player) and focuses exclusively on Android platform support.

### Key Features

- **ExoPlayer-based**: Uses ExoPlayer on Android for robust video playback
- **Network-only**: Designed specifically for streaming video sources
- **Playback Controls**: Play/pause, seek, speed control, fullscreen mode
- **BoxFit Support**: Multiple BoxFit options (contain, cover, fill, fitWidth, fitHeight)
- **Track Selection**: Video, audio, and subtitle track selection capabilities
- **Unified State**: Single state object for position, buffer, and error reporting
- **Buffer Indicator**: YouTube-like buffering indicator on progress bar
- **DRM Support**: Widevine and ClearKey DRM protection
- **Retry & Buffer Options**: Configurable retry counts and buffering options
- **Android TV Support**: Remote navigation with visual focus indication
- **Picture-in-Picture**: PiP mode support where available

## Building and Running

### Prerequisites

- Flutter SDK (>=3.38.0)
- Dart SDK (^3.8.1)
- Android SDK with minimum API level 21
- FVM (recommended for version management)

### Setup Commands

```bash
# Install dependencies
fvm flutter pub get

# Format code
fvm dart format .

# Analyze code
fvm flutter analyze .

# Run tests
fvm flutter test .

# Build example app
cd example && fvm flutter run
```

### Example Usage

```dart
import 'package:rhs_player/rhs_player.dart';

// Create controller with a single media source
final ctrl = RhsPlayerController.single(
  RhsMediaSource('https://example.com/video.mp4'),
  autoPlay: true,
  loop: false,
  playbackOptions: const RhsPlaybackOptions(
    maxRetryCount: 5,
    initialRetryDelay: Duration(milliseconds: 800),
  ),
);

// In your widget tree
AspectRatio(
  aspectRatio: 16 / 9,
  child: RhsPlayerView(
    controller: ctrl,
    boxFit: BoxFit.contain,
    overlay: StreamBuilder<RhsNativeEvents?>(
      // Custom overlay implementation
    ),
  ),
);

// Remember to dispose the controller
@override
void dispose() {
  ctrl.dispose();
  super.dispose();
}
```

## Development Conventions

### Architecture

- **Platform Interface**: Abstracts platform-specific implementations
- **Method Channel**: Communicates between Dart and native Android code
- **Public API**: Clean, intuitive Dart interface for end users
- **SOLID Principles**: Strictly followed in design and implementation

### Code Style

- **Naming**: PascalCase for types, camelCase for members, snake_case for files
- **Null Safety**: Strict null safety without using the `!` operator
- **Async Operations**: Use async/await with proper error handling
- **Documentation**: Comprehensive dartdoc comments for all public APIs
- **Functions**: Keep functions under 20 lines when possible
- **Immutability**: Use `const` constructors wherever possible

### Error Handling

- Comprehensive error handling on both Dart and native sides
- Proper error propagation from native layer to Dart
- Detailed error messages for debugging

### Testing

- Unit and integration tests follow standard Flutter practices
- Example app serves as both usage demonstration and manual testing ground

## Android-Specific Implementation

### Dependencies

- androidx.media3:media3-exoplayer:1.3.1
- androidx.media3:media3-ui:1.3.1
- androidx.media3:media3-exoplayer-hls:1.3.1
- androidx.media3:media3-exoplayer-dash:1.3.1
- androidx.media3:media3-datasource-okhttp:1.3.1

### Key Classes

- `RhsPlayerPlugin`: Main plugin registration
- `RhsPlayerPlatformView`: Core Android player implementation
- `RhsPlayerViewFactory`: Platform view factory
- `SharedPlayerRegistry`: Manages ExoPlayer instances across multiple views

### Android TV Support

The plugin includes comprehensive Android TV remote navigation support:

- Arrow key navigation between controls
- Automatic focus management
- Visual focus indication
- Simultaneous mouse and remote support
- Persistent focus state during fullscreen transitions

## Project Structure

```
rhs_player/
├── lib/                    # Dart source code
│   ├── src/
│   │   ├── media/         # Media source and DRM models
│   │   ├── playback/      # Playback state and events
│   │   ├── player/        # Main player controller and view
│   │   └── tracks/        # Track models and events
│   └── rhs_player.dart    # Main library export
├── android/               # Android native implementation
│   └── src/main/kotlin/com/example/rhs_player/
├── example/               # Example application
├── test/                  # Test files
└── docs/                  # Documentation
```

## Known Issues

- Auto-hide/show behavior of controls may not work perfectly in all cases

## License

MIT License - see LICENSE file for details
