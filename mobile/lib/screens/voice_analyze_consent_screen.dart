import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
import 'voice_analyze_screen.dart';

class VoiceAnalyzeConsentScreen extends StatelessWidget {
  const VoiceAnalyzeConsentScreen({super.key});

  static const Color _noticeBorder = Color(0xFFFED7BC);
  static const Color _noticeIcon = Color(0xFFF25C05);
  static const Color _noticeBackground = Color(0xFFFFF9F4);

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
            const AppTopHeader.withBack(title: 'Ses Sağlığı Ön Tarama Testi'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _NoticeCard(
                      icon: Icons.error_outline_rounded,
                      title: 'Önemli Bilgilendirme',
                      content:
                          'Bu uygulama yalnızca ses sağlığına yönelik ön değerlendirme sağlar ve tıbbi tanı yerine geçmez.\n\nSesinizde olağandışı bir durum fark ederseniz, bir Kulak Burun Boğaz uzmanına başvurmanız önerilir.',
                    ),
                    const SizedBox(height: 12),
                    const _NoticeCard(
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
                          style: TextStyle(fontSize: 16),
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
        color: VoiceAnalyzeConsentScreen._noticeBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VoiceAnalyzeConsentScreen._noticeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  color: VoiceAnalyzeConsentScreen._noticeIcon, size: 28),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
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
              fontSize: 14,
              height: 1.38,
              color: Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }
}
