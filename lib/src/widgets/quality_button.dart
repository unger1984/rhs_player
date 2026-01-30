import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

/// Кнопка выбора качества видео
/// Подписывается на события треков от контроллера
class QualityButton extends StatefulWidget {
  final RhsPlayerController controller;

  const QualityButton({super.key, required this.controller});

  @override
  State<QualityButton> createState() => _QualityButtonState();
}

class _QualityButtonState extends State<QualityButton> {
  List<RhsVideoTrack> _tracks = [];
  String? _selectedTrackId;

  @override
  void initState() {
    super.initState();
    _setupTracksListener();
  }

  /// Настройка слушателя треков от контроллера
  void _setupTracksListener() {
    final videoTracks = widget.controller.videoTracks;
    if (videoTracks != null) {
      // Подписываемся на изменения треков
      videoTracks.addListener(_onTracksChanged);
      // Инициализируем текущее значение
      _onTracksChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.videoTracks?.removeListener(_onTracksChanged);
    super.dispose();
  }

  /// Обработка изменения треков от нативного плеера
  void _onTracksChanged() {
    if (!mounted) return;

    final videoTracks = widget.controller.videoTracks;
    if (videoTracks == null) return;

    // Получаем свежий список треков от ExoPlayer
    final tracks = videoTracks.value;

    setState(() {
      _tracks = tracks;

      // Восстанавливаем выбранный трек из контроллера (если виджет пересоздавался)
      if (_selectedTrackId == null) {
        final savedTrackId = widget.controller.selectedVideoTrackId;
        if (savedTrackId != null) {
          // Восстанавливаем ранее выбранный трек
          _selectedTrackId = savedTrackId;
        } else if (tracks.isNotEmpty) {
          // Если еще никогда не выбирали - выбираем первый (обычно это максимальное качество)
          _selectedTrackId = tracks.first.id;
        }
      }
    });
  }

  /// Текст для отображения на кнопке
  String get _buttonText {
    // Используем _selectedTrackId чтобы найти трек и показать его качество
    if (_selectedTrackId != null && _tracks.isNotEmpty) {
      try {
        final track = _tracks.firstWhere((t) => t.id == _selectedTrackId);
        return track.qualityLabel;
      } catch (e) {
        // Если трек не найден, показываем качество первого трека
        return _tracks.first.qualityLabel;
      }
    }
    return 'HD';
  }

  /// Обработка выбора качества
  Future<void> _onQualitySelected(String trackId) async {
    // Обновляем UI немедленно, но только если виджет еще mounted
    if (mounted) {
      setState(() {
        _selectedTrackId = trackId;
      });
    }

    try {
      await widget.controller.selectVideoTrack(trackId);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Построение строки меню
  Widget _buildMenuRow({required String label, required bool isSelected}) {
    return SizedBox(
      width: 120,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : const SizedBox(),
          ),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  /// Построение элементов меню
  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    if (_tracks.isEmpty) {
      return [
        const PopupMenuItem<String>(
          enabled: false,
          value: '',
          child: Text('No quality options available', style: TextStyle(color: Colors.white70)),
        ),
      ];
    }

    // Сортируем треки по битрейту (от большего к меньшему)
    final sortedTracks = List<RhsVideoTrack>.from(_tracks)..sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));

    final items = <PopupMenuEntry<String>>[];

    for (final track in sortedTracks) {
      final isSelected = _selectedTrackId == track.id;

      items.add(
        PopupMenuItem<String>(
          value: track.id,
          onTap: () {
            // Используем onTap вместо onSelected для более надежной обработки
            Future.microtask(() => _onQualitySelected(track.id));
          },
          child: _buildMenuRow(label: track.qualityLabel, isSelected: isSelected),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    // Не показываем кнопку пока не загружены треки и не определен выбранный трек
    if (_tracks.isEmpty || _selectedTrackId == null) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: 'Video Quality',
      color: const Color(0xFF1F1F1F),
      surfaceTintColor: Colors.transparent,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.over,
      itemBuilder: (context) => _buildMenuItems(context),
      child: Center(
        child: Text(
          _buttonText,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
