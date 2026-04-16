import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';

enum _VoiceStep { a, i }

class VoiceAnalyzeScreen extends StatefulWidget {
  const VoiceAnalyzeScreen({super.key});

  @override
  State<VoiceAnalyzeScreen> createState() => _VoiceAnalyzeScreenState();
}

class _VoiceAnalyzeScreenState extends State<VoiceAnalyzeScreen> {
  static const int _maxRecordSeconds = 5;
  static const double _minAcceptedSeconds = 1.0;
  static const double _minAcceptedRms = 0.003;
  static const double _minAcceptedPeak = 0.015;
  static const String _configuredBackendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

  static const Map<_VoiceStep, _StepMeta> _stepMeta = <_VoiceStep, _StepMeta>{
    _VoiceStep.a: _StepMeta(
      letter: 'A',
      apiFieldName: 'a_file',
      title: 'A sesi',
      instruction:
          'Normal konuşma tonunda, rahat ve kesintisiz şekilde "a" sesini 5 saniye uzatın.',
    ),
    _VoiceStep.i: _StepMeta(
      letter: 'İ',
      apiFieldName: 'i_file',
      title: 'İ sesi',
      instruction:
          'Ardından yine normal konuşma tonunda, rahat ve kesintisiz şekilde "i" sesini 5 saniye uzatın.',
    ),
  };

  final AudioRecorder _audioRecorder = AudioRecorder();
  final Map<_VoiceStep, String> _recordedPaths = <_VoiceStep, String>{};

  _VoiceStep _selectedStep = _VoiceStep.a;
  bool _isRecording = false;
  bool _isSending = false;
  int _remainingSeconds = _maxRecordSeconds;
  Timer? _countdownTimer;
  String? _errorText;

