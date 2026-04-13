import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/pitch_reading.dart';
import '../services/live_pitch_tracker.dart';
import '../theme/app_theme.dart';
import '../widgets/live_pitch_chart.dart';
import 'warmup_exercise.dart';

class VocalExerciseVideoScreen extends StatefulWidget {
  const VocalExerciseVideoScreen({
    super.key,
    required this.exercise,
  });

  final WarmupExercise exercise;

  @override
  State<VocalExerciseVideoScreen> createState() =>
      _VocalExerciseVideoScreenState();
}

class _VocalExerciseVideoScreenState extends State<VocalExerciseVideoScreen> {
  static const Duration _chartWindow = Duration(seconds: 6);

  final LivePitchTracker _pitchTracker = LivePitchTracker();

  StreamSubscription<PitchReading>? _pitchSubscription;
  VideoPlayerController? _videoController;
  List<PitchReading> _points = <PitchReading>[];
  double? _currentHz;
  bool _isListening = false;
  bool _isBusy = false;
  bool _isVideoReady = false;
  bool _isVideoLoading = false;

  String get _trackingStatus {
    if (_isBusy) {
      return 'Hazırlanıyor';
    }
    if (_isListening && _currentHz != null) {
      return 'Ses algılanıyor';
    }
    if (_isListening) {
      return 'Dinleniyor';
    }
    return 'Hazır';
  }

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _pitchSubscription = _pitchTracker.readings.listen(
      _handlePitchReading,
      onError: (_) {
        _showMessage('Canlı pitch analizi sırasında bir hata oluştu.');
        if (!mounted) {
          return;
        }

        setState(() {
          _isListening = false;
          _isBusy = false;
          _currentHz = null;
        });
      },
    );
  }

  Future<void> _initializeVideo() async {
    final videoAssetPath = widget.exercise.videoAssetPath;
    if (videoAssetPath == null) {
      return;
    }

    final controller = VideoPlayerController.asset(videoAssetPath);

    setState(() {
      _isVideoLoading = true;
    });

    try {
      await controller.initialize();
      await controller.setLooping(false);
      controller.addListener(_onVideoChanged);

      if (!mounted) {
        controller.removeListener(_onVideoChanged);
        await controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _isVideoReady = true;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        _showMessage('Video yüklenemedi.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
        });
      }
    }
  }

  void _onVideoChanged() {
    final controller = _videoController;
    if (!mounted || controller == null || !controller.value.isInitialized) {
      return;
    }

    final value = controller.value;
    if (value.position >= value.duration &&
        value.duration > Duration.zero &&
        value.isPlaying) {
      unawaited(controller.pause());
    }

    setState(() {});
  }

  Future<void> _toggleVideoPlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      await controller.seekTo(Duration.zero);
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handlePitchReading(PitchReading reading) {
    if (!mounted) {
      return;
    }

    final cutoff = reading.timestamp.subtract(
      _chartWindow + const Duration(seconds: 1),
    );

    setState(() {
      _points = <PitchReading>[
        for (final point in _points)
          if (!point.timestamp.isBefore(cutoff)) point,
        reading,
      ];
      _currentHz = reading.hz;
    });
  }

  Future<void> _toggleListening() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      if (_isListening) {
        await _pitchTracker.stop();
        if (!mounted) {
          return;
        }

        setState(() {
          _isListening = false;
          _currentHz = null;
        });
      } else {
        await _pitchTracker.start();
        if (!mounted) {
          return;
        }

        setState(() {
          _isListening = true;
          _currentHz = null;
          _points = <PitchReading>[];
        });
      }
    } on PitchTrackerException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Canlı pitch analizi başlatılamadı.');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _pitchSubscription?.cancel();
    unawaited(_pitchTracker.dispose());
    _videoController?.removeListener(_onVideoChanged);
    unawaited(_videoController?.dispose() ?? Future<void>.value());
    super.dispose();
  }

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
            _PlainVideoHeader(title: widget.exercise.titleEn),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TherapistVideoCard(
                      exercise: widget.exercise,
                      controller: _videoController,
                      isVideoReady: _isVideoReady,
                      isVideoLoading: _isVideoLoading,
                      onTogglePlayback: _toggleVideoPlayback,
                    ),
                    const SizedBox(height: 16),
                    const _InstructionCard(),
                    const SizedBox(height: 16),
                    _LivePitchCard(
                      currentHz: _currentHz,
                      isListening: _isListening,
                      isBusy: _isBusy,
                      trackingStatus: _trackingStatus,
                      points: _points,
                      onToggle: _toggleListening,
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

class _PlainVideoHeader extends StatelessWidget {
  const _PlainVideoHeader({
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
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
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

class _TherapistVideoCard extends StatelessWidget {
  const _TherapistVideoCard({
    required this.exercise,
    required this.controller,
    required this.isVideoReady,
    required this.isVideoLoading,
    required this.onTogglePlayback,
  });

  final WarmupExercise exercise;
  final VideoPlayerController? controller;
  final bool isVideoReady;
  final bool isVideoLoading;
  final Future<void> Function() onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    final hasVideoAsset = exercise.videoAssetPath != null;
    final isPlaying = controller?.value.isPlaying ?? false;
    final canTogglePlayback = isVideoReady && controller != null;
    final videoValue = controller?.value;
    final videoDuration = videoValue != null && videoValue.isInitialized
        ? videoValue.duration
        : null;
    final videoPosition = videoValue != null && videoValue.isInitialized
        ? videoValue.position
        : Duration.zero;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: canTogglePlayback
                  ? () => unawaited(onTogglePlayback())
                  : null,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: AppTheme.soft,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: isVideoReady && controller != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: controller!.value.size.width,
                                      height: controller!.value.size.height,
                                      child: VideoPlayer(controller!),
                                    ),
                                  ),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                    ),
                                  ),
                                ],
                              )
                            : const _VideoPlaceholder(),
                      ),
                    ),
                    Center(
                      child: isVideoLoading
                          ? const SizedBox(
                              width: 34,
                              height: 34,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: isPlaying ? 0 : 1,
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppTheme.headerStart,
                                      AppTheme.headerEnd,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 46,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            exercise.titleEn,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasVideoAsset
                ? 'Video bir kez oynar ve sonda durur. Tekrar oynatmak için oynat düğmesine basabilirsiniz.'
                : 'Bu bölüm video akışını göstermek için hazır durumda tutulur.',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textMuted,
              height: 1.45,
            ),
          ),
          if (canTogglePlayback && controller != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: VideoProgressIndicator(
                controller!,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: AppTheme.headerEnd,
                  bufferedColor: AppTheme.headerStart,
                  backgroundColor: AppTheme.soft,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatVideoDuration(videoPosition),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatVideoDuration(videoDuration ?? Duration.zero),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatVideoDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFDCE7E1),
            Color(0xFFEDF4F0),
          ],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kullanım Akışı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Videodaki trill hareketini ve ses yüksekliğini takip edin.',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textMuted,
              height: 1.45,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Başlat düğmesine bastığınızda mikrofon açılır ve sesinizin pitch değeri anlık olarak çizilir.',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textMuted,
              height: 1.45,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Sessizlikte veya güvenilir olmayan anlarda çizgi kopar, böylece grafik yanıltıcı olmaz.',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePitchCard extends StatelessWidget {
  const _LivePitchCard({
    required this.currentHz,
    required this.isListening,
    required this.isBusy,
    required this.trackingStatus,
    required this.points,
    required this.onToggle,
  });

  final double? currentHz;
  final bool isListening;
  final bool isBusy;
  final String trackingStatus;
  final List<PitchReading> points;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Canlı Pitch Grafiği',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _StatusPill(
                label: trackingStatus,
                isActive: isListening,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currentHz == null ? '--' : currentHz!.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Hz',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Grafik son birkaç saniyeyi daha hassas gösterecek şekilde ayarlanmıştır; küçük pitch değişimleri de daha belirgin görünür.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          LivePitchChart(points: points),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy ? null : onToggle,
              style: FilledButton.styleFrom(
                backgroundColor:
                    isListening ? AppTheme.terracotta : AppTheme.primary,
              ),
              icon: Icon(
                isListening
                    ? Icons.stop_circle_outlined
                    : Icons.mic_none_rounded,
              ),
              label: Text(
                isListening ? 'Dinlemeyi Durdur' : 'Canlı Analizi Başlat',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.isActive,
  });

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.soft : AppTheme.sand.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? AppTheme.primary : AppTheme.textMuted,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
