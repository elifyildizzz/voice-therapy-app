import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';

enum _BreathControlStep {
  diaphragm,
  recording,
}

class BreathControlScreen extends StatefulWidget {
  const BreathControlScreen({super.key});

  @override
  State<BreathControlScreen> createState() => _BreathControlScreenState();
}

class _BreathControlScreenState extends State<BreathControlScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final Stopwatch _stopwatch = Stopwatch();

  Timer? _ticker;
  bool _isStarting = false;
  bool _isRecording = false;
  bool _isStopping = false;
  bool _stopAfterStart = false;
  double _elapsedSeconds = 0;
  double _bestSeconds = 0;
  _BreathControlStep _currentStep = _BreathControlStep.diaphragm;
  final List<_PhonationAttempt> _attempts = <_PhonationAttempt>[];

  Future<void> _startRecording() async {
    if (_isStarting || _isRecording || _isStopping) {
      return;
    }

    setState(() {
      _isStarting = true;
      _elapsedSeconds = 0;
    });

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _isStarting = false;
            _stopAfterStart = false;
          });
          _showMessage('Mikrofon izni verilmedi.');
        }
        return;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/maximum_a_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: path,
      );

      _ticker?.cancel();
      _stopwatch
        ..reset()
        ..start();

      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000;
        });
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _isStarting = false;
        _isRecording = true;
        _elapsedSeconds = 0;
      });

      if (_stopAfterStart) {
        _stopAfterStart = false;
        await _stopRecording();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isStarting = false;
        _isRecording = false;
        _isStopping = false;
        _stopAfterStart = false;
      });
      _showMessage('Kayıt başlatılırken bir sorun oluştu.');
    }
  }

  Future<void> _stopRecording() async {
    if (_isStarting) {
      _stopAfterStart = true;
      return;
    }

    if (!_isRecording || _isStopping) {
      return;
    }

    setState(() {
      _isStopping = true;
    });

    _ticker?.cancel();
    _stopwatch.stop();
    final roundedSeconds = double.parse(
      (_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1),
    );

    try {
      await _audioRecorder.stop();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecording = false;
        _isStopping = false;
      });
      _showMessage('Kayıt durdurulurken bir sorun oluştu.');
      return;
    }

    if (!mounted) {
      return;
    }

    final attempt = _PhonationAttempt(seconds: roundedSeconds);
    final isNewBest = roundedSeconds > _bestSeconds;

    setState(() {
      _isRecording = false;
      _isStopping = false;
      _elapsedSeconds = roundedSeconds;
      _attempts.add(attempt);
      if (isNewBest) {
        _bestSeconds = roundedSeconds;
      }
    });

    if (roundedSeconds < 1) {
      _showMessage('Kayıt çok kısa. Hazır olduğunuzda tekrar deneyin.');
    }
  }

  void _goToRecordingStep() {
    setState(() {
      _currentStep = _BreathControlStep.recording;
    });
  }

  Future<void> _goToDiaphragmStep() async {
    if (_isStarting || _isStopping) {
      _showMessage('Kayıt işlemi tamamlanınca geri dönebilirsin.');
      return;
    }

    if (_isRecording) {
      await _stopRecording();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentStep = _BreathControlStep.diaphragm;
    });
  }

  void _handleHeaderBack() {
    if (_currentStep == _BreathControlStep.recording) {
      unawaited(_goToDiaphragmStep());
      return;
    }
    Navigator.of(context).maybePop();
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
    _ticker?.cancel();
    _stopwatch.stop();
    if (_isRecording || _isStarting) {
      unawaited(_audioRecorder.stop());
    }
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _isStarting
        ? 'Kayıt hazırlanıyor...'
        : _isRecording
            ? 'Rahat tonda /a/ sesini sürdür, zorlanınca bırak.'
            : 'Hazır olduğunda butona basılı tut ve /a/ sesini uzat.';
    final lastSeconds = _attempts.isNotEmpty ? _attempts.last.seconds : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            AppTopHeader.withBack(
              title: 'Nefes Kontrolü',
              showDivider: true,
              onBackPressed: _handleHeaderBack,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_currentStep == _BreathControlStep.diaphragm) ...[
                      const _DiaphragmIntroCard(),
                      const SizedBox(height: 14),
                      const _DiaphragmGuideCard(),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _goToRecordingStep,
                        child: const Text('Kayıt aşamasına geç'),
                      ),
                    ] else ...[
                      const SizedBox(height: 14),
                      _RecordingCard(
                        elapsedSeconds: _elapsedSeconds,
                        statusText: statusText,
                        isStarting: _isStarting,
                        isRecording: _isRecording,
                        isStopping: _isStopping,
                        onPressStart: _startRecording,
                        onPressEnd: _stopRecording,
                      ),
                      const SizedBox(height: 14),
                      _RecordingSummaryCard(
                        bestSeconds: _bestSeconds,
                        lastSeconds: lastSeconds,
                      ),
                    ],
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

