import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _hasUnsavedMeasurement = false;

  List<MeasurementRecord> get _records =>
      MeasurementDraftStore.recordsForToday(widget.exercise.titleEn);

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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
    _ticker?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    setState(() {
      _elapsed = Duration.zero;
      _hasUnsavedMeasurement = false;
    });
  }

  void _saveMeasurement() {
    final slot = MeasurementDraftStore.saveToday(
      exerciseKey: widget.exercise.titleEn,
      duration: _elapsed,
    );

    if (slot == null) {
      _showMessage('Bugün için iki ölçüm zaten kaydedildi.');
      return;
    }

    _showMessage(
      slot == 1 ? 'İlk ölçüm kaydedildi.' : 'İkinci ölçüm kaydedildi.',
    );
    _resetTimer();
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
            const _MeasurementHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StopwatchCard(
                      elapsed: _elapsed,
                      isRunning: _stopwatch.isRunning,
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
                    _DailyRecordsCard(records: _records),
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
                              onPressed: _resetTimer,
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
                              child: const Text(
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
  const _MeasurementHeader();

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
          const Text(
            'Süre Ölçümü',
            style: TextStyle(
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
    required this.onToggle,
  });

  final Duration elapsed;
  final bool isRunning;
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
                        isRunning ? 'Durdur' : 'Başlat',
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
  });

  final List<MeasurementRecord> records;

  @override
  Widget build(BuildContext context) {
    final first = records.isNotEmpty ? records[0].duration : null;
    final second = records.length > 1 ? records[1].duration : null;
    final maxSeconds = [
      first?.inSeconds ?? 0,
      second?.inSeconds ?? 0,
      1,
    ].reduce(math.max).toDouble();

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
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 146,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _MeasurementBar(
                    label: 'İlk ölçüm',
                    duration: first,
                    maxSeconds: maxSeconds,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _MeasurementBar(
                    label: 'İkinci ölçüm',
                    duration: second,
                    maxSeconds: maxSeconds,
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

class _MeasurementBar extends StatelessWidget {
  const _MeasurementBar({
    required this.label,
    required this.duration,
    required this.maxSeconds,
  });

  final String label;
  final Duration? duration;
  final double maxSeconds;

  @override
  Widget build(BuildContext context) {
    final seconds = duration?.inSeconds.toDouble() ?? 0;
    final ratio =
        duration == null ? 0.12 : (seconds / maxSeconds).clamp(0.18, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          duration == null ? 'Ölçüm yapılmadı' : _formatDuration(duration!),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: duration == null ? AppTheme.textMuted : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEE7DE)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 34,
                        height: 84 * ratio,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: duration == null
                                ? const [
                                    Color(0xFFE9E3DB),
                                    Color(0xFFD9D2C9),
                                  ]
                                : const [
                                    Color(0xFFC9D9F0),
                                    Color(0xFF88AAD8),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class MeasurementRecord {
  const MeasurementRecord({
    required this.duration,
    required this.savedAt,
  });

  final Duration duration;
  final DateTime savedAt;
}

class MeasurementDraftStore {
  static final Map<String, List<MeasurementRecord>> _recordsByKey =
      <String, List<MeasurementRecord>>{};

  static List<MeasurementRecord> recordsForToday(String exerciseKey) {
    final today = DateTime.now();
    return List<MeasurementRecord>.unmodifiable(
      (_recordsByKey[exerciseKey] ?? <MeasurementRecord>[])
          .where((record) => _isSameDay(record.savedAt, today))
          .toList(),
    );
  }

  static int? saveToday({
    required String exerciseKey,
    required Duration duration,
  }) {
    final todayRecords = recordsForToday(exerciseKey);
    if (todayRecords.length >= 2) {
      return null;
    }

    final allRecords = _recordsByKey.putIfAbsent(
      exerciseKey,
      () => <MeasurementRecord>[],
    );
    allRecords.add(
      MeasurementRecord(
        duration: duration,
        savedAt: DateTime.now(),
      ),
    );
    return todayRecords.length + 1;
  }

  static bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}
