import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
import 'auth_screen.dart';
import 'breath_control_screen.dart';
import 'vocal_hygiene_onboarding_screen.dart';
import 'vocal_function_exercises_screen.dart';
import 'voice_assessment_tests_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _showLoginRequiredDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AuthScreen(),
                  ),
                );
              },
              child: const Text('Giriş Yap'),
            ),
          ],
        );
      },
    );
  }

  void _openAssessmentTests(BuildContext context, AppUser? currentUser) {
    if (currentUser == null) {
      _showLoginRequiredDialog(
        context,
        title: 'Testler için giriş gerekli',
        message:
            'Danışan formu ve S/Z testi sonuçlarınızı kaydetmek için önce giriş yapın veya kayıt olun.',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const VoiceAssessmentTestsScreen(),
      ),
    );
  }

  void _openVocalHygiene(BuildContext context, AppUser? currentUser) {
    if (currentUser == null) {
      _showLoginRequiredDialog(
        context,
        title: 'Kişiselleştirme için giriş gerekli',
        message:
            'Vokal hijyen cevaplarının hesabına kaydedilmesi ve sana özel sıralama için önce giriş yapın veya kayıt olun.',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const VocalHygieneOnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    final headerTitle = currentUser == null
        ? 'Hoş geldiniz'
        : 'Hoş geldiniz, ${currentUser.firstName}';

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            AppTopHeader.home(
              title: headerTitle,
              subtitle: 'Terapistinizin önerdiği egzersiz kategorisini seçin.',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  _CategoryTile(
                    icon: Icons.water_drop_outlined,
                    title: 'Vokal Hijyen',
                    onTap: () {
                      _openVocalHygiene(context, currentUser);
                    },
                  ),
                  const SizedBox(height: 12),
                  _CategoryTile(
                    icon: Icons.air,
                    title: 'Nefes Kontrolü',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BreathControlScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _CategoryTile(
                    icon: Icons.record_voice_over,
                    title: 'Vokal Fonksiyon Egzersizleri',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const VocalFunctionExercisesScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _CategoryTile(
                    icon: Icons.assignment_outlined,
                    title: 'Ses Değerlendirme Testleri',
                    isHighlighted: true,
                    showChevron: true,
                    onTap: () {
                      _openAssessmentTests(context, currentUser);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.title,
    this.isHighlighted = false,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool isHighlighted;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isHighlighted ? const Color(0xFFC6E0E6) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.cardBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.darkBlue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (showChevron)
                const Icon(Icons.chevron_right, color: AppTheme.darkBlue),
            ],
          ),
        ),
      ),
    );
  }
}
