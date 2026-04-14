import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'voice_analyze_consent_screen.dart';
import 'auth_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _selectedIndex = 1;
  late final Future<void> _authInitFuture;

  static const List<Widget> _authenticatedTabs = [
    VoiceAnalyzeConsentScreen(),
    HomeScreen(),
    ProfileScreen(),
  ];

  static const List<Widget> _guestTabs = [
    VoiceAnalyzeConsentScreen(),
    HomeScreen(),
  ];

  List<Widget> get _tabs {
    final isAuthenticated = AuthService.instance.currentUser != null;
    return isAuthenticated ? _authenticatedTabs : _guestTabs;
  }

  @override
  void initState() {
    super.initState();
    _authInitFuture = AuthService.instance.initialize();
  }

  Future<void> _showLoginRequiredSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bu bölüm için giriş gerekli',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Test sonuçlarınızı kişiselleştirilmiş olarak kaydetmek ve geçmişinizi görebilmek için önce giriş yapın veya kayıt olun.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF5F6E84),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(this.context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AuthScreen(),
                    ),
                  );
                },
                child: const Text('Giriş Yap veya Kayıt Ol'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Şimdilik Vazgeç'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onTabSelected(int index) {
    final isAuthenticated = AuthService.instance.currentUser != null;
    final isProtectedAnalyzeTab = !isAuthenticated && index == 0;

    if (isProtectedAnalyzeTab) {
      _showLoginRequiredSheet();
      return;
    }

    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _authInitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return ValueListenableBuilder(
          valueListenable: AuthService.instance.currentUserNotifier,
          builder: (context, _, __) {
            final currentTabs = _tabs;
            final safeIndex = _selectedIndex >= currentTabs.length
                ? currentTabs.length - 1
                : _selectedIndex;

            return Scaffold(
              body: AnnotatedRegion<SystemUiOverlayStyle>(
                value: const SystemUiOverlayStyle(
                  statusBarColor: Color(0xFFDCE7D4),
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                  systemNavigationBarColor: AppTheme.card,
                  systemNavigationBarDividerColor: Colors.transparent,
                ),
                child: IndexedStack(
                  index: safeIndex,
                  children: currentTabs,
                ),
              ),
              bottomNavigationBar: AppBottomNavigationBar(
                currentIndex: safeIndex,
                onTap: _onTabSelected,
              ),
            );
          },
        );
      },
    );
  }
}
