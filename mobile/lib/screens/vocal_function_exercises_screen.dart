import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';
import 'vocal_exercise_video_screen.dart';
import 'warmup_exercise.dart';

class VocalFunctionExercisesScreen extends StatelessWidget {
  const VocalFunctionExercisesScreen({super.key});

  static const List<WarmupExercise> _exercises = [
    WarmupExercise(
      titleTr: 'Egzersiz 1',
      titleEn: 'Germe egzersizi',
      durationMinutes: 4,
      level: 'Orta',
      levelColor: AppTheme.sand,
      levelTextColor: AppTheme.terracotta,
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 2',
      titleEn: 'Gevşeme egzersizi',
      durationMinutes: 5,
      level: 'Kolay',
      levelColor: AppTheme.soft,
      levelTextColor: AppTheme.primary,
      videoAssetPath: 'assets/videos/vocal_function/gevseme.mp4',
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 3',
      titleEn: 'Tiz perdede fonasyon',
      durationMinutes: 4,
      level: 'Orta',
      levelColor: AppTheme.sand,
      levelTextColor: AppTheme.terracotta,
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 4',
      titleEn: 'Uzatılmış fonasyon',
      durationMinutes: 5,
      level: 'Orta',
      levelColor: AppTheme.sand,
      levelTextColor: AppTheme.terracotta,
      videoAssetPath: 'assets/videos/vocal_function/uzatilmis_fonasyon.mp4',
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 5',
      titleEn: 'Pes perdede fonasyon',
      durationMinutes: 4,
      level: 'Kolay',
      levelColor: AppTheme.soft,
      levelTextColor: AppTheme.primary,
      videoAssetPath: 'assets/videos/vocal_function/pes_perdede_fonasyon.mp4',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            const _PlainPageHeader(title: 'Vokal Fonksiyon Egzersizleri'),
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

class _PlainPageHeader extends StatelessWidget {
  const _PlainPageHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Vokal Fonksiyon Egzersizleri',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.light.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.light.withValues(alpha: 0.2),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.titleEn,
                      style: const TextStyle(
                        fontSize: 16,
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        _ExerciseDurationText(
                          exercise: exercise,
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

class _ExerciseDurationText extends StatefulWidget {
  const _ExerciseDurationText({
    required this.exercise,
  });

  final WarmupExercise exercise;

  @override
  State<_ExerciseDurationText> createState() => _ExerciseDurationTextState();
}

class _ExerciseDurationTextState extends State<_ExerciseDurationText> {
  static final Map<String, Duration> _durationCache = <String, Duration>{};

  Duration? _resolvedDuration;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolvedDuration = _getCachedDuration();
    if (_resolvedDuration == null) {
      _loadDuration();
    }
  }

  @override
  void didUpdateWidget(covariant _ExerciseDurationText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.videoAssetPath != widget.exercise.videoAssetPath) {
      _resolvedDuration = _getCachedDuration();
      _isLoading = false;
      if (_resolvedDuration == null) {
        _loadDuration();
      }
    }
  }

  Duration? _getCachedDuration() {
    final videoAssetPath = widget.exercise.videoAssetPath;
    if (videoAssetPath == null) {
      return null;
    }
    return _durationCache[videoAssetPath];
  }

  Future<void> _loadDuration() async {
    final videoAssetPath = widget.exercise.videoAssetPath;
    if (videoAssetPath == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final controller = VideoPlayerController.asset(videoAssetPath);

    try {
      await controller.initialize();
      final duration = controller.value.duration;
      if (duration > Duration.zero) {
        _durationCache[videoAssetPath] = duration;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedDuration = duration > Duration.zero ? duration : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedDuration = null;
        _isLoading = false;
      });
    } finally {
      await controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _resolvedDuration;
    final hasVideo = widget.exercise.videoAssetPath != null;
    final fallbackText = widget.exercise.durationLabel != null
        ? widget.exercise.durationLabel!
        : '${widget.exercise.durationMinutes} dk';

    return Text(
      duration != null
          ? _formatDuration(duration)
          : _isLoading
              ? 'Yukleniyor...'
              : hasVideo
                  ? fallbackText
                  : fallbackText,
      style: const TextStyle(
        fontSize: 13,
        color: AppTheme.textMuted,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
