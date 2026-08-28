# rhs_player

Нативный видеоплеер для Flutter только для сетевых источников. Использует ExoPlayer на Android и AVPlayer на iOS.

Форк [tha_player](https://github.com/thethtwe-dev/tha_player).

---

## Возможности

- ExoPlayer (Android) и AVPlayer (iOS)
- Воспроизведение / пауза, перемотка, скорость, полноэкранный режим
- BoxFit (contain, cover, fill, fitWidth, fitHeight)
- Выбор качества видео, аудиодорожек
- Единое состояние: позиция, буфер, ошибка в одном потоке
- Индикатор буферизации на прогресс-баре (как в YouTube)
- DRM: Widevine/ClearKey на Android, FairPlay Streaming на iOS
- Опции повторных попыток и буферизации
- **Поддержка Android TV пульта** — фокус-навигация с визуальным выделением

---

## Установка

В `pubspec.yaml`:

```yaml
dependencies:
  rhs_player: ^0.5.0
```

```bash
flutter pub get
```

---

## Быстрый старт

```dart
import 'package:rhs_player/rhs_player.dart';

// Контроллер с одним источником
final ctrl = RhsPlayerController.single(
  RhsMediaSource('https://example.com/video.mp4'),
  autoPlay: true,
  loop: false,
  playbackOptions: const RhsPlaybackOptions(
    maxRetryCount: 5,
    initialRetryDelay: Duration(milliseconds: 800),
  ),
);

// В build: видео + контролы через overlay
AspectRatio(
  aspectRatio: 16 / 9,
  child: RhsPlayerView(
    controller: ctrl,
    boxFit: BoxFit.contain,
    overlay: StreamBuilder<RhsNativeEvents?>(
      stream: ctrl.eventsStream,
      builder: (context, eventsSnapshot) {
        if (!eventsSnapshot.hasData || eventsSnapshot.data == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return StreamBuilder<RhsPlaybackState>(
          stream: ctrl.playbackStateStream,
          initialData: ctrl.currentPlaybackState,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data!;
            if (state.duration == Duration.zero && state.error == null) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            return PlayerControls(
              controller: ctrl,
              state: state,
              formatDuration: (d) =>
                  '${d.inMinutes.toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}',
            );
          },
        );
      },
    ),
  ),
);

// Не забудьте вызвать ctrl.dispose() в State.dispose()
```

---

## API

### RhsPlayerController

- `RhsPlayerController.single(RhsMediaSource source, {autoPlay, loop, playbackOptions})` — один источник
- `RhsPlayerController.playlist(List<RhsMediaSource> playlist, ...)` — плейлист
- `play()`, `pause()`, `seekTo(Duration)`, `setSpeed(double)`, `setLooping(bool)`, `setBoxFit(BoxFit)`
- `playbackStateStream` — поток `RhsPlaybackState` (позиция, длительность, буфер, isPlaying, isBuffering, error)
- `currentPlaybackState`, `currentError` — текущее состояние
- `eventsStream` — поток `RhsNativeEvents?` (появляется после привязки view)
- `getVideoTracks()`, `selectVideoTrack(id)`, `getAudioTracks()`, `selectAudioTrack(id?)`, `getSubtitleTracks()`, `selectSubtitleTrack(id?)`
- `dispose()` — освобождение ресурсов

### RhsPlaybackState

Один объект состояния: `position`, `duration`, `bufferedPosition`, `isPlaying`, `isBuffering`, `error` (сообщение об ошибке или null). Воспроизведение и ошибка взаимоисключают друг друга.

### RhsPlayerView

- `controller` — обязательно
- `boxFit` — по умолчанию `BoxFit.contain`
- `overlay` — необязательный виджет поверх видео (например, `PlayerControls`)

### PlayerControls

Готовый overlay: кнопки воспроизведения/паузы, перемотка, прогресс-бар с буфером, качество, аудиодорожки, полноэкран. Принимает `controller`, `state` (`RhsPlaybackState`), `formatDuration`, опционально `isFullscreen`.

### RhsMediaSource

- `url` — URL потока или манифеста (HLS/DASH/MP4)
- `headers` — опциональные HTTP-заголовки
- `drm` — конфигурация DRM
- `thumbnailVttUrl`, `thumbnailHeaders` — опционально для миниатюр

### DRM

Widevine и ClearKey поддерживаются только на Android:

```dart
RhsMediaSource(
  'https://example.com/manifest.mpd',
  drm: const RhsDrmConfig(
    type: RhsDrmType.widevine,
    licenseUrl: 'https://license.example.com/wv',
    headers: {'Authorization': 'Bearer <token>'},
  ),
)
```

FairPlay для CBCS-HLS поддерживается только на iOS. License endpoint PlayerNow
должен принимать JSON `content_id`/`spc_message` и возвращать `ckc_message`:

```dart
RhsMediaSource(
  'https://p63022.nowcdn.co/done/cbcs/'
  'bbc11979b3f3ae1bfa020a157eebc0467c609e98/master.m3u8',
  drm: const RhsDrmConfig(
    type: RhsDrmType.fairPlay,
    licenseUrl: 'https://drm93075.nowdrm.co/fairplay',
    certificateUrl: 'https://cdn.playernow.ru/pronow.der',
  ),
)
```

`contentId` можно задать явно. Если он не указан, iOS берёт hostname из
`skd://` URI в HLS-манифесте. `headers` отправляются при загрузке сертификата
и лицензии.

### RhsPlaybackOptions

- `maxRetryCount` — макс. число повторных попыток
- `initialRetryDelay`, `maxRetryDelay` — задержки между попытками
- `autoRetry` — автоматические повторы
- `rebufferTimeout` — таймаут повторной буферизации

---

## Платформы

| Возможность | Android | iOS |
|---|---|---|
| Движок | ExoPlayer | AVPlayer |
| MP4 / HLS | Да | Да |
| DASH | Да | Нет (ограничение AVPlayer) |
| Widevine / ClearKey | Да | Нет |
| FairPlay CBCS-HLS | Нет | Да |
| Аудио и субтитры | Да | Да |
| PiP | Да | Да, при включённых Background Modes в приложении |

AVPlayer не предоставляет полный список вариантов HLS заранее, поэтому на iOS
список качества формируется из уже наблюдавшихся битрейтов. `fitWidth` и
`fitHeight` на iOS отображаются как `contain`.

---

## Android TV поддержка

Плеер автоматически поддерживает управление с пульта Android TV с фокус-навигацией:

### Когда контролы скрыты:
- **Стрелки влево/вправо** — перемотка на 10 секунд назад/вперед
- **Стрелка вверх или OK** — показать контролы с автоматической установкой фокуса

### Когда контролы видны:
- **Навигация с пульта:**
  - При первом нажатии фокус устанавливается автоматически (вверх → Play/Pause, влево/вправо → первая кнопка, OK → Play/Pause)
  - **Стрелки влево/вправо** — переключение между кнопками в ряду (качество → аудио → перемотка назад → play/pause → перемотка вперед → fullscreen)
  - На крайних кнопках стрелки не выходят за границы
  - **Стрелка вверх** — с нижнего ряда на прогресс-бар
  - **Стрелка вниз** — с прогресс-бара на Play/Pause, с нижнего ряда — скрыть контролы
  - **OK/Enter** — активировать кнопку
- **На прогресс-баре:**
  - Короткое нажатие влево/вправо — перемотка на 10 секунд
  - Длительное нажатие (удержание) — непрерывная перемотка с ускорением (1с → 2с → 3с → 5с → 10с)

### Работа с мышью и пультом:
- **Одновременная работа** — мышь и пульт работают одновременно без конфликтов
- **Мышь** — клик сбрасывает визуальный фокус, но запоминает последнюю позицию
- **Пульт** — автоматически восстанавливает фокус на последней позиции при нажатии
- **Fullscreen** — фокус сохраняется при переходе в fullscreen и обратно
- Можно переключаться между мышью и пультом без потери контекста
- При нажатии любой клавиши таймер автоскрытия сбрасывается

### Визуальная индикация:
- Кнопка в фокусе выделяется белой рамкой и полупрозрачным фоном
- Фокус виден только при использовании пульта

### Настройка AndroidManifest.xml:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Поддержка Android TV -->
    <uses-feature
        android:name="android.software.leanback"
        android:required="false" />
    <uses-feature
        android:name="android.hardware.touchscreen"
        android:required="false" />
    
    <application ...>
        <activity ...>
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
                <!-- Поддержка Android TV launcher -->
                <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

---

## Известные проблемы

1. **Скрытие и появление контролов** — автоскрытие и показ панели управления (PlayerControls) работают не совсем корректно; поведение может отличаться от ожидаемого.

---

## Пример

В каталоге `example/` — приложение с `RhsPlayerView`, `PlayerControls`, DRM и полноэкранным режимом.

---

## Лицензия

MIT — см. `LICENSE`.
