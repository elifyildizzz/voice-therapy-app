import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/measurement_record.dart';
import '../services/measurement_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';

const Color _authButtonColor = AppTheme.buttonPrimary;

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
  static const String _exerciseKey = 'maximum_a_phonation';

  final AudioRecorder _audioRecorder = AudioRecorder();
  final MeasurementRepository _repository = MeasurementRepository.instance;
  final Stopwatch _stopwatch = Stopwatch();

  Timer? _ticker;
  bool _isStarting = false;
  bool _isRecording = false;
  bool _isStopping = false;
  bool _stopAfterStart = false;
  bool _hasUnsavedMeasurement = false;
  bool _isLoadingSavedRecords = true;
  bool _isSavingMeasurement = false;
  double _elapsedSeconds = 0;
  double _bestSeconds = 0;
  _BreathControlStep _currentStep = _BreathControlStep.diaphragm;
  final List<_PhonationAttempt> _attempts = <_PhonationAttempt>[];
  List<MeasurementRecord> _savedRecords = const <MeasurementRecord>[];

  @override
  void initState() {
    super.initState();
    final cachedRecords = _repository.peekRecords();
    if (_repository.hasLoadedCache) {
      _savedRecords = _todayBreathRecords(cachedRecords);
      _bestSeconds = _bestBreathSeconds(cachedRecords);
      _isLoadingSavedRecords = false;
    } else {
      unawaited(_loadSavedRecords());
    }
  }

  Future<void> _loadSavedRecords() async {
    try {
      final records = await _repository.fetchRecords();
      if (!mounted) {
        return;
      }
      setState(() {
        _savedRecords = _todayBreathRecords(records);
        _bestSeconds = _bestBreathSeconds(records);
        _isLoadingSavedRecords = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingSavedRecords = false;
      });
      _showMessage('Ölçüm kayıtları yüklenemedi.');
    }
  }

  List<MeasurementRecord> _todayBreathRecords(List<MeasurementRecord> records) {
    final today = _formatClientDate(DateTime.now());
    final filtered = records
        .where(
          (record) =>
              record.clientDate == today &&
              record.module == MeasurementRepository.breathControlModule &&
              record.exerciseKey == _exerciseKey,
        )
        .toList(growable: true)
      ..sort((left, right) => left.performedAt.compareTo(right.performedAt));
    return List<MeasurementRecord>.unmodifiable(filtered);
  }

  double _bestBreathSeconds(List<MeasurementRecord> records) {
    var bestMilliseconds = 0;
    for (final record in records) {
      if (record.module != MeasurementRepository.breathControlModule ||
          record.exerciseKey != _exerciseKey) {
        continue;
      }
      if (record.duration.inMilliseconds > bestMilliseconds) {
        bestMilliseconds = record.duration.inMilliseconds;
      }
    }
    return bestMilliseconds / 1000;
  }

  String _formatClientDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

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
        _hasUnsavedMeasurement = false;
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
      _hasUnsavedMeasurement = roundedSeconds > 0;
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

  void _resetMeasurement() {
    if (_isRecording || _isStarting || _isStopping || _isSavingMeasurement) {
      return;
    }

    _clearMeasurementState();
  }

  void _clearMeasurementState() {
    setState(() {
      _elapsedSeconds = 0;
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

    final duration = Duration(milliseconds: (_elapsedSeconds * 1000).round());
    try {
      final slot = await _repository.saveRecord(
        module: MeasurementRepository.breathControlModule,
        exerciseKey: _exerciseKey,
        exerciseTitle: 'Maximum /a/ Fonasyonu',
        duration: duration,
      );
      await _loadSavedRecords();
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
    final canSave = !_isRecording &&
        !_isStarting &&
        !_isStopping &&
        !_isSavingMeasurement &&
        _hasUnsavedMeasurement &&
        _elapsedSeconds > 0;

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
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_currentStep == _BreathControlStep.diaphragm) ...[
                      const _DiaphragmInfoSection(),
                      const SizedBox(height: 14),
                      _DiaphragmHowToCard(
                        onPressed: _goToRecordingStep,
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
                      const SizedBox(height: 14),
                      _DailyBreathRecordsCard(
                        records: _savedRecords,
                        isLoading: _isLoadingSavedRecords,
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
                                onPressed: _isSavingMeasurement
                                    ? null
                                    : _resetMeasurement,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.textPrimary,
                                  side: const BorderSide(
                                    color: Color(0xFFECE7E0),
                                  ),
                                  backgroundColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
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
                                    : AppTheme.buttonPrimary.withValues(
                                        alpha: 0.45,
                                      ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
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

class _DiaphragmInfoSection extends StatelessWidget {
  const _DiaphragmInfoSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DiaphragmIllustration(),
        SizedBox(height: 0),
        Text(
          'Diyafram nefesi nedir?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Diyafram nefesi, sesi destekleyen temel nefes tekniğidir. Doğru uygulandığında sesin daha güçlü, kontrollü ve yorulmadan çıkmasını sağlar.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _DiaphragmHowToCard extends StatelessWidget {
  const _DiaphragmHowToCard({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _InstructionCheckIcon(),
                  SizedBox(width: 8),
                  Text(
                    'Nasıl yapılır?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _GuideSteps(),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _authButtonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 13,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            child: const Text(
              'Kayıt aşamasına geç',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppTheme.homeAccent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.32,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideSteps extends StatelessWidget {
  const _GuideSteps();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GuideStep(
          title: 'Elini Yerleştir',
          description: 'Bir elini göğsüne, diğerini karnına koy.',
        ),
        SizedBox(height: 10),
        _GuideStep(
          title: 'Karnını Şişir',
          description:
              'Burnundan nefes alırken sadece karnındaki elin dışarı hareket etsin.',
        ),
        SizedBox(height: 10),
        _GuideStep(
          title: 'Yavaşça Bırak',
          description: 'Nefesini verirken karnının içeri çekildiğini hisset.',
        ),
        SizedBox(height: 10),
        _GuideStep(
          title: 'Kontrol Et',
          description:
              'Omuzların sabit mi? Cevabın evet ise harika gidiyorsun.',
        ),
      ],
    );
  }
}

class _DiaphragmIllustration extends StatelessWidget {
  const _DiaphragmIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 238,
      width: double.infinity,
      child: Align(
        alignment: Alignment.topCenter,
        child: Image.asset(
          'assets/branding/diyafram_nefesi.png',
          width: 305,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _InstructionCheckIcon extends StatelessWidget {
  const _InstructionCheckIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: AppTheme.homeAccent,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 13,
      ),
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
    final accentColor =
        isRecording ? const Color(0xFFCF5A5A) : AppTheme.brandGreen;
    final micBackgroundColor =
        isRecording ? const Color(0xFFFFF1F1) : const Color(0xFFF8FBF8);

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
              color: AppTheme.textPrimary,
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

class _DailyBreathRecordsCard extends StatelessWidget {
  const _DailyBreathRecordsCard({
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
            _BreathMeasurementRow(
              label: '1. Ölçüm',
              duration: first,
            ),
            const SizedBox(height: 8),
            _BreathMeasurementRow(
              label: '2. Ölçüm',
              duration: second,
            ),
          ],
        ],
      ),
    );
  }
}

class _BreathMeasurementRow extends StatelessWidget {
  const _BreathMeasurementRow({
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
          duration != null ? _formatBreathDuration(duration!) : '-',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

String _formatSeconds(double seconds) => '${seconds.toStringAsFixed(1)} sn';

String _formatBreathDuration(Duration duration) {
  final totalSeconds = duration.inMilliseconds / 1000;
  return '${totalSeconds.toStringAsFixed(1)} sn';
}
