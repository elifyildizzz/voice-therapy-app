import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
import 'warmup_exercise.dart';

class BreathControlVideoScreen extends StatelessWidget {
  const BreathControlVideoScreen({
    super.key,
    required this.exercise,
  });

  final WarmupExercise exercise;

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
            AppTopHeader.withBack(title: exercise.titleTr),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BreathVideoCard(exercise: exercise),
                    const SizedBox(height: 16),
                    const _BreathInstructionCard(),
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

class _BreathVideoCard extends StatelessWidget {
  const _BreathVideoCard({
    required this.exercise,
  });

  final WarmupExercise exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4B5A66),
                  Color(0xFF90A7B2),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 88,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Text(
                          'Nefes Egzersizi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${exercise.durationMinutes} dk',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            exercise.titleEn,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF556273),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Bu alan nefes kontrolü videoları için ayrıdır. Diyafram kullanımı, nefes alma-verme ritmi ve beden duruşu burada gösterilecek gerçek video ile takip edilebilir.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF354254),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreathInstructionCard extends StatelessWidget {
  const _BreathInstructionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E7EA)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nefes Kontrolü',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkBlue,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Videodaki nefes alma ve verme temposunu izleyin.',
            style: TextStyle(fontSize: 14, color: Color(0xFF344254)),
          ),
          SizedBox(height: 6),
          Text(
            'Omuzları kaldırmadan, kontrollü ve ritmik şekilde egzersizi tekrar edin.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF344254),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Bu ekran vokal pitch takibinden ayrıdır; nefes egzersizlerine özel içerik için kullanılacaktır.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF344254),
            ),
          ),
        ],
      ),
    );
  }
}
