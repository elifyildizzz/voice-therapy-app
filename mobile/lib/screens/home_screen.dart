import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
import 'breath_control_screen.dart';
import 'vocal_hygiene_screen.dart';
import 'vocal_function_exercises_screen.dart';
import 'voice_analyze_consent_screen.dart';
import 'warmup_relax_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            const AppTopHeader.home(
              title: 'Hoşgeldiniz, İlayda',
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
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const VocalHygieneScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _CategoryTile(
                    icon: Icons.accessibility_new_outlined,
                    title: 'Isınma - Gevşeme',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WarmupRelaxScreen(),
                        ),
                      );
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
                    icon: Icons.medical_services_outlined,
                    title: 'Ses Sağlığı Ön Tarama Testi',
                    isHighlighted: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const VoiceAnalyzeConsentScreen(),
                        ),
                      );
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
    required this.onTap,
    this.isHighlighted = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isHighlighted;

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
              const Icon(Icons.chevron_right, color: AppTheme.darkBlue),
            ],
          ),
        ),
      ),
    );
  }
}
