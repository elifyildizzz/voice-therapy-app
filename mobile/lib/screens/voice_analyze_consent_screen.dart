import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'voice_analyze_screen.dart';

class VoiceAnalyzeConsentScreen extends StatelessWidget {
  const VoiceAnalyzeConsentScreen({super.key});

  static const Color _lightOrange = Color(0xFFFECEAB);
  static const Color _darkOrange = Color(0xFFE7580A);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, topInset + 6, 16, 12),
              decoration: const BoxDecoration(
                color: AppTheme.darkBlue,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ses Sağlığı Ön Tarama Testi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NoticeCard(
                      icon: Icons.error_outline_rounded,
                      title: 'Önemli Bilgilendirme',
                      content:
                          'Bu uygulama yalnızca ses sağlığına yönelik ön değerlendirme sağlar ve tıbbi tanı yerine geçmez.\n\nSesinizde olağandışı bir durum fark ederseniz, bir Kulak Burun Boğaz uzmanına başvurmanız önerilir.',
                    ),
                    const SizedBox(height: 12),
                    _NoticeCard(
                      icon: Icons.verified_user_outlined,
                      title: 'Gizlilik ve Güvenlik',
                      content:
                          'Ses verileriniz KVKK kapsamında hiçbir şekilde saklanmamaktadır.',
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const VoiceAnalyzeScreen(),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.darkBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Anladım, Devam Et',
                          style: TextStyle(fontSize: 15.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VoiceAnalyzeConsentScreen._lightOrange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: VoiceAnalyzeConsentScreen._darkOrange, size: 28),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1E1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.38,
              color: Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }
}
