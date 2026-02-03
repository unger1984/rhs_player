# GEMINI.md: rhs_player

[AGENTS.md](AGENTS.md)

## Project Overview

This project is a Flutter video player plugin named `rhs_player`. It is designed for Android only and uses the native ExoPlayer engine for network-based video streaming. The project is a fork of the `tha_player` plugin and has removed iOS support to focus solely on Android.

**Main Technologies:**

- Flutter (Dart)
- Native Android (Kotlin/ExoPlayer)

**Key Features:**

- Standard playback controls (play, pause, seek, speed).
- Video quality and audio track selection.
- DRM support for Widevine and ClearKey.
- Advanced buffering and retry options.
- Specialized support for Android TV remote control, including focus navigation and visual feedback.
- Thumbnail previews via VTT files.

## Building and Running

### Setup

1.  Get the project dependencies:
    ```bash
    flutter pub get
    ```

### Running the Example Application

The `example/` directory contains a sample application that demonstrates the player's functionality.

1.  Navigate to the example directory:
    ```bash
    cd example
    ```
2.  Run the application:
    ```bash
    flutter run
    ```

**Note on Emulators:** As noted in the example code, DRM-protected content (like Widevine) may not work correctly on an Android emulator. For testing, it is recommended to use a physical device or a media source without DRM, such as:
`https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4`

### Running Tests

To run the project's unit tests, execute the following command from the root directory:

```bash
flutter test
```

## Development Conventions

### Coding Style

The project follows the standard Dart and Flutter analysis rules defined in the `flutter_lints` package. All contributions should adhere to these guidelines to ensure code consistency.

### Documentation

- The primary source of documentation is the `README.md` file, which is written in Russian. It provides a comprehensive overview of the API, features, and usage.
- The `example/` directory and its source files (especially `player_screen.dart`) serve as the best practical reference for understanding how to integrate and use the player.

### Key Files

- `pubspec.yaml`: Defines the project as a Flutter plugin and lists its dependencies.
- `README.md`: Detailed project documentation (in Russian).
- `lib/rhs_player.dart`: The main public API and entry point for the plugin.
- `lib/src/player/player_controller.dart`: The core class for controlling video playback, managing media sources, and listening to events.
- `android/src/main/kotlin/com/example/rhs_player/`: The directory containing the native Kotlin code that integrates ExoPlayer.
- `example/lib/player_screen.dart`: A complete, working example demonstrating player initialization, event handling, and UI integration.
