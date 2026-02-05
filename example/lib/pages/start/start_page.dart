import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rhs_player_example/pages/player/player_page.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  bool _loading = false;

  Future<void> _openPlayer() async {
    if (_loading) return;
    setState(() => _loading = true);
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const PlayerPage()));
    if (mounted) setState(() => _loading = false);
  }

  void _closeApp() {
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Тест плеера')),
          body: Center(
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _loading ? null : _openPlayer,
                    child: const Text('Запустить плеер'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loading ? null : _closeApp,
                    child: const Text('Закрыть приложение'),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_loading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
