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
import '../widgets/sz_test_record_card.dart';

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
  SzTestRecord? _latestRecord;
  SzTestRecord? _completedRecord;

  _SzStep get _currentStep => _steps[_currentStepIndex];
  bool get _showResult => _completedRecord != null;

  @override
  void initState() {
    super.initState();
    _loadLatestRecord();
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

  Future<void> _loadLatestRecord() async {
    final latestRecord = await _repository.fetchLatestRecord();
    if (!mounted) {
      return;
    }

    setState(() {
      _latestRecord = latestRecord;
      _isLoading = false;
    });
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
        _latestRecord = savedRecord;
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

  void _restartTest() {
    setState(() {
      _currentStepIndex = 0;
      _isRecording = false;
      _elapsedSeconds = 0;
      _sAttempts = <double>[];
      _zAttempts = <double>[];
      _completedRecord = null;
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
            const AppTopHeader.withBack(title: 'S/Z Oranı Testi'),
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
                                sAttempts: _sAttempts,
                                zAttempts: _zAttempts,
                                onRestart: _restartTest,
                              )
                            : _SessionView(
                                key: const ValueKey<String>('session'),
                                currentStep: _currentStep,
                                currentStepIndex: _currentStepIndex,
                                totalSteps: _steps.length,
                                isRecording: _isRecording,
                                isSaving: _isSaving,
                                elapsedSeconds: _elapsedSeconds,
                                sAttempts: _sAttempts,
                                zAttempts: _zAttempts,
                                latestRecord: _latestRecord,
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
    required this.currentStepIndex,
    required this.totalSteps,
    required this.isRecording,
    required this.isSaving,
    required this.elapsedSeconds,
    required this.sAttempts,
    required this.zAttempts,
    required this.latestRecord,
    required this.onPrimaryPressed,
    super.key,
  });

  final _SzStep currentStep;
  final int currentStepIndex;
  final int totalSteps;
  final bool isRecording;
  final bool isSaving;
  final double elapsedSeconds;
  final List<double> sAttempts;
  final List<double> zAttempts;
  final SzTestRecord? latestRecord;
  final VoidCallback onPrimaryPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _InfoCard(),
        const SizedBox(height: 14),
        _ProgressCard(
          currentStepIndex: currentStepIndex,
          totalSteps: totalSteps,
          currentStep: currentStep,
        ),
        const SizedBox(height: 14),
        _ActiveStepCard(
          currentStep: currentStep,
          elapsedSeconds: elapsedSeconds,
          isRecording: isRecording,
          isSaving: isSaving,
          onPrimaryPressed: onPrimaryPressed,
        ),
        const SizedBox(height: 14),
        _AttemptsCard(
          sAttempts: sAttempts,
          zAttempts: zAttempts,
        ),
        if (latestRecord != null) ...[
          const SizedBox(height: 14),
          SzTestRecordCard(
            title: 'Son Kayıt',
            record: latestRecord!,
          ),
        ],
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.record,
    required this.sAttempts,
    required this.zAttempts,
    required this.onRestart,
    super.key,
  });

  final SzTestRecord record;
  final List<double> sAttempts;
  final List<double> zAttempts;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SzTestRecordCard(
          title: 'Test Sonucu',
          record: record,
          showNote: true,
          showTime: true,
        ),
        const SizedBox(height: 14),
        _AttemptsCard(
          title: 'Deneme Detayları',
          sAttempts: sAttempts,
          zAttempts: zAttempts,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onRestart,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.darkBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Yeni Test Başlat',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E1E8)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test Akışı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkBlue,
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
            style:
                TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF344254)),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.currentStepIndex,
    required this.totalSteps,
    required this.currentStep,
  });

  final int currentStepIndex;
  final int totalSteps;
  final _SzStep currentStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adım ${currentStepIndex + 1} / $totalSteps',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF5F6E84),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(totalSteps, (index) {
              final isCompleted = index < currentStepIndex;
              final isActive = index == currentStepIndex;

              return Expanded(
                child: Container(
                  height: 10,
                  margin:
                      EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: isCompleted || isActive
                        ? AppTheme.darkBlue
                        : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            currentStep.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 132,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              currentStep.letter,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkBlue,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            currentStep.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF536274),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            formatSzSeconds(elapsedSeconds),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: isSaving ? null : onPrimaryPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isRecording ? const Color(0xFFCF5A5A) : AppTheme.darkBlue,
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
                size: 54,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isSaving
                ? 'Sonuç kaydediliyor...'
                : isRecording
                    ? 'Kaydı Durdur'
                    : 'Kaydı Başlat',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttemptsCard extends StatelessWidget {
  const _AttemptsCard({
    required this.sAttempts,
    required this.zAttempts,
    this.title = 'Alınan Denemeler',
  });

  final String title;
  final List<double> sAttempts;
  final List<double> zAttempts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkBlue,
            ),
          ),
          const SizedBox(height: 12),
          _AttemptLine(
            label: 'S',
            attempts: sAttempts,
          ),
          const SizedBox(height: 10),
          _AttemptLine(
            label: 'Z',
            attempts: zAttempts,
          ),
        ],
      ),
    );
  }
}

class _AttemptLine extends StatelessWidget {
  const _AttemptLine({
    required this.label,
    required this.attempts,
  });

  final String label;
  final List<double> attempts;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attempts.isEmpty
                ? const [
                    _AttemptChip(label: 'Henüz kayıt yok'),
                  ]
                : List<Widget>.generate(
                    attempts.length,
                    (index) => _AttemptChip(
                      label:
                          '${index + 1}. deneme • ${formatSzSeconds(attempts[index])}',
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _AttemptChip extends StatelessWidget {
  const _AttemptChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
        ),
      ),
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
