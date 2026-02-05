import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rhs_player_example/pages/player/player_page.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  void _openPlayer() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PlayerPage()));
  }

  void _closeApp() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Тест плеера')),
      body: Center(
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: _openPlayer,
                child: const Text('Запустить плеер'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _closeApp,
                child: const Text('Закрыть приложение'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
