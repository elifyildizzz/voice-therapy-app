import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../models/vocal_hygiene_personalization.dart';
import '../services/auth_service.dart';
import '../services/vocal_hygiene_repository.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'breath_control_screen.dart';
import 'vocal_function_exercises_screen.dart';
import 'vocal_hygiene_onboarding_screen.dart';
import 'vocal_hygiene_screen.dart';
import 'voice_assessment_tests_screen.dart';

const Color _homeAccentGreen = Color(0xFF4D6B57);

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
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.homeIconBackground,
                foregroundColor: AppTheme.homeAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
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

  Future<void> _openVocalHygiene(
      BuildContext context, AppUser? currentUser) async {
    if (currentUser == null) {
      _showLoginRequiredDialog(
        context,
        title: 'Kişiselleştirme için giriş gerekli',
        message:
            'Vokal hijyen cevaplarının hesabına kaydedilmesi ve size özel sıralama için önce giriş yapın veya kayıt olun.',
      );
      return;
    }

    final latestResponse =
        await VocalHygieneRepository.instance.fetchLatestResponse();
    if (!context.mounted) {
      return;
    }

    final route = latestResponse == null
        ? MaterialPageRoute<void>(
            builder: (_) => const VocalHygieneOnboardingScreen(),
          )
        : MaterialPageRoute<void>(
            builder: (_) => VocalHygieneScreen(
              personalizationResult:
                  VocalHygienePersonalizer.evaluate(latestResponse),
            ),
          );

    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    final headerTitle = currentUser == null
        ? 'Hoş geldiniz'
        : 'Hoş geldiniz, ${currentUser.firstName}';
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFDCE7D4),
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _WelcomeCard(
              title: headerTitle,
              topInset: topInset,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Egzersiz Kategorileri',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
                    child: Column(
                      children: [
                        _CategoryTile(
                          icon: Icons.spa_outlined,
                          title: 'Vokal Hijyen',
                          subtitle: 'Günlük ses sağlığı alışkanlıkları',
                          onTap: () => _openVocalHygiene(context, currentUser),
                        ),
                        const SizedBox(height: 12),
                        _CategoryTile(
                          icon: Icons.air_rounded,
                          title: 'Nefes Kontrolü',
                          subtitle: 'Diyafram ve nefes egzersizleri',
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
                          icon: Icons.music_note_rounded,
                          title: 'Vokal Fonksiyon',
                          subtitle: 'Ses üretimi ve teknik çalışma',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const VocalFunctionExercisesScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _CategoryTile(
                          icon: Icons.bar_chart_rounded,
                          title: 'Ses Değerlendirme',
                          subtitle: 'Ses analizi ve ilerleme takibi',
                          onTap: () =>
                              _openAssessmentTests(context, currentUser),
                        ),
                      ],
                    ),
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

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.title,
    required this.topInset,
  });

  final String title;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final cardHeight = MediaQuery.of(context).size.height * 0.25 + topInset;

    return Container(
      width: double.infinity,
      height: cardHeight,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 28),
      decoration: const BoxDecoration(
        color: Color(0xFFDCE7D4),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x120F1B16),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -4,
            bottom: -30,
            child: IgnorePointer(
              child: Image.asset(
                'assets/branding/plant.png',
                width: 120,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 235),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _homeAccentGreen,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 235),
                child: const Text(
                  'Terapi önerilerine göre bugün kendine iyi bak.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  static const Color _iconBorder = Color(0xFFD4E0D4);
  static const Color _iconForeground = _homeAccentGreen;
  static const Color _chevronColor = Color(0xFFA8B7A2);

  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F1B16),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.homeIconBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _iconBorder),
                ),
                child: Icon(icon, color: _iconForeground, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: _chevronColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
