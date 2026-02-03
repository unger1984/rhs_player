import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player/rhs_player.dart';
import 'package:rhs_player_example/controls/rows/recommended_carousel_row.dart';
import 'package:rhs_player_example/video_controls.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlayerScreenContent();
  }
}

class _PlayerScreenContent extends StatefulWidget {
  const _PlayerScreenContent();

  @override
  State<_PlayerScreenContent> createState() => _PlayerScreenContentState();
}

class _PlayerScreenContentState extends State<_PlayerScreenContent> {
  List<RecommendedCarouselItem> _carouselItems = [];
  String? _currentPlayingUrl;
  late RhsPlayerController controller;

  static Widget _placeholderImage() => Container(
    color: const Color(0xFF2A303C),
    child: Center(
      child: Icon(Icons.movie, color: Colors.white54, size: 48.r),
    ),
  );

  /// Имитация API: перечитываем список из JSON.
  static Future<List<RecommendedCarouselItem>> _loadFilmsFromJson() async {
    final json = await rootBundle.loadString('films.json');
    final list = jsonDecode(json) as List<dynamic>;
    final items = <RecommendedCarouselItem>[];
    for (final e in list) {
      final map = e as Map<String, dynamic>;
      final link = map['link'] as String? ?? '';
      final drmUrl = map['drm'] as String?;
      final title = map['title'] as String? ?? '';
      final source = RhsMediaSource(
        link,
        drm: drmUrl != null && drmUrl.isNotEmpty
            ? RhsDrmConfig(type: RhsDrmType.widevine, licenseUrl: drmUrl)
            : const RhsDrmConfig(type: RhsDrmType.none),
      );
      items.add(
        RecommendedCarouselItem(
          title: title,
          image: _placeholderImage(),
          mediaSource: source,
        ),
      );
    }
    return items;
  }

  static List<RecommendedCarouselItem> _filterExcludingPlaying(
    List<RecommendedCarouselItem> items,
    String? currentPlayingUrl,
  ) {
    if (currentPlayingUrl == null) return items;
    return items.where((e) => e.mediaSource?.url != currentPlayingUrl).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadFilms();
    final placeholderSource = RhsMediaSource(
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    );
    controller = RhsPlayerController.single(placeholderSource);

    controller.addStatusListener((status) {
      if (status is RhsPlayerStatusError) {
        developer.log('EVENT PLAYER ERROR: ${status.message}');
      } else {
        developer.log('EVENT PLAYER STATUS: $status');
      }
    });

    controller.addPositionDataListener((data) {
      developer.log('EVENT POSITION DATA: ${data.position} / ${data.duration}');
    });

    controller.addBufferedPositionListener((position) {
      developer.log('EVENT BUFFERED: $position');
    });

    controller.addVideoTracksListener((tracks) {
      final trackLabels = tracks.map((t) => t.displayLabel).join(', ');
      developer.log('EVENT VIDEO TRACKS: [$trackLabels]');
    });

    controller.addAudioTracksListener((tracks) {
      final trackLabels = tracks.map((t) => t.label).join(', ');
      developer.log('EVENT AUDIO TRACKS: [$trackLabels]');
    });
  }

  Future<void> _loadFilms() async {
    try {
      final items = await _loadFilmsFromJson();
      if (items.isEmpty || !mounted) return;
      final firstSource = items.first.mediaSource!;
      setState(() {
        _currentPlayingUrl = firstSource.url;
        _carouselItems = _filterExcludingPlaying(items, firstSource.url);
      });
      controller.loadMediaSource(firstSource);
    } catch (e, st) {
      debugPrint('_loadFilms error: $e $st');
    }
  }

  /// Обновить карусель: перечитать список из JSON (имитация API) и отфильтровать текущее.
  Future<void> _refreshCarousel() async {
    try {
      final items = await _loadFilmsFromJson();
      if (!mounted) return;
      setState(
        () =>
            _carouselItems = _filterExcludingPlaying(items, _currentPlayingUrl),
      );
    } catch (e, st) {
      debugPrint('_refreshCarousel error: $e $st');
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onRecommendedItemActivated(RecommendedCarouselItem item) {
    final source = item.mediaSource;
    if (source == null) return;
    controller.loadMediaSource(source);
    setState(() => _currentPlayingUrl = source.url);
    _refreshCarousel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: RhsPlayerView(
            controller: controller,
            boxFit: BoxFit.contain,
            overlay: VideoControls(
              controller: controller,
              onSwitchSource: () {},
              recommendedItems: _carouselItems,
              initialRecommendedIndex: 0,
              onRecommendedItemActivated: _onRecommendedItemActivated,
            ),
          ),
        ),
      ),
    );
  }
}
