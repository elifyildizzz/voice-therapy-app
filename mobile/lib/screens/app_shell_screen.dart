import 'package:flutter/material.dart';

import '../widgets/app_bottom_navigation_bar.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'voice_analyze_consent_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _selectedIndex = 1;

  static const List<Widget> _tabs = [
    VoiceAnalyzeConsentScreen(),
    HomeScreen(),
    ProfileScreen(),
  ];

  void _onTabSelected(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
