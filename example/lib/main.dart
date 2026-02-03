import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    return ScreenUtilInit(
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
      splitScreenMode: true,
      // Use builder only if you need to use library outside ScreenUtilInit context
      builder: (_, child) => MaterialApp(
        title: 'Rhs_player Example',
        home: PlayerScreen(),
        // debugShowCheckedModeBanner: false,
      ),
    );
  }
}
