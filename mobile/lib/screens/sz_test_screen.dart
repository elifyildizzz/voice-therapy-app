import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/sz_test_record.dart';
import '../services/sz_test_repository.dart';
import '../theme/app_theme.dart';
import '../utils/sz_test_formatters.dart';
import '../widgets/app_top_header.dart';

class SzTestScreen extends StatefulWidget {
  const SzTestScreen({super.key});

  @override
  State<SzTestScreen> createState() => _SzTestScreenState();
}

class _SzTestScreenState extends State<SzTestScreen> {
  static const List<_SzStep> _steps = [
    _SzStep(letter: 'S', attempt: 1),
    _SzStep(letter: 'S', attempt: 2),
    _SzStep(letter: 'Z', attempt: 1),
    _SzStep(letter: 'Z', attempt: 2),
  ];

  final AudioRecorder _audioRecorder = AudioRecorder();
  final Stopwatch _stopwatch = Stopwatch();
  final SzTestRepository _repository = SzTestRepository.instance;

  Timer? _ticker;
  int _currentStepIndex = 0;
  bool _isRecording = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasShownIntroDialog = false;
  double _elapsedSeconds = 0;
  List<double> _sAttempts = <double>[];
  List<double> _zAttempts = <double>[];
  SzTestRecord? _completedRecord;

  _SzStep get _currentStep => _steps[_currentStepIndex];
  bool get _showResult => _completedRecord != null;

  @override
  void initState() {
    super.initState();
    _isLoading = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showIntroDialogIfNeeded();
    });
  }

  Future<void> _showIntroDialogIfNeeded() async {
    if (!mounted || _hasShownIntroDialog) {
      return;
    }

    _hasShownIntroDialog = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(
              color: AppTheme.darkBlue,
              width: 2,
            ),
          ),
          backgroundColor: AppTheme.card,
          title: const Text(
            'S/Z Testi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkBlue,
            ),
          ),
          content: const Text(
            '“S” ve “Z” seslerini tek nefeste ve mümkün olduğunca uzun çıkarın.\n'
            'Sessiz bir ortamda yapmanız önerilir.\n'
            'Sonuçlar ön değerlendirme amaçlıdır.',
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Color(0xFF344254),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.darkBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Anladım'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleRecording() async {
    if (_isSaving) {
      return;
    }

    if (_isRecording) {
      await _stopRecording();
      return;
    }

    await _startRecording();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _showMessage('Mikrofon izni verilmedi.');
      return;
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/sz_${_currentStep.letter.toLowerCase()}_${_currentStep.attempt}_${DateTime.now().millisecondsSinceEpoch}.m4a';

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

    setState(() {
      _isRecording = true;
      _elapsedSeconds = 0;
    });
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    _stopwatch.stop();

    try {
      await _audioRecorder.stop();
    } catch (_) {
      _showMessage('Kayıt durdurulurken bir sorun oluştu.');
      return;
    }

    final roundedSeconds = double.parse(
      (_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isRecording = false;
      _elapsedSeconds = roundedSeconds;
      if (_currentStep.letter == 'S') {
        _sAttempts = <double>[..._sAttempts, roundedSeconds];
      } else {
        _zAttempts = <double>[..._zAttempts, roundedSeconds];
      }
    });

    if (_currentStepIndex == _steps.length - 1) {
      await _saveCompletedTest();
      return;
    }

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || _showResult) {
        return;
      }

      setState(() {
        _currentStepIndex += 1;
        _elapsedSeconds = 0;
      });
    });
  }

  Future<void> _saveCompletedTest() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final savedRecord = await _repository.saveRecord(
        sAttempts: _sAttempts,
        zAttempts: _zAttempts,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _completedRecord = savedRecord;
      });
    } catch (_) {
      _showMessage('Sonuç kaydedilirken bir sorun oluştu.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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
    _ticker?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

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
              title: 'S/Z Oranı Testi',
              showDivider: true,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _showResult
                            ? _ResultView(
                                key: const ValueKey<String>('result'),
                                record: _completedRecord!,
                              )
                            : _SessionView(
                                key: const ValueKey<String>('session'),
                                currentStep: _currentStep,
                                isRecording: _isRecording,
                                isSaving: _isSaving,
                                elapsedSeconds: _elapsedSeconds,
                                sAttempts: _sAttempts,
                                zAttempts: _zAttempts,
                                onPrimaryPressed: _toggleRecording,
                              ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionView extends StatelessWidget {
  const _SessionView({
    required this.currentStep,
    required this.isRecording,
    required this.isSaving,
    required this.elapsedSeconds,
    required this.sAttempts,
    required this.zAttempts,
    required this.onPrimaryPressed,
    super.key,
  });

  final _SzStep currentStep;
  final bool isRecording;
  final bool isSaving;
  final double elapsedSeconds;
  final List<double> sAttempts;
  final List<double> zAttempts;
  final VoidCallback onPrimaryPressed;

  @override
  Widget build(BuildContext context) {
    return _UnifiedPanel(
      children: [
        const _InfoCard(),
        _RecordingProgressCard(
          currentStep: currentStep,
          sAttempts: sAttempts,
          zAttempts: zAttempts,
        ),
        _ActiveStepCard(
          currentStep: currentStep,
          elapsedSeconds: elapsedSeconds,
          isRecording: isRecording,
          isSaving: isSaving,
          onPrimaryPressed: onPrimaryPressed,
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.record,
    super.key,
  });

  final SzTestRecord record;

  @override
  Widget build(BuildContext context) {
    return _UnifiedPanel(
      children: [
        _ResultSummaryCard(record: record),
        _InformationCard(message: buildSzRatioNote(record.ratio)),
      ],
    );
  }
}

class _UnifiedPanel extends StatelessWidget {
  const _UnifiedPanel({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1) ...[
              const SizedBox(height: 18),
              const Divider(height: 1, color: AppTheme.cardBorder),
              const SizedBox(height: 18),
            ],
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Test Akışı',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Her ses için iki deneme alınır.',
          style: TextStyle(fontSize: 14, color: Color(0xFF344254)),
        ),
        SizedBox(height: 6),
        Text(
          'En uzun süre değerlendirmeye alınır.',
          style: TextStyle(fontSize: 14, color: Color(0xFF344254)),
        ),
        SizedBox(height: 6),
        Text(
          'S sesi için 2 kayıt, Z sesi için 2 kayıt alınır ve ardından oran hesaplanır.',
          style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF344254)),
        ),
      ],
    );
  }
}