  String get _backendBaseUrl {
    if (_configuredBackendBaseUrl.isNotEmpty) {
      return _configuredBackendBaseUrl;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  _StepMeta get _currentMeta => _stepMeta[_selectedStep]!;

  bool get _hasARecording => _recordedPaths.containsKey(_VoiceStep.a);
  bool get _hasIRecording => _recordedPaths.containsKey(_VoiceStep.i);
  bool get _isReadyToAnalyze => _hasARecording && _hasIRecording;

  String get _statusLabel {
    if (_isSending) {
      return 'Kayıtlar analiz ediliyor...';
    }
    if (_isRecording) {
      return '${_currentMeta.title} kaydediliyor: $_remainingSeconds sn';
    }
    if (_isReadyToAnalyze) {
      return 'İki kayıt hazır. Ön taramayı başlatabilirsiniz.';
    }
    if (_hasARecording && !_hasIRecording) {
      return 'A kaydı tamamlandı. Şimdi İ sesini kaydedin.';
    }
    return 'Önce A sesini kaydedin.';
  }

  Future<void> _selectStep(_VoiceStep step) async {
    if (_isRecording || _isSending) {
      return;
    }
    if (step == _VoiceStep.i && !_hasARecording) {
      return;
    }
    setState(() {
      _selectedStep = step;
    });
  }

  Future<void> _onMicPressed() async {
    if (_isSending) {
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
      setState(() {
        _errorText = 'Mikrofon izni verilmedi.';
      });
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/${_currentMeta.apiFieldName}_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
      path: path,
    );

    _countdownTimer?.cancel();

    setState(() {
      _isRecording = true;
      _remainingSeconds = _maxRecordSeconds;
      _errorText = null;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        await _stopRecording();
        return;
      }

      if (mounted) {
        setState(() {
          _remainingSeconds -= 1;
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    _countdownTimer?.cancel();
    final path = await _audioRecorder.stop();
    final recordedStep = _selectedStep;

    if (!mounted) {
      return;
    }

    if (path != null) {
      final validationError = await _validateRecordedAudio(
        path,
        _stepMeta[recordedStep]!.title,
      );
      if (validationError != null) {
        try {
          await File(path).delete();
        } catch (_) {}

        setState(() {
          _isRecording = false;
          _remainingSeconds = _maxRecordSeconds;
          _recordedPaths.remove(recordedStep);
          _errorText = validationError;
        });
        return;
      }
    }

    setState(() {
      _isRecording = false;
      _remainingSeconds = _maxRecordSeconds;
      if (path != null) {
        _recordedPaths[recordedStep] = path;
      }
      _errorText = null;
      if (recordedStep == _VoiceStep.a && !_hasIRecording) {
        _selectedStep = _VoiceStep.i;
      }
    });
  }

  Future<String?> _validateRecordedAudio(String path, String stepTitle) async {
    try {
      final bytes = await File(path).readAsBytes();
      final metrics = _extractWavMetrics(bytes);
      if (metrics == null) {
        return null;
      }

      if (metrics.durationSec < _minAcceptedSeconds ||
          metrics.rms < _minAcceptedRms ||
          metrics.peak < _minAcceptedPeak) {
        return '$stepTitle kaydında yeterli ses algılanmadı. Lütfen sesi normal konuşma tonunda tekrar kaydedin.';
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  _WavMetrics? _extractWavMetrics(Uint8List bytes) {
    if (bytes.length < 44) {
      return null;
    }

    final data = ByteData.sublistView(bytes);
    final riff = String.fromCharCodes(bytes.sublist(0, 4), 0, 4).toUpperCase();
    final wave = String.fromCharCodes(bytes.sublist(8, 12), 0, 4).toUpperCase();
    if (riff != 'RIFF' || wave != 'WAVE') {
      return null;
    }

    var offset = 12;
    var sampleRate = 0;
    var channels = 0;
    var bitsPerSample = 0;
    var dataOffset = -1;
    var dataLength = 0;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(
        bytes.sublist(offset, offset + 4),
        0,
        4,
      );
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      final chunkDataStart = offset + 8;
      final chunkDataEnd = chunkDataStart + chunkSize;
      if (chunkDataEnd > bytes.length) {
        break;
      }

      if (chunkId == 'fmt ') {
        channels = data.getUint16(chunkDataStart + 2, Endian.little);
        sampleRate = data.getUint32(chunkDataStart + 4, Endian.little);
        bitsPerSample = data.getUint16(chunkDataStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = chunkDataStart;
        dataLength = chunkSize;
        break;
      }

      offset = chunkDataEnd + (chunkSize.isOdd ? 1 : 0);
    }

    if (dataOffset < 0 ||
        dataLength <= 0 ||
        sampleRate <= 0 ||
        channels <= 0 ||
        bitsPerSample != 16) {
      return null;
    }

    final sampleCount = dataLength ~/ 2;
    if (sampleCount <= 0) {
      return null;
    }

    var sumSquares = 0.0;
    var peak = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final sample = data.getInt16(dataOffset + (i * 2), Endian.little);
      final normalized = sample / 32768.0;
      final absolute = normalized.abs();
      sumSquares += normalized * normalized;
      if (absolute > peak) {
        peak = absolute;
      }
    }

    final durationSec = sampleCount / channels / sampleRate;
    final rms = math.sqrt(sumSquares / sampleCount);
    return _WavMetrics(durationSec: durationSec, rms: rms, peak: peak);
  }

  Future<void> _sendToBackend() async {
    final aPath = _recordedPaths[_VoiceStep.a];
    final iPath = _recordedPaths[_VoiceStep.i];
    if (aPath == null || iPath == null) {
      setState(() {
        _errorText = 'Analiz için hem A hem de İ kaydı gereklidir.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorText = null;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendBaseUrl/analyze-voice-screening'),
      );

      request.files.add(await http.MultipartFile.fromPath('a_file', aPath));
      request.files.add(await http.MultipartFile.fromPath('i_file', iPath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final result = _ScreeningViewModel.fromJson(
          body['screening'] as Map<String, dynamic>,
        );
        setState(() {
          _errorText = null;
        });
        if (!mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _VoiceAnalyzeResultScreen(result: result),
          ),
        );
      } else {
        setState(() {
          _errorText = body['detail']?.toString() ??
              'Analiz sırasında beklenmeyen bir hata oluştu.';
        });
      }
    } catch (error) {
      setState(() {
        _errorText = 'Bağlantı hatası: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canRecord = !_isSending;
    final micLabel = _recordedPaths.containsKey(_selectedStep)
        ? '${_currentMeta.title} kaydını yenile'
        : '${_currentMeta.title} kaydını al';

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
              title: 'Ses Sağlığı Ön Tarama Testi',
              showDivider: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.cardBorder),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoBadge(label: '2 ADIMLI KAYIT'),
                        SizedBox(height: 10),
                        Text(
                          'Modelin çalışabilmesi için kullanıcıdan hem "A" hem de "İ" sesi alınır.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Lütfen her iki sesi de normal konuşma tonunda, rahat ve sabit biçimde 5 saniye boyunca uzatın.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StepCard(
                    title: _stepMeta[_VoiceStep.a]!.title,
                    letter: _stepMeta[_VoiceStep.a]!.letter,
                    isSelected: _selectedStep == _VoiceStep.a,
                    isCompleted: _hasARecording,
                    onTap: () => _selectStep(_VoiceStep.a),
                  ),
                  const SizedBox(height: 10),
                  _StepCard(
                    title: _stepMeta[_VoiceStep.i]!.title,
                    letter: _stepMeta[_VoiceStep.i]!.letter,
                    isSelected: _selectedStep == _VoiceStep.i,
                    isCompleted: _hasIRecording,
                    onTap: () => _selectStep(_VoiceStep.i),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 132,
                          height: 92,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Text(
                            _currentMeta.letter,
                            style: TextStyle(
                              fontSize: _currentMeta.letter == 'İ' ? 28 : 32,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentMeta.instruction,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        GestureDetector(
                          onTap: canRecord ? _onMicPressed : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording
                                  ? const Color(0xFFCF5A5A)
                                  : AppTheme.card,
                              border: Border.all(
                                color: _isRecording
                                    ? const Color(0xFFCF5A5A)
                                    : AppTheme.homeAccent
                                        .withValues(alpha: canRecord ? 1 : 0.45),
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
                              _isRecording
                                  ? Icons.stop_rounded
                                  : Icons.mic_none_rounded,
                              size: 44,
                              color: _isRecording
                                  ? Colors.white
                                  : AppTheme.homeAccent
                                      .withValues(alpha: canRecord ? 1 : 0.45),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _isRecording ? 'Kaydı Durdur' : micLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _statusLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isReadyToAnalyze &&
                                    !_isRecording &&
                                    !_isSending
                                ? _sendToBackend
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.homeIconBackground,
                              foregroundColor: AppTheme.homeAccent,
                            ),
                            icon: const Icon(Icons.analytics_outlined),
                            label: const Text('Ön Taramayı Başlat'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4F1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFF4C7B8)),
                      ),
                      child: Text(
                        _errorText!,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Color(0xFF7A2E18),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const _BottomReminder(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepMeta {
  const _StepMeta({
    required this.letter,
    required this.apiFieldName,
    required this.title,
    required this.instruction,
  });

  final String letter;
  final String apiFieldName;
  final String title;
  final String instruction;
}

class _WavMetrics {
  const _WavMetrics({
    required this.durationSec,
    required this.rms,
    required this.peak,
  });

  final double durationSec;
  final double rms;
  final double peak;
}

class _ScreeningViewModel {
  const _ScreeningViewModel({
    required this.label,
    required this.title,
    required this.summary,
    required this.recommendation,
    required this.confidencePercent,
  });

  factory _ScreeningViewModel.fromJson(Map<String, dynamic> json) {
    return _ScreeningViewModel(
      label: json['label']?.toString() ?? 'healthy',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      recommendation: json['recommendation']?.toString() ?? '',
      confidencePercent: (json['confidence_percent'] as num?)?.toDouble() ?? 0,
    );
  }

  final String label;
  final String title;
  final String summary;
  final String recommendation;
  final double confidencePercent;

  bool get isHealthy => label == 'healthy';
  bool get isRetakeRequired => label == 'retake_required';
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.letter,
    required this.isSelected,
    required this.isCompleted,
    required this.onTap,
  });

  final String title;
  final String letter;
  final bool isSelected;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? AppTheme.primary : AppTheme.cardBorder;
    final backgroundColor = isSelected ? AppTheme.soft : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Text(
                  letter,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.soft
                      : AppTheme.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Text(
                  isCompleted ? 'Hazır' : 'Bekliyor',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? AppTheme.primary : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final _ScreeningViewModel result;

  @override
  Widget build(BuildContext context) {
    final accent = result.isHealthy
        ? AppTheme.primary
        : result.isRetakeRequired
            ? const Color(0xFF7A5A12)
            : const Color(0xFF9C5E16);
    final background = result.isHealthy
        ? const Color(0xFFF5FAF7)
        : result.isRetakeRequired
            ? const Color(0xFFFFFCF2)
            : const Color(0xFFFFFAF2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: result.isHealthy
              ? AppTheme.cardBorder
              : result.isRetakeRequired
                  ? const Color(0xFFE8D7A8)
                  : const Color(0xFFF1D2A9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Icon(
                  result.isHealthy
                      ? Icons.verified_outlined
                      : result.isRetakeRequired
                          ? Icons.refresh_rounded
                          : Icons.medical_information_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.summary,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.recommendation,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Model güveni: %${result.confidencePercent.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceAnalyzeResultScreen extends StatelessWidget {
  const _VoiceAnalyzeResultScreen({required this.result});

  final _ScreeningViewModel result;

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
            const AppTopHeader.withBack(title: 'Ön Tarama Sonucu'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ResultCard(result: result),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: const Text(
                        'Bu sonuç yalnızca ön tarama amaçlıdır. Klinik değerlendirme ve kesin tanı için şikayetleriniz devam ediyorsa bir Kulak Burun Boğaz uzmanına başvurmanız önerilir.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.homeIconBackground,
                        foregroundColor: AppTheme.homeAccent,
                      ),
                      child: const Text('Kayıt Ekranına Dön'),
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

class _BottomReminder extends StatelessWidget {
  const _BottomReminder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFED7BC)),
        color: const Color(0xFFFFF9F4),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.priority_high_rounded,
            color: Color(0xFFF25C05),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Her kayıt 5 saniye sonra otomatik durur. Daha tutarlı sonuç için sessiz bir ortamda, telefonu ağzınıza çok yaklaştırmadan kayıt alın.',
              style: TextStyle(
                color: Color(0xFF1C1C1E),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
