import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player/rhs_player.dart';

/// Кнопка выбора аудиодорожки
/// Подписывается на события треков от контроллера
class AudioTrackButton extends StatefulWidget {
  final RhsPlayerController controller;
  final VoidCallback? onInteraction;
  final FocusNode? focusNode;

  const AudioTrackButton({
    super.key, 
    required this.controller, 
    this.onInteraction,
    this.focusNode,
  });

  @override
  State<AudioTrackButton> createState() => _AudioTrackButtonState();
}

class _AudioTrackButtonState extends State<AudioTrackButton> {
  List<RhsAudioTrack> _tracks = [];
  String? _selectedTrackId;
  StreamSubscription? _tracksSubscription;
  final GlobalKey<PopupMenuButtonState<String>> _popupMenuKey = GlobalKey<PopupMenuButtonState<String>>();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _loadAudioTracks();
    _setupTracksListener();
  }

  /// Настройка слушателя изменений треков от контроллера
  void _setupTracksListener() {
    // Подписываемся на общий поток изменений треков
    _tracksSubscription = widget.controller.tracksStream.listen((_) {
      _loadAudioTracks();
    });
  }

  /// Загружает список аудиотреков асинхронно
  Future<void> _loadAudioTracks() async {
    if (!mounted) return;

    try {
      final tracks = await widget.controller.getAudioTracks();

      if (!mounted) return;

      setState(() {
        _tracks = tracks;

        // Находим выбранный трек
        final selectedTrack = tracks.where((t) => t.selected).firstOrNull;
        if (selectedTrack != null) {
          _selectedTrackId = selectedTrack.id;
        } else if (_selectedTrackId == null && tracks.isNotEmpty) {
          // Если ничего не выбрано, выбираем первый
          _selectedTrackId = tracks.first.id;
        }
      });
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  void dispose() {
    _tracksSubscription?.cancel();
    super.dispose();
  }

  /// Текст для отображения на кнопке
  String get _buttonText {
    // Используем _selectedTrackId чтобы найти трек и показать его метку
    if (_selectedTrackId != null && _tracks.isNotEmpty) {
      try {
        final track = _tracks.firstWhere((t) => t.id == _selectedTrackId);
        return _getTrackDisplayLabel(track);
      } catch (e) {
        // Если трек не найден, показываем метку первого трека
        return _getTrackDisplayLabel(_tracks.first);
      }
    }
    return 'Audio';
  }

  /// Получает отображаемую метку для аудиодорожки
  String _getTrackDisplayLabel(RhsAudioTrack track) {
    // Приоритет: language > label > id
    if (track.language != null && track.language!.isNotEmpty) {
      return track.language!.toUpperCase();
    }
    if (track.label != null && track.label!.isNotEmpty) {
      return track.label!;
    }
    return 'Track ${track.id}';
  }

  /// Получает полную метку для отображения в меню
  String _getTrackMenuLabel(RhsAudioTrack track) {
    final parts = <String>[];

    if (track.language != null && track.language!.isNotEmpty) {
      parts.add(track.language!.toUpperCase());
    }

    if (track.label != null && track.label!.isNotEmpty && track.label != track.language) {
      parts.add(track.label!);
    }

    if (parts.isEmpty) {
      parts.add('Track ${track.id}');
    }

    return parts.join(' • ');
  }

  /// Обработка выбора аудиодорожки
  Future<void> _onAudioTrackSelected(String trackId) async {
    widget.onInteraction?.call();
    // Обновляем UI немедленно, но только если виджет еще mounted
    if (mounted) {
      setState(() {
        _selectedTrackId = trackId;
      });
    }

    try {
      await widget.controller.selectAudioTrack(trackId);

      // Перезагружаем треки чтобы обновить selected флаг
      await _loadAudioTracks();
    } catch (e) {
      // Ignore errors
    }
  }

  /// Построение строки меню
  Widget _buildMenuRow({required String label, required bool isSelected}) {
    return SizedBox(
      width: 200,
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

  /// Программно открывает меню (для вызова с пульта)
  void showMenu() {
    _popupMenuKey.currentState?.showButtonMenu();
  }

  /// Построение элементов меню
  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    if (_tracks.isEmpty) {
      return [
        const PopupMenuItem<String>(
          enabled: false,
          value: '',
          child: Text('No audio tracks available', style: TextStyle(color: Colors.white70)),
        ),
      ];
    }

    final items = <PopupMenuEntry<String>>[];

    for (final track in _tracks) {
      final isSelected = _selectedTrackId == track.id;

      items.add(
        PopupMenuItem<String>(
          value: track.id,
          onTap: () {
            // Используем onTap вместо onSelected для более надежной обработки
            Future.microtask(() => _onAudioTrackSelected(track.id));
          },
          child: _buildMenuRow(label: _getTrackMenuLabel(track), isSelected: isSelected),
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

    // Тема для выпадающего меню: светлое выделение на тёмном фоне (чтобы фокус был виден)
    final menuTheme = Theme.of(context).copyWith(
      highlightColor: Colors.white.withValues(alpha: 0.25),
      hoverColor: Colors.white.withValues(alpha: 0.2),
      focusColor: Colors.white.withValues(alpha: 0.3),
      splashColor: Colors.white.withValues(alpha: 0.15),
    );

    return Theme(
      data: menuTheme,
      child: Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onInteraction?.call();
          showMenu();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          border: _isFocused ? Border.all(color: Colors.white, width: 2) : null,
          borderRadius: BorderRadius.circular(8),
          color: _isFocused ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
        ),
        padding: const EdgeInsets.all(8),
        child: PopupMenuButton<String>(
          key: _popupMenuKey,
          tooltip: 'Audio Track',
          color: const Color(0xFF1F1F1F),
          surfaceTintColor: Colors.transparent,
          padding: EdgeInsets.zero,
          position: PopupMenuPosition.over,
          onOpened: widget.onInteraction != null ? () => widget.onInteraction!() : null,
          itemBuilder: (context) => _buildMenuItems(context),
          child: Center(
            child: Text(
              _buttonText,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
