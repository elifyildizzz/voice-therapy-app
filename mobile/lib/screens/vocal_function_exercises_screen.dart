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
      levelColor: Color(0xFFBEE9CB),
      levelTextColor: Color(0xFF2D6B3F),
      videoAssetPath: 'assets/videos/vocal_function/exercise_1.mp4',
      thumbnailAssetPath: 'assets/videos/vocal_function/exercise_1_thumb.jpg',
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 2',
      titleEn: 'Dil Trill',
      durationMinutes: 4,
      level: 'Orta',
      levelColor: Color(0xFFF2DEB8),
      levelTextColor: Color(0xFF92672A),
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 3',
      titleEn: 'Humming',
      durationMinutes: 5,
      level: 'Kolay',
      levelColor: Color(0xFFBEE9CB),
      levelTextColor: Color(0xFF2D6B3F),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.cardBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasThumbnail)
                        Image.asset(
                          exercise.thumbnailAssetPath!,
                          fit: BoxFit.cover,
                        )
                      else
                        const ColoredBox(color: AppTheme.darkBlue),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: hasThumbnail ? 0.18 : 0,
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.titleEn,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3643),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exercise.titleTr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: Color(0xFF8E8E93),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          durationText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF8E8E93),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
