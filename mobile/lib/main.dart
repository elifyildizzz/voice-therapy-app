import 'package:flutter/material.dart';

import 'screens/voice_analyze_screen.dart';

void main() {
  runApp(const VoiceTherapyApp());
}

class VoiceTherapyApp extends StatelessWidget {
  const VoiceTherapyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Therapy App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const VoiceAnalyzeScreen(),
    );
  }
}
