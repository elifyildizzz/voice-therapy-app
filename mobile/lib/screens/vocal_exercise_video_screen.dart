import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/pitch_reading.dart';
import '../services/live_pitch_tracker.dart';
import '../theme/app_theme.dart';
import '../widgets/live_pitch_chart.dart';
import 'vocal_measurement_screen.dart';
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
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TherapistVideoPlayer(
                      controller: _videoController,
                      isVideoReady: _isVideoReady,
                      isVideoLoading: _isVideoLoading,
                      cropTopFraction: widget.exercise.videoCropTopFraction,
                      cropHeightFraction:
                          widget.exercise.videoCropHeightFraction,
                      onTogglePlayback: _toggleVideoPlayback,
                    ),
                    if (widget.exercise.howToText != null) ...[
                      const SizedBox(height: 20),
                      _HowToSection(
                        text: widget.exercise.howToText!,
                        showMeasurementButton:
                            widget.exercise.supportsMeasurement,
                        onMeasurementTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => VocalMeasurementScreen(
                                exercise: widget.exercise,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _LivePitchSection(
                        currentHz: _currentHz,
                        isListening: _isListening,
                        isBusy: _isBusy,
                        trackingStatus: _trackingStatus,
                        points: _points,
                        onToggle: _toggleListening,
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

class _PlainVideoHeader extends StatelessWidget {
  const _PlainVideoHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 20, 6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.cardBorder),
        ),
      ),
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

class _TherapistVideoPlayer extends StatelessWidget {
  const _TherapistVideoPlayer({
    required this.controller,
    required this.isVideoReady,
    required this.isVideoLoading,
    required this.cropTopFraction,
    required this.cropHeightFraction,
    required this.onTogglePlayback,
  });

  final VideoPlayerController? controller;
  final bool isVideoReady;
  final bool isVideoLoading;
  final double cropTopFraction;
  final double cropHeightFraction;
  final Future<void> Function() onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    final isPlaying = controller?.value.isPlaying ?? false;
    final canTogglePlayback = isVideoReady && controller != null;
    final videoValue = controller?.value;
    final videoDuration = videoValue != null && videoValue.isInitialized
        ? videoValue.duration
        : null;
    final videoPosition = videoValue != null && videoValue.isInitialized
        ? videoValue.position
        : Duration.zero;
    final aspectRatio = videoValue != null &&
            videoValue.isInitialized &&
            videoValue.aspectRatio > 0
        ? videoValue.aspectRatio / cropHeightFraction.clamp(0.1, 1.0).toDouble()
        : 16 / 9;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canTogglePlayback ? () => unawaited(onTogglePlayback()) : null,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.soft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: isVideoReady && controller != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          _CroppedVideoPlayer(
                            controller: controller!,
                            cropTopFraction: cropTopFraction,
                            cropHeightFraction: cropHeightFraction,
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.04),
                            ),
                          ),
                        ],
                      )
                    : const _VideoPlaceholder(),
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
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.82),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 46,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
              ),
              if (canTogglePlayback && controller != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.62),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 42, 14, 12),
                      child: Row(
                        children: [
                          Text(
                            _formatVideoDuration(videoPosition),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatVideoDuration(
                              videoDuration ?? Duration.zero,
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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

class _CroppedVideoPlayer extends StatelessWidget {
  const _CroppedVideoPlayer({
    required this.controller,
    required this.cropTopFraction,
    required this.cropHeightFraction,
  });

  final VideoPlayerController controller;
  final double cropTopFraction;
  final double cropHeightFraction;

  @override
  Widget build(BuildContext context) {
    final videoSize = controller.value.size;
    final rawAspectRatio = controller.value.aspectRatio;
    final cropHeight = cropHeightFraction.clamp(0.1, 1.0).toDouble();
    final cropTop = cropTopFraction.clamp(0.0, 1 - cropHeight).toDouble();

    if (videoSize.isEmpty || rawAspectRatio <= 0) {
      return VideoPlayer(controller);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width <= 0) {
          return VideoPlayer(controller);
        }

        final rawHeight = width / rawAspectRatio;

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minWidth: width,
            maxWidth: width,
            minHeight: rawHeight,
            maxHeight: rawHeight,
            child: Transform.translate(
              offset: Offset(0, -rawHeight * cropTop),
              child: SizedBox(
                width: width,
                height: rawHeight,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: videoSize.width,
                    height: videoSize.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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

class _HowToSection extends StatelessWidget {
  const _HowToSection({
    required this.text,
    this.showMeasurementButton = false,
    this.onMeasurementTap,
  });

  final String text;
  final bool showMeasurementButton;
  final VoidCallback? onMeasurementTap;

  @override
  Widget build(BuildContext context) {
    final items = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Text(
              'Nasıl Yapmalısın?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.cardBorder,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == items.length - 1 ? 0 : 6,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            items[index],
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (showMeasurementButton) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: onMeasurementTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.buttonPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.task_alt_rounded, size: 20),
                      label: const Text('Ölçüm yap'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePitchSection extends StatelessWidget {
  const _LivePitchSection({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Canlı Pitch Grafiği',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
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
        const SizedBox(height: 20),
        LivePitchChart(points: points),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              currentHz == null
                  ? '-- Hz'
                  : '${currentHz!.toStringAsFixed(1)} Hz',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: AppTheme.primary,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: isBusy ? null : onToggle,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.buttonPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
              ),
              icon: Icon(
                isListening
                    ? Icons.stop_circle_outlined
                    : Icons.mic_none_rounded,
              ),
              label: Text(
                isListening ? 'Durdur' : 'Başlat',
              ),
            ),
          ],
        ),
      ],
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
