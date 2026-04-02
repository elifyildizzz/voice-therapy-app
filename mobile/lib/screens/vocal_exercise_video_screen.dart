import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/pitch_reading.dart';
import '../services/live_pitch_tracker.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
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
      if (!mounted) {
        return;
      }

      _showMessage('Video yüklenemedi.');
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
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            AppTopHeader.withBack(title: widget.exercise.titleEn),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: canTogglePlayback
                  ? () => unawaited(onTogglePlayback())
                  : null,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF48546B),
                      Color(0xFF72829B),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
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
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.04),
                                          Colors.black.withValues(alpha: 0.18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : DecoratedBox(
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
                    ),
                    Center(
                      child: isVideoLoading
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                                color: Colors.white,
                              ),
                            )
                          : AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: isPlaying ? 0.0 : 1.0,
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Text(
                        videoDuration == null
                            ? '${exercise.durationMinutes} dk'
                            : _formatVideoDuration(videoDuration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
          Text(
            hasVideoAsset
                ? 'Video bir kez oynar ve sonda durur. Tekrar oynatmak için oynat düğmesine basabilirsin.'
                : 'Terapistin dudak, nefes ve ses akışını videodan izleyin. Gerçek video dosyanızı daha sonra bu kartın içine yerleştirip aynı ekranda kullanıcı grafiğini altta canlı tutabilirsiniz.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF354254),
            ),
          ),
          if (canTogglePlayback && controller != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: VideoProgressIndicator(
                controller!,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: AppTheme.darkBlue,
                  bufferedColor: Color(0xFFB8C6D6),
                  backgroundColor: Color(0xFFE3EAF1),
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
                    color: Color(0xFF617185),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatVideoDuration(videoDuration ?? Duration.zero),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF617185),
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

class _InstructionCard extends StatelessWidget {
  const _InstructionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E4EC)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kullanım Akışı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkBlue,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Videodaki trill hareketini ve ses yüksekliğini takip edin.',
            style: TextStyle(fontSize: 14, color: Color(0xFF344254)),
          ),
          SizedBox(height: 6),
          Text(
            'Başlat düğmesine bastığınızda mikrofon açılır ve sesinizin pitch değeri anlık olarak çizilir.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF344254),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Sessizlikte veya güvenilir olmayan anlarda çizgi kopar, böylece grafik yanıltıcı olmaz.',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkBlue,
                  ),
                ),
              ),
              _StatusPill(
                label: trackingStatus,
                isActive: isListening,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currentHz == null ? '--' : currentHz!.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E2B3C),
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Hz',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6A7788),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Grafik son birkaç saniyeyi daha hassas gösterecek şekilde ayarlanmıştır; küçük pitch değişimleri de daha belirgin görünür.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF536174),
            ),
          ),
          const SizedBox(height: 16),
          LivePitchChart(points: points),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy ? null : onToggle,
              style: FilledButton.styleFrom(
                backgroundColor:
                    isListening ? const Color(0xFFE56A6A) : AppTheme.darkBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(
                isListening ? Icons.stop_circle_outlined : Icons.mic_rounded,
              ),
              label: Text(
                isListening ? 'Dinlemeyi Durdur' : 'Canlı Analizi Başlat',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
    final backgroundColor =
        isActive ? const Color(0xFFD7F2E7) : const Color(0xFFEAEFF5);
    final foregroundColor =
        isActive ? const Color(0xFF1F7C58) : const Color(0xFF637285);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
