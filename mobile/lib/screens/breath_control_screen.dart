import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';

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
  String? _bestRecordingPath;
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

    String? path;
    try {
      path = await _audioRecorder.stop();
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

    final attempt = _PhonationAttempt(
      seconds: roundedSeconds,
      recordedPath: path,
    );
    final isNewBest = roundedSeconds > _bestSeconds;

    setState(() {
      _isRecording = false;
      _isStopping = false;
      _elapsedSeconds = roundedSeconds;
      _attempts.add(attempt);
      if (isNewBest) {
        _bestSeconds = roundedSeconds;
        _bestRecordingPath = path;
      }
    });

    if (roundedSeconds < 1) {
      _showMessage('Kayıt çok kısa. Hazır olduğunuzda tekrar deneyin.');
    }
  }

  void _resetSession() {
    setState(() {
      _elapsedSeconds = 0;
      _bestSeconds = 0;
      _bestRecordingPath = null;
      _attempts.clear();
    });
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
            ? 'Sesinizi rahatça sürdürün, zorlanınca bırakın.'
            : 'Hazır olduğunuzda butona basılı tutun.';

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
              title: 'Nefes Kontrolü',
              showDivider: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _DiaphragmIntroCard(),
                    const SizedBox(height: 14),
                    const _InstructionCard(),
                    const SizedBox(height: 14),
                    _RecordingCard(
                      elapsedSeconds: _elapsedSeconds,
                      bestSeconds: _bestSeconds,
                      statusText: statusText,
                      isStarting: _isStarting,
                      isRecording: _isRecording,
                      isStopping: _isStopping,
                      onPressStart: _startRecording,
                      onPressEnd: _stopRecording,
                    ),
                    const SizedBox(height: 14),
                    _AttemptsCard(
                      attempts: _attempts,
                      bestSeconds: _bestSeconds,
                      bestRecordingPath: _bestRecordingPath,
                      onReset: _attempts.isEmpty ? null : _resetSession,
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

class _DiaphragmIntroCard extends StatelessWidget {
  const _DiaphragmIntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Diyafram nefesi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nefes alırken göğüs yerine karın bölgenizin yumuşakça genişlemesine izin verin. Nefesi verirken karın içeri döner ve sesinizi bu destekle taşırsınız.',
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _DiaphragmPainter(),
              child: const Center(
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
        ],
      ),
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
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E1E8)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Maksimum /a/ fonasyonu kaydı',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Dik oturun ve omuzlarınızı serbest bırakın. Karnınızın bir balon gibi şiştiğini hissederek derin bir diyafram nefesi alın. Hazır olduğunda butona bas ve '/a/' sesini en rahat tonda, kesintisiz olarak uzatabildiğin kadar uzat. Kendinizi zorlamayın; sesinizde titreme veya yorulma hissettiğiniz an butonu bırakın.",
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF344254),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({
    required this.elapsedSeconds,
    required this.bestSeconds,
    required this.statusText,
    required this.isStarting,
    required this.isRecording,
    required this.isStopping,
    required this.onPressStart,
    required this.onPressEnd,
  });

  final double elapsedSeconds;
  final double bestSeconds;
  final String statusText;
  final bool isStarting;
  final bool isRecording;
  final bool isStopping;
  final Future<void> Function() onPressStart;
  final Future<void> Function() onPressEnd;

  @override
  Widget build(BuildContext context) {
    final canPress = !isStopping;
    final currentLabel =
        isRecording ? _formatSeconds(elapsedSeconds) : _formatSeconds(0);

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
              fontSize: 42,
              fontWeight: FontWeight.w800,
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
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Anlık süre',
                  value: currentLabel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Maksimum',
                  value: _formatSeconds(bestSeconds),
                  highlight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTapDown: canPress ? (_) => onPressStart() : null,
            onTapUp: canPress ? (_) => onPressEnd() : null,
            onTapCancel: canPress ? () => onPressEnd() : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording
                    ? const Color(0xFFCF5A5A)
                    : isStarting
                        ? AppTheme.light
                        : AppTheme.primary,
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
                color: Colors.white,
                size: 56,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isRecording
                ? 'Bırakınca kayıt bitecek'
                : isStarting
                    ? 'Mikrofon hazırlanıyor'
                    : 'Basılı tutarak kaydet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.soft : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: highlight ? AppTheme.primary : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: highlight ? AppTheme.primary : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttemptsCard extends StatelessWidget {
  const _AttemptsCard({
    required this.attempts,
    required this.bestSeconds,
    required this.bestRecordingPath,
    required this.onReset,
  });

  final List<_PhonationAttempt> attempts;
  final double bestSeconds;
  final String? bestRecordingPath;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kayıt sonucu',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (onReset != null)
                TextButton(
                  onPressed: onReset,
                  child: const Text('Sıfırla'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            bestSeconds > 0
                ? 'Maksimum /a/ süreniz ${_formatSeconds(bestSeconds)}.'
                : 'Henüz /a/ kaydı alınmadı.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (bestRecordingPath != null) ...[
            const SizedBox(height: 8),
            const Text(
              'En uzun kayıt bu oturumda saklandı.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attempts.isEmpty
                ? const [
                    _AttemptChip(label: 'Henüz deneme yok'),
                  ]
                : List<Widget>.generate(
                    attempts.length,
                    (index) {
                      final seconds = attempts[index].seconds;
                      final isBest = seconds == bestSeconds && bestSeconds > 0;

                      return _AttemptChip(
                        label:
                            '${index + 1}. deneme • ${_formatSeconds(seconds)}${isBest ? ' • en uzun' : ''}',
                        isBest: isBest,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AttemptChip extends StatelessWidget {
  const _AttemptChip({
    required this.label,
    this.isBest = false,
  });

  final String label;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isBest ? AppTheme.soft : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: isBest ? AppTheme.primary : const Color(0xFF475569),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PhonationAttempt {
  const _PhonationAttempt({
    required this.seconds,
    required this.recordedPath,
  });

  final double seconds;
  final String? recordedPath;
}

class _DiaphragmPainter extends CustomPainter {
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
