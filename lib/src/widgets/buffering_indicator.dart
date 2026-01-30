import 'package:flutter/material.dart';

class BufferingIndicator extends StatelessWidget {
  const BufferingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Buffering',
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
