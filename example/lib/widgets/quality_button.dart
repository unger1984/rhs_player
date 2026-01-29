import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rhs_player/rhs_player.dart';

// ignore: avoid_relative_lib_imports

class QualityButton extends StatefulWidget {
  final RhsPlayerController controller;
  final VoidCallback? onControlsShow;

  const QualityButton({super.key, required this.controller, this.onControlsShow});

  @override
  State<QualityButton> createState() => _QualityButtonState();
}

class _QualityButtonState extends State<QualityButton> {
  List<RhsVideoTrack> _videoTracks = const <RhsVideoTrack>[];
  String? _manualTrackId;
  bool _dataSaver = false;
  Future<void>? _pendingTrackFetch;

  Future<void> _refreshVideoTracks() async {
    if (_pendingTrackFetch != null) return;
    _pendingTrackFetch = widget.controller
        .getVideoTracks()
        .then((tracks) {
          if (!mounted) return;
          setState(() {
            _videoTracks = tracks;
            if (_manualTrackId != null && tracks.every((t) => t.id != _manualTrackId)) {
              _manualTrackId = null;
            }
          });
        })
        .catchError((e) {
          print('[Quality] Error loading tracks: $e');
        })
        .whenComplete(() {
          _pendingTrackFetch = null;
        });
  }

  Future<void> _onQualitySelected(String value) async {
    switch (value) {
      case 'auto':
        setState(() {
          _dataSaver = false;
          _manualTrackId = null;
        });
        await widget.controller.setDataSaver(false);
        await widget.controller.clearVideoTrackSelection();
        break;
      case 'dataSaver':
        setState(() {
          _dataSaver = true;
          _manualTrackId = null;
        });
        await widget.controller.setDataSaver(true);
        await widget.controller.clearVideoTrackSelection();
        break;
      default:
        setState(() {
          _dataSaver = false;
          _manualTrackId = value;
        });
        await widget.controller.setDataSaver(false);
        await widget.controller.selectVideoTrack(value);
        break;
    }
    widget.onControlsShow?.call();
  }

  IconData get _qualityIcon {
    if (_dataSaver) return Icons.data_saver_on;
    if (_manualTrackId != null) return Icons.high_quality;
    return Icons.hd;
  }

  Widget _qualityMenuRow({required String label, bool selected = false}) {
    return Row(
      children: [
        if (selected) const Icon(Icons.check, size: 18, color: Colors.white) else const SizedBox(width: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  List<PopupMenuEntry<String>> _qualityPopupItems(BuildContext context) {
    final items = <PopupMenuEntry<String>>[];
    items.add(
      PopupMenuItem(
        value: 'auto',
        child: _qualityMenuRow(label: 'Auto', selected: !_dataSaver && _manualTrackId == null),
      ),
    );
    items.add(
      PopupMenuItem(
        value: 'dataSaver',
        child: _qualityMenuRow(label: 'Data Saver', selected: _dataSaver),
      ),
    );
    if (_videoTracks.isNotEmpty) {
      final sorted = [..._videoTracks]..sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));
      items.add(const PopupMenuDivider());
      for (final track in sorted) {
        items.add(
          PopupMenuItem(
            value: track.id,
            child: _qualityMenuRow(label: track.displayLabel, selected: _manualTrackId == track.id),
          ),
        );
      }
    } else if (_pendingTrackFetch != null) {
      items.add(
        const PopupMenuItem<String>(
          enabled: false,
          value: '__loading__',
          child: Text('Loading variants...', style: TextStyle(color: Colors.white70)),
        ),
      );
    } else {
      items.add(
        const PopupMenuItem<String>(
          enabled: false,
          value: '__empty__',
          child: Text('No variants reported', style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Quality',
      color: const Color(0xFF1F1F1F),
      surfaceTintColor: Colors.transparent,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.over,
      onOpened: () => _refreshVideoTracks(),
      onSelected: (v) => unawaited(_onQualitySelected(v)),
      itemBuilder: (context) => _qualityPopupItems(context),
      child: IconButton(icon: Icon(_qualityIcon, color: Colors.white, size: 32), onPressed: null),
    );
  }
}
