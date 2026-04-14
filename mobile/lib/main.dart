import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/app_shell_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const VoiceTherapyApp());
}

class VoiceTherapyApp extends StatelessWidget {
  const VoiceTherapyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFDCE7D4),
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Voice Therapy App',
        theme: AppTheme.build(),
        home: const AppShellScreen(),
      ),
    );
  }
}
