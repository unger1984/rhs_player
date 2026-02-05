# План рефакторинга Example по FSD архитектуре

## Текущее состояние

### Проблемы архитектуры

- Плоская структура без слоёв FSD (app/pages/features/entities/shared)
- PlayerScreen - монолитный экран без разделения на слои
- Controls система в корне `lib/controls/` вместо `features/player/ui/controls/`
- Бизнес-логика смешана с UI в State классах
- UI компоненты (`control_button.dart`, `play_pause_control_button.dart`, `progress_slider.dart`) в корне `lib/`

### Дублирование кода

- Функция `_focusGlow()` дублируется в 4 файлах
- Цвета хардкодятся во всех компонентах (например, `Color(0xFF201B2E)`)
- Размеры и длительности разбросаны по файлам

### Отсутствие структуры данных

- Фильмы загружаются из JSON без типизированной модели
- `RecommendedCarouselItem` - простая модель без связи с бизнес-сущностями
- Нет репозитория для работы с данными

## Целевая FSD архитектура

### Структура папок

```
example/lib/
  app/                              # Слой app (инициализация, конфигурация)
    main.dart                       # Точка входа приложения

  pages/                            # Слой pages (экраны приложения)
    player/
      player_page.dart              # PlayerScreen → PlayerPage (упрощенная страница)

  features/                         # Слой features (бизнес-фичи)
    player/                         # Фича воспроизведения видео
      model/                        # Бизнес-логика и состояние
        player_state.dart           # Управление плеером (контроллер, треки, меню)
      ui/                           # UI компоненты фичи
        controls/                   # Система управления (ВНУТРИ player UI)
          core/
            control_row.dart
            focusable_item.dart
            key_handling_result.dart
          items/
            button_item.dart
            custom_widget_item.dart
            progress_slider_item.dart
            quality_selector_item.dart
            soundtrack_selector_item.dart
          rows/
            full_width_row.dart
            horizontal_button_row.dart
            recommended_carousel_row.dart
            three_zone_button_row.dart
            top_bar_row.dart
          navigation/
            navigation_manager.dart
          builder/
            video_controls_builder.dart
          widgets/                  # UI компоненты controls
            control_button.dart     # Переместить из корня
            play_pause_button.dart  # Переименовать из play_pause_control_button
            progress_slider.dart    # Переместить из корня
          video_controls.dart       # Главный виджет controls (упростить)
        player_view.dart            # Виджет плеера с overlay

  entities/                         # Слой entities (бизнес-сущности)
    media/
      model/
        media_item.dart             # Модель медиа-контента

  shared/                           # Слой shared (переиспользуемое)
    api/
      media_repository.dart         # Репозиторий загрузки фильмов
    ui/
      theme/
        app_colors.dart             # Палитра цветов
        app_sizes.dart              # Размеры компонентов
        app_durations.dart          # Длительности
        focus_decoration.dart       # Общая функция focus glow
      widgets/
        buffering_overlay.dart      # Индикатор буферизации

  films.json                        # Данные остаются в корне
  assets/                           # Ассеты остаются в корне
```

## Этапы рефакторинга

### Этап 1: Создание shared слоя

Весь переиспользуемый код выносится в shared.

#### 1.1 shared/ui/theme/

**app_colors.dart**:

```dart
abstract class AppColors {
  // Цвета кнопок
  static const buttonBgNormal = Color(0xFF201B2E);
  static const buttonBgHover = Color(0xFF2A303C);
  static const buttonBgPressed = Color(0xFF0C0D1D);
  static const iconPressed = Color(0xFF201B2E);

  // Цвета play/pause
  static const playPauseNormal = Color(0xFFDF3F1E);  // red/600
  static const playPauseHover = Color(0xFFF45E3F);   // red/500
  static const playPausePressed = Color(0xFFBD3418); // red/700

  // Цвета слайдера
  static const sliderActive = Color(0xFFF45E3F);
  static const sliderInactive = Color(0xFF757B8A);
  static const sliderBuffered = Color(0xFFB0B4BF);
  static const sliderThumbFillUnfocused = Color(0xFFEFF1F5);

  // Focus glow
  static const focusGlowBlue = Color(0xFFB3E5FC);

  // Прочее
  static const backgroundDark = Color(0xFF2A303C);
}
```

**app_sizes.dart**:

