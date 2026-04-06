import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
import 'vocal_exercise_video_screen.dart';
import 'warmup_exercise.dart';

class VocalFunctionExercisesScreen extends StatelessWidget {
  const VocalFunctionExercisesScreen({super.key});

  static const List<WarmupExercise> _exercises = [
    WarmupExercise(
      titleTr: 'Egzersiz 1',
      titleEn: 'Dudak Trill',
      durationMinutes: 3,
      durationLabel: '00:09',
      level: 'Kolay',
      levelColor: AppTheme.soft,
      levelTextColor: AppTheme.primary,
      videoAssetPath: 'assets/videos/vocal_function/exercise_1.mp4',
      thumbnailAssetPath: 'assets/videos/vocal_function/exercise_1_thumb.jpg',
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 2',
      titleEn: 'Dil Trill',
      durationMinutes: 4,
      level: 'Orta',
      levelColor: AppTheme.sand,
      levelTextColor: AppTheme.terracotta,
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 3',
      titleEn: 'Humming',
      durationMinutes: 5,
      level: 'Kolay',
      levelColor: AppTheme.soft,
      levelTextColor: AppTheme.primary,
    ),
  ];

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
            const AppTopHeader.withBack(title: 'Vokal Fonksiyon Egzersizleri'),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: _exercises.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final item = _exercises[index];
                  return _ExerciseCard(
                    exercise: item,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              VocalExerciseVideoScreen(exercise: item),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.onTap,
  });

  final WarmupExercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasThumbnail = exercise.thumbnailAssetPath != null;
    final durationText =
        exercise.durationLabel ?? '${exercise.durationMinutes} dk';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppTheme.light.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasThumbnail)
                      Image.asset(
                        exercise.thumbnailAssetPath!,
                        fit: BoxFit.cover,
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: hasThumbnail
                            ? Colors.black.withValues(alpha: 0.16)
                            : AppTheme.light.withValues(alpha: 0.2),
                      ),
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.titleEn,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.titleTr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          durationText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppTheme.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
