import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
import 'vocal_exercise_video_screen.dart';
import 'warmup_exercise.dart';

class VocalFunctionExercisesScreen extends StatelessWidget {
  const VocalFunctionExercisesScreen({super.key});

  static const List<WarmupExercise> _exercises = [
    WarmupExercise(
      titleTr: 'Egzersiz 1',
      titleEn: 'Isınma Egzersizi',
      durationMinutes: 4,
      level: 'Kolay',
      levelColor: AppTheme.soft,
      levelTextColor: AppTheme.primary,
      videoAssetPath: 'assets/videos/vocal_function/isinma_egzersizi.mp4',
      iconAssetPath: 'assets/icons/vocal_function/wind.svg',
      videoCropTopFraction: 312 / 848,
      videoCropHeightFraction: 224 / 848,
      howToText:
          'Derin bir diyafram nefesi alın. En rahat olduğunuz ses tonunuzda, "/i/" sesini nefesiniz yettiği kadar uzatın. Sesi sürdürürken boğazınızı sıkmadığınızdan emin olun. Bu egzersiz, sesi ısıtmak için yapılmaktadır. Bu egzersiz süre takibi ile yapılır. Uzatma süreniz kayıt altına alınır. Performansınız süreye göre izlenir.',
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 2',
      titleEn: 'Germe Egzersizi',
      durationMinutes: 4,
      level: 'Orta',
      levelColor: AppTheme.sand,
      levelTextColor: AppTheme.terracotta,
      videoAssetPath: 'assets/videos/vocal_function/germe_egzersizi.mp4',
      iconAssetPath: 'assets/icons/vocal_function/user-sound-bold.svg',
      videoCropTopFraction: 266 / 832,
      videoCropHeightFraction: 304 / 832,
      howToText:
          'Derin bir nefes alın. Çıkarabildiğiniz en kalın (pes) tondan başlayarak, sesinizi kesintisiz bir şekilde en ince (tiz) tonunuza kadar yükseltin. Sesi yükseltirken boğazınızı sıkmadığınızdan emin olun. Bu egzersiz ses tellerini germek için yapılmaktadır.  İki kez yapılmalıdır. Süre ölçümü yapılmaz.',
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 3',
      titleEn: 'Gevşeme Egzersizi',
      durationMinutes: 5,
      level: 'Kolay',
      levelColor: AppTheme.soft,
      levelTextColor: AppTheme.primary,
      videoAssetPath: 'assets/videos/vocal_function/gevseme.mp4',
      iconAssetPath: 'assets/icons/vocal_function/pulse-bold.svg',
      videoCropTopFraction: 288 / 848,
      videoCropHeightFraction: 272 / 848,
      howToText:
          'Derin bir nefes alın. Çıkarabildiğiniz en ince (tiz) tondan başlayarak, sesinizi kesintisiz bir şekilde en kalın (pes) tonunuza kadar indirin. Sesi indirirken boğazınızı sıkmadığınızdan emin olun. Bu egzersiz ses tellerini gevşetmek için yapılmaktadır. İki kez yapılmalıdır. Süre ölçümü yapılmaz.',
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 4',
      titleEn: 'Tiz Perdede Fonasyon',
      durationMinutes: 4,
      level: 'Orta',
      levelColor: AppTheme.sand,
      levelTextColor: AppTheme.terracotta,
      videoAssetPath: 'assets/videos/vocal_function/tiz_perdede_fonasyon.mp4',
      iconAssetPath: 'assets/icons/vocal_function/trend-up-bold.svg',
      videoCropTopFraction: 272 / 848,
      videoCropHeightFraction: 304 / 848,
      howToText:
          'Derin bir nefes alın. Çıkarabildiğiniz en rahat ve en ince (tiz) ses tonuyla, sesi kesintisiz bir şekilde uzatabildiğiniz kadar uzatın. Sesi sürdürürken boğazınızı sıkmadığınızdan emin olun.  Bu egzersiz süre takibi ile yapılır. Uzatma süreniz kayıt altına alınır. Performansınız süreye göre izlenir.',
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 5',
      titleEn: 'Uzatılmış Fonasyon',
      durationMinutes: 5,
      level: 'Orta',
      levelColor: AppTheme.sand,
      levelTextColor: AppTheme.terracotta,
      videoAssetPath: 'assets/videos/vocal_function/uzatilmis_fonasyon.mp4',
      iconAssetPath: 'assets/icons/vocal_function/waveform-bold.svg',
      videoCropTopFraction: 266 / 832,
      videoCropHeightFraction: 304 / 832,
      howToText:
          'Derin bir nefes alın. En rahat, günlük konuşma tonunuzdaki (normal) sesle, sesi kesintisiz bir şekilde uzatabildiğiniz kadar uzatın. Sesi sürdürürken boğazınızı sıkmadığınızdan emin olun.  Bu egzersiz süre takibi ile yapılır. Uzatma süreniz kayıt altına alınır. Performansınız süreye göre izlenir.',
    ),
    WarmupExercise(
      titleTr: 'Egzersiz 6',
      titleEn: 'Pes Perdede Fonasyon',
      durationMinutes: 4,
      level: 'Kolay',
      levelColor: AppTheme.soft,
      levelTextColor: AppTheme.primary,
      videoAssetPath: 'assets/videos/vocal_function/pes_perdede_fonasyon.mp4',
      iconAssetPath: 'assets/icons/vocal_function/trend-down-bold.svg',
      videoCropTopFraction: 272 / 848,
      videoCropHeightFraction: 304 / 848,
      howToText:
          'Derin bir nefes alın. Çıkarabildiğiniz en rahat ve en kalın (pes) ses tonuyla, sesi kesintisiz bir şekilde uzatabildiğiniz kadar uzatın. Sesi sürdürürken boğazınızı sıkmadığınızdan emin olun. Bu egzersiz süre takibi ile yapılır. Uzatma süreniz kayıt altına alınır. Performansınız süreye göre izlenir.',
    ),
  ];

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
            const AppTopHeader.withBack(
              title: 'Vokal Fonksiyon Egzersizleri',
              showDivider: true,
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                itemCount: _exercises.length + 1,
                separatorBuilder: (context, index) =>
                    SizedBox(height: index == 0 ? 18 : 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const _ExerciseFrequencyNote();
                  }

                  final item = _exercises[index - 1];
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

class _ExerciseFrequencyNote extends StatelessWidget {
  const _ExerciseFrequencyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAE6)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.repeat_rounded,
              color: AppTheme.textPrimary,
              size: 18,
            ),
          ),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Egzersizler günde 2 kez uygulanmalıdır',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Sabah ve akşam tekrar edilmesi önerilir',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  static const Color _chevronColor = Color(0xFF8DA292);

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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.homeIconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Center(
                  child: _ExerciseIcon(assetPath: exercise.iconAssetPath),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.titleTr,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        _ExerciseDurationText(
                          exercise: exercise,
                        ),
                      ],
                    ),
                  ],
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

class _ExerciseIcon extends StatelessWidget {
  const _ExerciseIcon({
    required this.assetPath,
  });

  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final assetPath = this.assetPath;
    if (assetPath == null) {
      return const Icon(
        Icons.play_arrow_rounded,
        color: AppTheme.homeAccent,
        size: 22,
      );
    }

    return SvgPicture.asset(
      assetPath,
      width: 24,
      height: 24,
      colorFilter: const ColorFilter.mode(
        AppTheme.homeAccent,
        BlendMode.srcIn,
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