```dart
abstract class AppSizes {
  // Кнопки
  static const double buttonNormal = 112;
  static const double buttonPlayPause = 136;
  static const double buttonBorderRadius = 16;

  // Слайдер
  static const double sliderThumbNormal = 16;
  static const double sliderThumbFocused = 20;
  static const double sliderTrackNormal = 12;
  static const double sliderTrackFocused = 16;

  // Focus glow
  static const double focusGlowSpread1 = 4;
  static const double focusGlowBlur1 = 20;
  static const double focusGlowSpread2 = 2;
  static const double focusGlowBlur2 = 12;
}
```

**app_durations.dart**:

```dart
abstract class AppDurations {
  static const controlsAutoHide = Duration(seconds: 5);
  static const seekingOverlay = Duration(seconds: 2);
  static const repeatInterval = Duration(milliseconds: 300);
  static const controlsAnimation = Duration(milliseconds: 300);
}
```

**focus_decoration.dart**:

```dart
// Единая функция вместо 4 дублей
List<BoxShadow> buildFocusGlow() { ... }

// Для Canvas (progress_slider)
void paintFocusGlow(Canvas canvas, Offset center, double radius) { ... }
```

#### 1.2 shared/api/

**media_repository.dart**:

```dart
class MediaRepository {
  Future<List<MediaItem>> loadMediaItems() async {
    // Парсинг films.json
  }
}
```

#### 1.3 shared/ui/widgets/

**buffering_overlay.dart**:

```dart
class BufferingOverlay extends StatelessWidget {
  final RhsPlayerController controller;
  // Вынести из video_controls.dart
}
```

### Этап 2: Создание entities слоя

#### entities/media/model/media_item.dart

```dart
class MediaItem {
  final String id;
  final String title;
  final String url;
  final String? drmLicenseUrl;
  final Widget? poster;

  const MediaItem({ ... });

  RhsMediaSource toMediaSource() {
    return RhsMediaSource(
      url,
      drm: drmLicenseUrl != null && drmLicenseUrl!.isNotEmpty
        ? RhsDrmConfig(type: RhsDrmType.widevine, licenseUrl: drmLicenseUrl!)
        : const RhsDrmConfig(type: RhsDrmType.none),
    );
  }

  // Преобразование в RecommendedCarouselItem для controls
  RecommendedCarouselItem toCarouselItem() { ... }
}
```

### Этап 3: Создание features/player

#### 3.1 features/player/model/player_state.dart

Вынести всю логику из `_PlayerScreenContentState`:

```dart
class PlayerState {
  final MediaRepository _repository;
  late final RhsPlayerController controller;

  List<MediaItem> _mediaItems = [];
  MediaItem? _currentItem;

  // Callback для обновления UI
  void Function()? onStateChanged;

  Future<void> initialize() async {
    // Создание контроллера
    // Загрузка фильмов
    // Подписка на события
  }

  void playMedia(MediaItem item) { ... }

  List<MediaItem> getRecommendedItems() {
    // Фильтрация без текущего
  }

  void dispose() { ... }
}
```

#### 3.2 features/player/ui/controls/

##### Перемещение UI компонентов

1. **widgets/control_button.dart** (переместить из `lib/control_button.dart`):

- Заменить хардкод на `AppColors`, `AppSizes`, `AppDurations`
- Заменить `_focusGlow()` на `buildFocusGlow()`

1. **widgets/play_pause_button.dart** (переименовать из `play_pause_control_button.dart`):

- Заменить хардкод на `AppColors`, `AppSizes`
- Заменить `_focusGlow()` на `buildFocusGlow()`

1. **widgets/progress_slider.dart** (переместить из `lib/progress_slider.dart`):

- Заменить хардкод на `AppColors`, `AppSizes`, `AppDurations`
- Заменить `_paintFocusGlow()` на `paintFocusGlow()`

##### Обновление зависимых компонентов

- **items/button_item.dart**: обновить импорт `ControlButton`
- **items/progress_slider_item.dart**: обновить импорт `ProgressSlider`
- **items/quality_selector_item.dart**: использовать `AppColors`, `buildFocusGlow()`
- **items/soundtrack_selector_item.dart**: аналогично
- **rows/recommended_carousel_row.dart**: использовать `MediaItem` вместо простой модели

##### Упрощение video_controls.dart

Вынести логику управления состоянием:

```dart
// Оставить в video_controls.dart только UI композицию
class VideoControls extends StatefulWidget { ... }

class _VideoControlsState extends State<VideoControls> {
  // Минимальная логика UI (видимость, таймеры)
  // Без бизнес-логики треков, меню и т.д.

  @override
  Widget build(BuildContext context) {
    return VideoControlsBuilder(
      rows: _buildRows(),
      // ...
    );
  }
}
```

#### 3.3 features/player/ui/player_view.dart

Виджет плеера с overlay:

