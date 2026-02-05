/// Конфигурация видимости рядов контролов плеера.
///
/// Определяет, какие ряды контролов должны быть видимы в каждом состоянии,
/// а также их параметры отображения (режим карусели, смещения для анимаций).
///
/// Обеспечивает расширяемость: при добавлении новых рядов достаточно добавить
/// новое поле в этот класс и обновить preset конфигурации, не изменяя логику State Machine.
library;

/// Режим отображения карусели рекомендаций
enum CarouselMode {
  /// Карусель полностью скрыта
  hidden,

  /// Карусель частично видна (peek) - высота 96.h
  /// Показывается верхняя часть для намёка на наличие контента
  peek,

  /// Карусель полностью развёрнута - высота 320.h
  /// Показывается при фокусе на карусели
  expanded,
}

/// Конфигурация видимости всех рядов контролов.
///
/// Каждое состояние State Machine возвращает свою конфигурацию,
/// которая используется в VideoControlsBuilder для условного рендеринга
/// и управления анимациями.
class ControlsVisibilityConfig {
  /// Показывать верхнюю панель (TopBarRow с кнопкой "Назад" и селектором саундтрека)
  final bool showTopBar;

  /// Показывать слайдер прогресса (FullWidthRow с ProgressSliderItem)
  final bool showProgressSlider;

  /// Показывать кнопки управления плеером (ThreeZoneButtonRow с play/pause, перемоткой и т.д.)
  final bool showControlButtons;

  /// Показывать карусель рекомендаций (RecommendedCarouselRow)
  final bool showCarousel;

  /// Режим отображения карусели (скрыта/peek/развёрнута)
  final CarouselMode carouselMode;

  /// Исключить все элементы контролов из фокус-дерева (ExcludeFocus).
  /// Используется когда контролы скрыты или показан только слайдер без возможности фокуса.
  final bool excludeFromFocus;

  /// Смещение для AnimatedSlide верхней панели.
  /// - 0.0 = панель видна на своём месте
  /// - -1.0 = панель скрыта вверху за границей экрана
  final double topBarSlideOffset;

  /// Смещение для AnimatedSlide нижних контролов (кнопки + карусель).
  /// - 0.0 = контролы видны на своём месте
  /// - 1.0 = контролы скрыты внизу за границей экрана
  final double bottomControlsSlideOffset;

  const ControlsVisibilityConfig({
    required this.showTopBar,
    required this.showProgressSlider,
    required this.showControlButtons,
    required this.showCarousel,
    required this.carouselMode,
    required this.excludeFromFocus,
    required this.topBarSlideOffset,
    required this.bottomControlsSlideOffset,
  });

  // ==================== Предустановленные конфигурации ====================

  /// Все контролы полностью скрыты (состояние ControlsHiddenState).
  /// Используется когда пользователь не взаимодействует с плеером.
  static const hidden = ControlsVisibilityConfig(
    showTopBar: false,
    showProgressSlider: false,
    showControlButtons: false,
    showCarousel: false,
    carouselMode: CarouselMode.hidden,
    excludeFromFocus: true,
    topBarSlideOffset: -1.0,
    bottomControlsSlideOffset: 1.0,
  );

  /// Показан только слайдер прогресса (состояние SeekingOverlayState).
  /// Используется при перемотке со скрытыми контролами - показываем слайдер
  /// на 2 секунды для визуальной обратной связи.
  static const seekingOverlay = ControlsVisibilityConfig(
    showTopBar: false,
    showProgressSlider: true, // <-- только слайдер видим
    showControlButtons: false,
    showCarousel: false,
    carouselMode: CarouselMode.hidden,
    excludeFromFocus: true, // фокус недоступен во время перемотки
    topBarSlideOffset: -1.0,
    bottomControlsSlideOffset: 1.0,
  );

  /// Все контролы видны, карусель в режиме peek (состояние ControlsVisiblePeekState).
  /// Используется как основной режим взаимодействия - все контролы доступны,
  /// карусель слегка выглядывает снизу как намёк.
  static const visiblePeek = ControlsVisibilityConfig(
    showTopBar: true,
    showProgressSlider: true,
    showControlButtons: true,
    showCarousel: true,
    carouselMode: CarouselMode.peek,
    excludeFromFocus: false,
    topBarSlideOffset: 0.0,
    bottomControlsSlideOffset: 0.0,
  );

  /// Все контролы видны, карусель полностью развёрнута (состояние ControlsVisibleExpandedState).
  /// Используется когда фокус переведён на карусель - даём полный доступ к рекомендациям.
  static const visibleExpanded = ControlsVisibilityConfig(
    showTopBar: true,
    showProgressSlider: true,
    showControlButtons: true,
    showCarousel: true,
    carouselMode: CarouselMode.expanded,
    excludeFromFocus: false,
    topBarSlideOffset: 0.0,
    bottomControlsSlideOffset: 0.0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ControlsVisibilityConfig &&
          runtimeType == other.runtimeType &&
          showTopBar == other.showTopBar &&
          showProgressSlider == other.showProgressSlider &&
          showControlButtons == other.showControlButtons &&
          showCarousel == other.showCarousel &&
          carouselMode == other.carouselMode &&
          excludeFromFocus == other.excludeFromFocus &&
          topBarSlideOffset == other.topBarSlideOffset &&
          bottomControlsSlideOffset == other.bottomControlsSlideOffset;

  @override
  int get hashCode =>
      showTopBar.hashCode ^
      showProgressSlider.hashCode ^
      showControlButtons.hashCode ^
      showCarousel.hashCode ^
      carouselMode.hashCode ^
      excludeFromFocus.hashCode ^
      topBarSlideOffset.hashCode ^
      bottomControlsSlideOffset.hashCode;

  @override
  String toString() {
    return 'ControlsVisibilityConfig('
        'showTopBar: $showTopBar, '
        'showProgressSlider: $showProgressSlider, '
        'showControlButtons: $showControlButtons, '
        'showCarousel: $showCarousel, '
        'carouselMode: $carouselMode, '
        'excludeFromFocus: $excludeFromFocus, '
        'topBarSlideOffset: $topBarSlideOffset, '
        'bottomControlsSlideOffset: $bottomControlsSlideOffset)';
  }
}
