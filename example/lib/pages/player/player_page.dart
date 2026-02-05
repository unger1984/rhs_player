import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rhs_player_example/features/player/model/player_state.dart';
import 'package:rhs_player_example/features/player/ui/player_view.dart';
import 'package:rhs_player_example/shared/api/media_repository.dart';
import 'package:rhs_player_example/shared/ui/theme/app_durations.dart';

/// Страница плеера.
/// Композиция UI с делегированием логики в PlayerState.
class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    this.exitConfirmDuration = AppDurations.exitConfirmOverlay,
  });

  /// Время показа подсказки «Для выхода нажмите Назад ещё раз» при скрытых контролах.
  final Duration exitConfirmDuration;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlayerState _playerState;

  /// Обработчик Back от VideoControls (скрыть контролы / свернуть карусель или разрешить pop).
  bool Function()? _backHandler;

  /// Запрошен выход с экрана (UI кнопка «Назад» или второй Back при скрытых контролах).
  bool _requestedPop = false;

  /// Показана подсказка «Назад ещё раз»; повторное нажатие Back в этот момент выходит.
  bool _exitConfirmVisible = false;

  Timer? _exitConfirmTimer;

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
    _exitConfirmTimer?.cancel();
    _playerState.dispose();
    super.dispose();
  }

  void _requestPop() {
    if (_requestedPop) return;

    setState(() => _requestedPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _onBackInvoked() {
    if (_backHandler?.call() == true) return;

    if (_exitConfirmVisible) {
      _exitConfirmTimer?.cancel();
      _exitConfirmTimer = null;
      _requestPop();
      return;
    }

    setState(() => _exitConfirmVisible = true);
    _exitConfirmTimer = Timer(widget.exitConfirmDuration, () {
      if (mounted) {
        setState(() {
          _exitConfirmVisible = false;
          _exitConfirmTimer = null;
        });
      } else {
        _exitConfirmTimer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _requestedPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBackInvoked();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
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
            if (_exitConfirmVisible) _buildExitConfirmOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildExitConfirmOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 80.h,
      child: Center(
        child: Material(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 24.h),
            child: Text(
              'Для выхода нажмите Назад ещё раз',
              style: TextStyle(color: Colors.white, fontSize: 28.sp),
            ),
          ),
        ),
      ),
    );
  }
}