```dart
class PlayerView extends StatelessWidget {
  final RhsPlayerController controller;
  final List<MediaItem> recommendedItems;
  final void Function(MediaItem)? onItemSelected;

  @override
  Widget build(BuildContext context) {
    return RhsPlayerView(
      controller: controller,
      boxFit: BoxFit.contain,
      overlay: VideoControls(
        controller: controller,
        recommendedItems: recommendedItems.map((e) => e.toCarouselItem()).toList(),
        onRecommendedItemActivated: (item) {
          // Найти MediaItem и вызвать callback
        },
      ),
    );
  }
}
```

### Этап 4: Создание pages слоя

#### pages/player/player_page.dart

Упрощенная страница - только UI композиция:

```dart
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlayerState _playerState;

  @override
  void initState() {
    super.initState();
    _playerState = PlayerState(MediaRepository());
    _playerState.onStateChanged = () => setState(() {});
    _playerState.initialize();
  }

  @override
  void dispose() {
    _playerState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Логика back (возможно делегировать в PlayerState)
        Navigator.maybePop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: PlayerView(
              controller: _playerState.controller,
              recommendedItems: _playerState.getRecommendedItems(),
              onItemSelected: _playerState.playMedia,
            ),
          ),
        ),
      ),
    );
  }
}
```

### Этап 5: Создание app слоя

#### app/main.dart

Переместить `main.dart` из корня в `app/`:

```dart
import 'package:rhs_player_example/pages/player/player_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
      splitScreenMode: false,
      builder: (_, child) => MaterialApp(
        title: 'Rhs_player Example',
        home: PlayerPage(),  // Обновленный импорт
      ),
    );
  }
}
```

### Этап 6: Обновление импортов и очистка

#### 6.1 Обновление всех импортов

Пройтись по всем файлам и обновить пути:

- `import 'package:rhs_player_example/shared/ui/theme/app_colors.dart'`
- `import 'package:rhs_player_example/features/player/ui/controls/widgets/control_button.dart'`
- `import 'package:rhs_player_example/entities/media/model/media_item.dart'`
- И т.д.

#### 6.2 Удаление дублирования

- Удалить все дубли `_focusGlow()` из `control_button.dart`, `play_pause_button.dart`, `progress_slider.dart`, `quality_selector_item.dart`
- Удалить хардкод цветов, размеров, длительностей
- Удалить старые файлы из корня `lib/` после перемещения

#### 6.3 Форматирование и проверка

```bash
fvm dart format .
fvm flutter analyze .
cd example && fvm flutter run  # Проверка работоспособности
```

## Соответствие FSD слоям

### app/

Инициализация приложения, конфигурация, точка входа.

- `main.dart` - создание MaterialApp, настройка ScreenUtil

### pages/

Страницы приложения (роуты). В будущем могут быть: catalog, profile, settings.

- `player/player_page.dart` - страница плеера (сейчас единственная)

### features/

Бизнес-фичи приложения. Каждая фича - независимый модуль.

- `player/` - фича воспроизведения видео
  - `model/` - бизнес-логика (PlayerState)
  - `ui/` - UI компоненты (controls, player_view)

### entities/

Бизнес-сущности, переиспользуемые между фичами.

- `media/model/media_item.dart` - модель медиа-контента

### shared/

Переиспользуемый код без привязки к бизнес-логике.

- `api/` - репозитории, сервисы
- `ui/` - theme, общие виджеты

## Преимущества после рефакторинга

### FSD архитектура

- Чёткое разделение по слоям (app → pages → features → entities → shared)
- Каждый слой имеет свою ответственность
- Возможность масштабирования (добавление новых pages, features)

### Поддерживаемость

- PlayerState инкапсулирует всю бизнес-логику плеера
- UI компоненты чистые, без бизнес-логики
- Легко тестировать model слои

### Расширяемость

- Добавление новых страниц (catalog, profile) - в `pages/`
- Добавление новых фич - в `features/`
- Переиспользование entities и shared между фичами

### Устранение дублирования

- Единая `buildFocusGlow()` в `shared/ui/theme/`
- Централизованные константы (AppColors, AppSizes, AppDurations)
- Единая модель MediaItem

### Читаемость

- Структура папок соответствует FSD стандарту
- Понятно, где искать: страницы (pages), фичи (features), сущности (entities)
- Малые файлы с чёткой ответственностью

## Примечания

- Система controls остаётся внутри `features/player/ui/controls/` - она часть UI фичи player
- Логика Chain of Responsibility и навигации сохраняется без изменений
- API компонентов не меняется - изменения обратно совместимы
- После рефакторинга запустить: `fvm dart format .` и `fvm flutter analyze .`
