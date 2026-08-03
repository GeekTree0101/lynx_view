import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'lynx_view_ios has no standalone Dart API to exercise here.\n'
            'See the lynx_view package\'s example app for a real LynxView demo.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
