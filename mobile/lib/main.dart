import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

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
      theme: AppTheme.build(),
      home: const HomeScreen(),
    );
  }
}