class _DiaphragmIntroCard extends StatelessWidget {
  const _DiaphragmIntroCard();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: CustomPaint(
            painter: _DiaphragmPainter(),
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 98),
                child: Text(
                  'Karın bir balon gibi genişler',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Diyafram nefesi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Nefes alırken göğüs yerine karın bölgenizin yumuşakça genişlemesine izin verin. Nefesi verirken karın içeri döner ve sesinizi bu destekle taşırsınız.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _DiaphragmGuideCard extends StatelessWidget {
  const _DiaphragmGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.cardBorder.withValues(alpha: 0.65),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuideHeader(),
          SizedBox(height: 12),
          _GuideBullet(text: 'Omuzlarını kaldırma'),
          SizedBox(height: 10),
          _GuideBullet(
            text:
                'Burnundan yavaşça derin nefes al, karnının yumuşakça genişlemesine izin ver. Nefesi verirken karnının içeri dönmesine izin ver.',
          ),
        ],
      ),
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          color: AppTheme.primary,
          size: 24,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Karın nefesi kullan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideBullet extends StatelessWidget {
  const _GuideBullet({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({
    required this.elapsedSeconds,
    required this.statusText,
    required this.isStarting,
    required this.isRecording,
    required this.isStopping,
    required this.onPressStart,
    required this.onPressEnd,
  });

  final double elapsedSeconds;
  final String statusText;
  final bool isStarting;
  final bool isRecording;
  final bool isStopping;
  final Future<void> Function() onPressStart;
  final Future<void> Function() onPressEnd;

  @override
  Widget build(BuildContext context) {
    final canPress = !isStopping;
    final currentLabel = _formatSeconds(elapsedSeconds);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          const Text(
            '/a/',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isRecording || elapsedSeconds > 0) ...[
            const SizedBox(height: 14),
            Text(
              'Anlık süre: $currentLabel',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 20),
          GestureDetector(
            onTapDown: canPress ? (_) => onPressStart() : null,
            onTapUp: canPress ? (_) => onPressEnd() : null,
            onTapCancel: canPress ? () => onPressEnd() : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording ? const Color(0xFFCF5A5A) : AppTheme.card,
                border: Border.all(
                  color: isRecording
                      ? const Color(0xFFCF5A5A)
                      : AppTheme.homeAccent,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24163B55),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                color: isRecording ? Colors.white : AppTheme.homeAccent,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isRecording
                ? 'Kaydı Durdur'
                : isStarting
                    ? 'Mikrofon hazırlanıyor'
                    : 'Kaydı Başlat',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingSummaryCard extends StatelessWidget {
  const _RecordingSummaryCard({
    required this.bestSeconds,
    required this.lastSeconds,
  });

  final double bestSeconds;
  final double lastSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              label: 'En iyi:',
              value: _formatSeconds(bestSeconds),
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: AppTheme.cardBorder,
          ),
          Expanded(
            child: _SummaryMetric(
              label: 'Son:',
              value: _formatSeconds(lastSeconds),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _PhonationAttempt {
  const _PhonationAttempt({
    required this.seconds,
  });

  final double seconds;
}

class _DiaphragmPainter extends CustomPainter {
  const _DiaphragmPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final skinPaint = Paint()..color = const Color(0xFFEAF1EC);
    final outlinePaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final lungPaint = Paint()..color = const Color(0xFFCFE2D6);
    final bellyPaint = Paint()..color = const Color(0xFFF2D8CE);
    final diaphragmPaint = Paint()
      ..color = AppTheme.terracotta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final arrowPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final torsoPath = Path()
      ..moveTo(centerX - 54, 28)
      ..quadraticBezierTo(centerX - 88, 82, centerX - 72, 170)
      ..quadraticBezierTo(centerX, 206, centerX + 72, 170)
      ..quadraticBezierTo(centerX + 88, 82, centerX + 54, 28)
      ..close();

    canvas.drawPath(torsoPath, skinPaint);
    canvas.drawPath(torsoPath, outlinePaint);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX - 24, 82),
        width: 40,
        height: 72,
      ),
      lungPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX + 24, 82),
        width: 40,
        height: 72,
      ),
      lungPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, 150),
        width: 118,
        height: 72,
      ),
      bellyPaint,
    );

    final diaphragmPath = Path()
      ..moveTo(centerX - 62, 118)
      ..quadraticBezierTo(centerX, 148, centerX + 62, 118);
    canvas.drawPath(diaphragmPath, diaphragmPaint);

    final arrowPath = Path()
      ..moveTo(centerX - 104, 76)
      ..lineTo(centerX - 104, 136)
      ..moveTo(centerX - 116, 124)
      ..lineTo(centerX - 104, 138)
      ..lineTo(centerX - 92, 124)
      ..moveTo(centerX + 104, 76)
      ..lineTo(centerX + 104, 136)
      ..moveTo(centerX + 92, 124)
      ..lineTo(centerX + 104, 138)
      ..lineTo(centerX + 116, 124);
    canvas.drawPath(arrowPath, arrowPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Diyafram',
        style: TextStyle(
          color: AppTheme.terracotta,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(centerX - textPainter.width / 2, 108),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatSeconds(double seconds) => '${seconds.toStringAsFixed(1)} sn';
