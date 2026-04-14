import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
import 'client_form_screen.dart';
import 'sz_test_screen.dart';

class VoiceAssessmentTestsScreen extends StatelessWidget {
  const VoiceAssessmentTestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            const AppTopHeader.withBack(title: 'Ses Değerlendirme Testleri'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: [
                  _AssessmentModuleCard(
                    icon: Icons.assignment_outlined,
                    title: 'Danışan Bilgi Formu',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ClientFormScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _AssessmentModuleCard(
                    icon: Icons.mic_none_rounded,
                    title: 'S/Z Oranı Testi',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SzTestScreen(),
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

class _AssessmentModuleCard extends StatelessWidget {
  static const Color _tileBackground = Color(0xFFF5FAF4);
  static const Color _tileBorder = Color(0xFFD5E2D1);
  static const Color _iconBackground = Color(0xFFE6F0E6);
  static const Color _chevronColor = Color(0xFF8DA292);

  const _AssessmentModuleCard({
    required this.icon,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _tileBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _tileBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _tileBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.homeAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _chevronColor,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
