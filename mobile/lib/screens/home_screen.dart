import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
import 'auth_screen.dart';
import 'breath_control_screen.dart';
import 'vocal_function_exercises_screen.dart';
import 'vocal_hygiene_onboarding_screen.dart';
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
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: AppTheme.card,
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
            'Vokal hijyen cevaplarının hesabına kaydedilmesi ve size özel sıralama için önce giriş yapın veya kayıt olun.',
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
        : 'Hoş geldiniz,\n${currentUser.firstName}';

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
              subtitle:
                  'Terapistinizin önerdiği egzersiz kategorisini seçin ve günlük akışınızı sürdürün.',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  const _DailyFocusCard(),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tileWidth = (constraints.maxWidth - 14) / 2;

                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          _CategoryTile(
                            width: tileWidth,
                            icon: Icons.spa_outlined,
                            title: 'Vokal Hijyen',
                            backgroundColor: AppTheme.soft,
                            iconColor: AppTheme.primary,
                            onTap: () =>
                                _openVocalHygiene(context, currentUser),
                          ),
                          _CategoryTile(
                            width: tileWidth,
                            icon: Icons.air_rounded,
                            title: 'Nefes\nKontrolü',
                            backgroundColor: const Color(0xFFF7EEE8),
                            iconColor: AppTheme.terracotta,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const BreathControlScreen(),
                                ),
                              );
                            },
                          ),
                          _CategoryTile(
                            width: tileWidth,
                            icon: Icons.music_note_rounded,
                            title: 'Vokal\nFonksiyon',
                            backgroundColor: const Color(0xFFF9F2DF),
                            iconColor: const Color(0xFFB98A2E),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const VocalFunctionExercisesScreen(),
                                ),
                              );
                            },
                          ),
                          _CategoryTile(
                            width: tileWidth,
                            icon: Icons.bar_chart_rounded,
                            title: 'Ses\nDeğerlendirme',
                            backgroundColor: const Color(0xFFF3ECE6),
                            iconColor: AppTheme.light,
                            onTap: () =>
                                _openAssessmentTests(context, currentUser),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const _SupportCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyFocusCard extends StatelessWidget {
  const _DailyFocusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Günlük Akış',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppTheme.textMuted,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '4 Kategori',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    height: 1,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Hijyen, nefes, fonksiyon ve değerlendirme akışı tek ekranda hazır.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.soft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              color: AppTheme.primary,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          width: width,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(26),
            border:
                Border.all(color: AppTheme.cardBorder.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(height: 38),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: AppTheme.terracotta,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gün içinde dilediğiniz modülden devam ederek kişisel ses rutininizi sürdürebilirsiniz.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