class _RecordingProgressCard extends StatelessWidget {
  const _RecordingProgressCard({
    required this.currentStep,
    required this.sAttempts,
    required this.zAttempts,
  });

  final _SzStep currentStep;
  final List<double> sAttempts;
  final List<double> zAttempts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProgressRow(
          label: 'S sesi',
          completedCount: sAttempts.length,
          isActive: currentStep.letter == 'S',
          activeAttempt: currentStep.letter == 'S' ? currentStep.attempt : null,
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: AppTheme.cardBorder),
        const SizedBox(height: 14),
        _ProgressRow(
          label: 'Z sesi',
          completedCount: zAttempts.length,
          isActive: currentStep.letter == 'Z',
          activeAttempt: currentStep.letter == 'Z' ? currentStep.attempt : null,
        ),
      ],
    );
  }
}

class _ActiveStepCard extends StatelessWidget {
  const _ActiveStepCard({
    required this.currentStep,
    required this.elapsedSeconds,
    required this.isRecording,
    required this.isSaving,
    required this.onPrimaryPressed,
  });

  final _SzStep currentStep;
  final double elapsedSeconds;
  final bool isRecording;
  final bool isSaving;
  final VoidCallback onPrimaryPressed;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        isRecording ? const Color(0xFFCF5A5A) : AppTheme.brandGreen;
    final micBackgroundColor =
        isRecording ? const Color(0xFFFFF1F1) : const Color(0xFFF8FBF8);
    final statusText = isSaving
        ? 'Sonuç kaydediliyor...'
        : isRecording
            ? '${currentStep.letter} sesi kaydediliyor'
            : 'Önce ${currentStep.letter} sesini kaydedin.';

    return Column(
      children: [
        Text(
          currentStep.letter,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          currentStep.description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: isSaving ? null : onPrimaryPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 102,
            height: 102,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: micBackgroundColor,
              border: Border.all(
                color: accentColor,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F1B16),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
              color: accentColor,
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: elapsedSeconds > 0 || isRecording ? 1 : 0.6,
          child: Text(
            formatSzSeconds(elapsedSeconds),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: accentColor,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.completedCount,
    required this.isActive,
    this.activeAttempt,
  });

  final String label;
  final int completedCount;
  final bool isActive;
  final int? activeAttempt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (isActive && activeAttempt != null) ...[
                const SizedBox(height: 4),
                Text(
                  '$activeAttempt. deneme',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5F6E84),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        _AttemptDots(completedCount: completedCount),
      ],
    );
  }
}

class _AttemptDots extends StatelessWidget {
  const _AttemptDots({
    required this.completedCount,
  });

  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < 2; index++) ...[
          _AttemptDot(isFilled: index < completedCount),
          if (index < 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _AttemptDot extends StatelessWidget {
  const _AttemptDot({
    required this.isFilled,
  });

  final bool isFilled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled ? AppTheme.brandGreen : Colors.transparent,
        border: Border.all(
          color: isFilled ? AppTheme.brandGreen : const Color(0xFFD2D7DE),
          width: 1.8,
        ),
      ),
    );
  }
}

class _ResultSummaryCard extends StatelessWidget {
  const _ResultSummaryCard({
    required this.record,
  });

  final SzTestRecord record;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sonuç',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _ResultMetricRow(
          label: 'En uzun Z sesi',
          value: formatSzSeconds(record.zBest),
        ),
        const SizedBox(height: 10),
        _ResultMetricRow(
          label: 'En uzun S sesi',
          value: formatSzSeconds(record.sBest),
        ),
        const SizedBox(height: 10),
        _ResultMetricRow(
          label: 'S/Z oranı',
          value: record.ratio.toStringAsFixed(2),
        ),
      ],
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bilgilendirme',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkBlue,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF344254),
          ),
        ),
      ],
    );
  }
}

class _ResultMetricRow extends StatelessWidget {
  const _ResultMetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF5F6E84),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SzStep {
  const _SzStep({
    required this.letter,
    required this.attempt,
  });

  final String letter;
  final int attempt;

  String get title => '$letter sesi $attempt/2';

  String get description =>
      '"$letter" sesini tek nefeste ve mümkün olduğunca uzun çıkarın.';
}
