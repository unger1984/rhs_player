import 'package:flutter/material.dart';
import 'package:rhs_player_example/features/player/model/player_state.dart';
import 'package:rhs_player_example/features/player/ui/player_view.dart';
import 'package:rhs_player_example/shared/api/media_repository.dart';

/// Страница плеера.
/// Композиция UI с делегированием логики в PlayerState.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlayerState _playerState;

  /// Обработчик Back от VideoControls (скрыть контролы или разрешить pop).
  bool Function()? _backHandler;

  /// Запрошен выход с экрана (UI кнопка «Назад» или аппаратный Back при скрытых контролах).
  bool _requestedPop = false;

  @override
  void initState() {
    super.initState();
    _playerState = PlayerState(MediaRepository());
    _playerState.onStateChanged = () {
      if (mounted) setState(() {});
    };
    _playerState.initialize();
  }

  @override
  void dispose() {
    _playerState.dispose();
    super.dispose();
  }

  void _requestPop() {
    setState(() => _requestedPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _requestedPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Сначала даём VideoControls скрыть контролы; если не скрыли — запрашиваем выход
        if (_backHandler?.call() == true) return;
        _requestPop();
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
              registerBackHandler: (handler) => _backHandler = handler,
              onBackButtonPressed: _requestPop,
            ),
          ),
        ),
      ),
    );
  }
}
