import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player_example/controls/core/control_row.dart';
import 'package:rhs_player_example/controls/core/focusable_item.dart';
import 'package:rhs_player_example/controls/core/key_handling_result.dart';
import 'package:rhs_player_example/controls/items/custom_widget_item.dart';

/// Элемент карусели «Рекомендуем посмотреть» (превью фильма).
class RecommendedCarouselItem {
  final String title;
  final Widget image;

  const RecommendedCarouselItem({required this.title, required this.image});
}

/// Виджет карусели: фокус всегда на крайнем левом слайде.
/// Стрелка вправо — текущий слайд уезжает влево, фокус на новом левом слайде.
/// Стрелка влево — прокрутка вправо (предыдущий слайд).
class _RecommendedCarouselWidget extends StatefulWidget {
  final FocusNode focusNode;
  final List<RecommendedCarouselItem> items;
  final void Function(int index)? onItemSelected;
  final int initialScrollIndex;

  const _RecommendedCarouselWidget({
    required this.focusNode,
    required this.items,
    this.onItemSelected,
    this.initialScrollIndex = 0,
  });

  @override
  State<_RecommendedCarouselWidget> createState() =>
      _RecommendedCarouselWidgetState();
}

class _RecommendedCarouselWidgetState
    extends State<_RecommendedCarouselWidget> {
  late ScrollController _scrollController;
  late int _scrollIndex;

  double _cardWidth = 388;
  double _cardHeight = 220;
  double _gap = 40;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final maxIndex = widget.items.isEmpty ? 0 : widget.items.length - 1;
    _scrollIndex = widget.initialScrollIndex.clamp(0, maxIndex);
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus) {
      widget.onItemSelected?.call(_scrollIndex);
    }
  }

  bool _savedIndexScrolled = false;

  void _scrollToSavedIndexOnce() {
    if (_savedIndexScrolled || !_scrollController.hasClients) return;
    _savedIndexScrolled = true;
    final offset = _offsetForIndex(_scrollIndex);
    final position = _scrollController.position;
    _scrollController.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем только при изменении (AGENTS.md: designSize 1920×1080, .w/.h/.r/.sp).
    final w = 388.w;
    final h = 220.w;
    final g = 40.w;
    if (_cardWidth != w || _cardHeight != h || _gap != g) {
      _cardWidth = w;
      _cardHeight = h;
      _gap = g;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToSavedIndexOnce(),
    );
  }

  /// Смещение прокрутки: активный слайд всегда начинается в 120.w от левого края.
  double _offsetForIndex(int index) {
    return index * (_cardWidth + _gap);
  }

  void _scrollToIndex(int index) {
    if (index < 0 || index >= widget.items.length) return;
    if (!_scrollController.hasClients) return;
    setState(() => _scrollIndex = index);
    final rawOffset = _offsetForIndex(index);
    final position = _scrollController.position;
    final clampedOffset = rawOffset.clamp(0.0, position.maxScrollExtent);
    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowRight:
            if (_scrollIndex < widget.items.length - 1) {
              _scrollToIndex(_scrollIndex + 1);
            }
            return KeyEventResult.handled;
          case LogicalKeyboardKey.arrowLeft:
            if (_scrollIndex > 0) {
              _scrollToIndex(_scrollIndex - 1);
            }
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: Container(
        height: _cardHeight + 48.h,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 120.w, bottom: 12.h),
              child: Text(
                'Рекомендуем посмотреть',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.focusNode,
                builder: (context, _) {
                  final hasFocus = widget.focusNode.hasFocus;
                  return ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(left: 120.w),
                    itemCount: widget.items.length,
                    itemExtent: _cardWidth + _gap,
                    physics: const ClampingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final carouselItem = widget.items[index];
                      final isFirstVisible = index == _scrollIndex;
                      return Padding(
                        padding: EdgeInsets.only(right: _gap),
                        child: _CarouselCard(
                          title: carouselItem.title,
                          image: carouselItem.image,
                          width: _cardWidth,
                          height: _cardHeight,
                          showFocusBorder: isFirstVisible && hasFocus,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка слайда с рамкой фокуса.
class _CarouselCard extends StatelessWidget {
  final String title;
  final Widget image;
  final double width;
  final double height;
  final bool showFocusBorder;

  const _CarouselCard({
    required this.title,
    required this.image,
    required this.width,
    required this.height,
    required this.showFocusBorder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: showFocusBorder
            ? Border.all(color: const Color(0xFFB3E5FC), width: 3.w)
            : null,
        boxShadow: showFocusBorder
            ? [
                BoxShadow(
                  color: const Color(0xFFB3E5FC).withValues(alpha: 0.5),
                  blurRadius: 12.r,
                  spreadRadius: 2.r,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: image),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                color: const Color(0xFF201B2E),
                child: Text(
                  title,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Контент ряда с анимацией высоты при появлении фокуса.
class _AnimatedRecommendedRowContent extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;

  const _AnimatedRecommendedRowContent({
    required this.focusNode,
    required this.child,
  });

  @override
  State<_AnimatedRecommendedRowContent> createState() =>
      _AnimatedRecommendedRowContentState();
}

class _AnimatedRecommendedRowContentState
    extends State<_AnimatedRecommendedRowContent> {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _hasFocus = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant _AnimatedRecommendedRowContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      _hasFocus = widget.focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted && _hasFocus != widget.focusNode.hasFocus) {
      setState(() => _hasFocus = widget.focusNode.hasFocus);
    }
  }

  /// Высота «подглядывающей» полоски, когда фокус не на карусели.
  static double _peekHeight(BuildContext context) => 96.h;

  static const double _expandedHeight = 320;

  /// Отступ снизу в режиме фокуса, чтобы слайды не прижимались к низу экрана.
  static double _bottomPadding(BuildContext context) => 40.h;

  @override
  Widget build(BuildContext context) {
    final expandedHeight = _expandedHeight.h;
    final visibleHeight = _hasFocus ? expandedHeight : _peekHeight(context);
    final contentChild = _hasFocus
        ? Padding(
            padding: EdgeInsets.only(bottom: _bottomPadding(context)),
            child: widget.child,
          )
        : widget.child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: visibleHeight,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: expandedHeight,
            child: SizedBox(height: expandedHeight, child: contentChild),
          ),
        ),
      ),
    );
  }
}

/// Ряд «Рекомендуем посмотреть» с каруселью превью.
/// При переходе фокуса вниз ряд выезжает снизу, сдвигая кнопки и прогресс выше.
/// Фокус всегда на крайнем левом слайде; стрелка вправо — слайд уезжает влево, фокус на новом слайде.
class RecommendedCarouselRow extends BaseControlRow {
  final List<RecommendedCarouselItem> carouselItems;
  final void Function(int index)? onItemSelected;
  final int initialScrollIndex;

  RecommendedCarouselRow({
    required super.id,
    required super.index,
    required this.carouselItems,
    this.onItemSelected,
    this.initialScrollIndex = 0,
  }) : super(
         items: [
           _createCarouselItem(
             id,
             carouselItems,
             onItemSelected,
             initialScrollIndex,
           ),
         ],
       );

  static FocusableItem _createCarouselItem(
    String rowId,
    List<RecommendedCarouselItem> carouselItems,
    void Function(int index)? onItemSelected,
    int initialScrollIndex,
  ) {
    return CustomWidgetItem(
      id: '${rowId}_carousel',
      keyHandler: (event) {
        if (event is KeyDownEvent) {
          switch (event.logicalKey) {
            case LogicalKeyboardKey.arrowRight:
            case LogicalKeyboardKey.arrowLeft:
              return KeyHandlingResult.handled;
            default:
              return KeyHandlingResult.notHandled;
          }
        }
        return KeyHandlingResult.notHandled;
      },
      builder: (focusNode) => _AnimatedRecommendedRowContent(
        focusNode: focusNode,
        child: _RecommendedCarouselWidget(
          focusNode: focusNode,
          items: carouselItems,
          onItemSelected: onItemSelected,
          initialScrollIndex: initialScrollIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return items.first.build(context);
  }
}
