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
- Android TV remote support with focus navigation

## Android TV Support
- FocusableControlButton — виджет кнопки с визуальным выделением при фокусе
- PlayerControls с встроенной фокус-навигацией через FocusNode
- Обработка клавиш пульта:
  - Навигация D-pad между элементами управления
  - Автоматическое скрытие/показ контролов
  - Непрерывная перемотка при длительном нажатии
  - Визуальная индикация фокуса (белая рамка + полупрозрачный фон)
