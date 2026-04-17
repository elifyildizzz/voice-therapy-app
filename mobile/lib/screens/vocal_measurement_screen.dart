import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/measurement_record.dart';
import '../services/measurement_repository.dart';
import '../theme/app_theme.dart';
import 'warmup_exercise.dart';

class VocalMeasurementScreen extends StatefulWidget {
  const VocalMeasurementScreen({
    super.key,
    required this.exercise,
  });

  final WarmupExercise exercise;

  @override
  State<VocalMeasurementScreen> createState() => _VocalMeasurementScreenState();
}

class _VocalMeasurementScreenState extends State<VocalMeasurementScreen> {
  static const Duration _tick = Duration(milliseconds: 100);

  final Stopwatch _stopwatch = Stopwatch();
  final MeasurementRepository _repository = MeasurementRepository.instance;

  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _hasUnsavedMeasurement = false;
  bool _isLoadingRecords = true;
  bool _isSavingMeasurement = false;
  List<MeasurementRecord> _records = const <MeasurementRecord>[];

  @override
  void initState() {
    super.initState();
    final cachedRecords = _repository.peekRecordsForToday(
      module: MeasurementRepository.vocalFunctionModule,
      exerciseKey: widget.exercise.titleEn,
    );
    if (_repository.hasLoadedCache) {
      _records = cachedRecords;
      _isLoadingRecords = false;
    } else {
      unawaited(_loadRecords());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    try {
      final records = await _repository.fetchRecordsForToday(
        module: MeasurementRepository.vocalFunctionModule,
        exerciseKey: widget.exercise.titleEn,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
        _isLoadingRecords = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingRecords = false;
      });
      _showMessage('Ölçüm kayıtları yüklenemedi.');
    }
  }

  void _toggleTimer() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _ticker?.cancel();
      setState(() {
        _elapsed = _stopwatch.elapsed;
        _hasUnsavedMeasurement = _elapsed > Duration.zero;
      });
      return;
    }

    if (_elapsed > Duration.zero) {
      _stopwatch
        ..stop()
        ..reset();
      _elapsed = Duration.zero;
      _hasUnsavedMeasurement = false;
    }

    _stopwatch.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _elapsed = _stopwatch.elapsed;
      });
    });
    setState(() {});
  }

  void _resetTimer() {
    if (_isSavingMeasurement) {
      return;
    }

    _clearMeasurementState();
  }

  void _clearMeasurementState() {
    _ticker?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    setState(() {
      _elapsed = Duration.zero;
      _hasUnsavedMeasurement = false;
    });
  }

  Future<void> _saveMeasurement() async {
    if (_isSavingMeasurement) {
      return;
    }

    setState(() {
      _isSavingMeasurement = true;
    });

    try {
      final slot = await _repository.saveRecord(
        module: MeasurementRepository.vocalFunctionModule,
        exerciseKey: widget.exercise.titleEn,
        exerciseTitle: widget.exercise.titleEn,
        duration: _elapsed,
      );
      await _loadRecords();
      _showMessage(
        slot == 1 ? 'İlk ölçüm kaydedildi.' : 'İkinci ölçüm kaydedildi.',
      );
      _clearMeasurementState();
    } on MeasurementSaveLimitException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Ölçüm kaydedilirken bir sorun oluştu.');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingMeasurement = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instruction = widget.exercise.measurementInstruction ??
        widget.exercise.howToText ??
        '';
    final canSave = !_stopwatch.isRunning &&
        !_isSavingMeasurement &&
        _hasUnsavedMeasurement &&
        _elapsed > Duration.zero;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            _MeasurementHeader(title: widget.exercise.titleEn),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StopwatchCard(
                      elapsed: _elapsed,
                      isRunning: _stopwatch.isRunning,
                      hasElapsedValue: _elapsed > Duration.zero,
                      onToggle: _toggleTimer,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Bu sayfada ${widget.exercise.titleEn.toLowerCase()} için $instruction',
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _DailyRecordsCard(
                      records: _records,
                      isLoading: _isLoadingRecords,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '* Günde iki ölçüm kaydı yapabilirsiniz.',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x140F1B16),
                                  blurRadius: 16,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: OutlinedButton(
                              onPressed:
                                  _isSavingMeasurement ? null : _resetTimer,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textPrimary,
                                side:
                                    const BorderSide(color: Color(0xFFECE7E0)),
                                backgroundColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Text(
                                'Tekrar Dene',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: canSave
                                  ? AppTheme.buttonPrimary
                                  : AppTheme.buttonPrimary
                                      .withValues(alpha: 0.45),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x140F1B16),
                                  blurRadius: 16,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: FilledButton(
                              onPressed: canSave ? _saveMeasurement : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                surfaceTintColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                disabledForegroundColor:
                                    Colors.white.withValues(alpha: 0.8),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: _isSavingMeasurement
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Kaydediliyor...',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Kaydet',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
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

class _MeasurementHeader extends StatelessWidget {
  const _MeasurementHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.cardBorder),
        ),
      ),
      child: Row(
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StopwatchCard extends StatelessWidget {
  const _StopwatchCard({
    required this.elapsed,
    required this.isRunning,
    required this.hasElapsedValue,
    required this.onToggle,
  });

  final Duration elapsed;
  final bool isRunning;
  final bool hasElapsedValue;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final seconds = elapsed.inMilliseconds / 1000;
    final progress = (seconds % 60) / 60;

    return Center(
      child: SizedBox(
        width: 214,
        height: 214,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(214),
              painter: _RingPainter(progress: progress, isRunning: isRunning),
            ),
            Container(
              width: 196,
              height: 196,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x140F1B16),
                    blurRadius: 26,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatDuration(elapsed),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isRunning ? 'Ölçülüyor' : 'Hazır',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7A838F),
                    ),
                  ),
                  const SizedBox(height: 26),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: isRunning
                          ? AppTheme.buttonPressed
                          : AppTheme.buttonPrimary,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A7FA58D),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: onToggle,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        isRunning
                            ? 'Durdur'
                            : hasElapsedValue
                                ? 'Tekrar Başlat'
                                : 'Başlat',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.isRunning,
  });

  final double progress;
  final bool isRunning;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: (size.width / 2) - 8);
    final basePaint = Paint()
      ..color = const Color(0xFFE9E4DD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = const Color(0xFFB8CEB5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 2, false, basePaint);
    if (isRunning) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * math.max(progress, 0.04),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isRunning != isRunning;
  }
}

class _DailyRecordsCard extends StatelessWidget {
  const _DailyRecordsCard({
    required this.records,
    required this.isLoading,
  });

  final List<MeasurementRecord> records;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final first = records.isNotEmpty ? records[0].duration : null;
    final second = records.length > 1 ? records[1].duration : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bugünkü Ölçümler',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const Text(
              'Kayıtlar yükleniyor...',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            )
          else ...[
            _MeasurementRow(
              label: '1. Ölçüm',
              duration: first,
            ),
            const SizedBox(height: 8),
            _MeasurementRow(
              label: '2. Ölçüm',
              duration: second,
            ),
          ],
        ],
      ),
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({
    required this.label,
    required this.duration,
  });

  final String label;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          duration != null ? _formatDuration(duration!) : '-',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inMilliseconds / 1000;
    return '${totalSeconds.toStringAsFixed(1)} sn';
  }
}
