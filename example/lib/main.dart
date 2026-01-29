import 'package:flutter/material.dart';
import 'package:rhs_player_example/player_screen.dart';

//to add
// - current selected boxFit
// - seek Overlays

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Rhs_player Example', home: PlayerScreen(), debugShowCheckedModeBanner: false);
  }
}
