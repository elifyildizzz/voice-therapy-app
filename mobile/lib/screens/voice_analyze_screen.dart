import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';

class VoiceAnalyzeScreen extends StatefulWidget {
  const VoiceAnalyzeScreen({super.key});

  @override
  State<VoiceAnalyzeScreen> createState() => _VoiceAnalyzeScreenState();
}

class _VoiceAnalyzeScreenState extends State<VoiceAnalyzeScreen> {
  static const String _initialResult = 'Henüz analiz yapılmadı.';
  static const int _maxRecordSeconds = 5;
  static const String _configuredBackendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

  final AudioRecorder _audioRecorder = AudioRecorder();

  String? _recordedPath;
  String _resultText = _initialResult;
  bool _isRecording = false;
  bool _isSending = false;
  int _remainingSeconds = _maxRecordSeconds;
  Timer? _countdownTimer;

  String get _backendBaseUrl {
    if (_configuredBackendBaseUrl.isNotEmpty) {
      return _configuredBackendBaseUrl;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  String get _statusLabel {
    if (_isSending) {
      return 'Analiz yapılıyor...';
    }
    if (_isRecording) {
      return 'Kayıt alınıyor: $_remainingSeconds sn';
    }
    if (_recordedPath != null) {
      return 'Kayıt tamamlandı';
    }
    return 'Mikrofona basarak kaydı başlatın';
  }

  bool get _showResultCard => _resultText != _initialResult;

  Future<void> _onMicPressed() async {
    if (_isSending) {
      return;
    }

    if (_isRecording) {
      await _stopRecording();
      if (mounted) {
        await _sendToBackend();
      }
      return;
    }

    await _startRecording();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      setState(() {
        _resultText = 'Mikrofon izni verilmedi.';
      });
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      ),
      path: path,
    );

    _countdownTimer?.cancel();

    setState(() {
      _isRecording = true;
      _recordedPath = path;
      _remainingSeconds = _maxRecordSeconds;
      _resultText = 'Kayıt başlatıldı.';
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        await _stopRecording();
        if (mounted) {
          await _sendToBackend();
        }
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

    if (!mounted) {
      return;
    }

    setState(() {
      _isRecording = false;
      _remainingSeconds = _maxRecordSeconds;
      if (path != null) {
        _recordedPath = path;
      }
    });
  }

  Future<void> _sendToBackend() async {
    if (_recordedPath == null) {
      setState(() {
        _resultText = 'Önce bir ses kaydı al.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _resultText = 'Analiz için gönderiliyor...';
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendBaseUrl/analyze-voice'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', _recordedPath!),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        setState(() {
          _resultText = const JsonEncoder.withIndent('  ').convert(body);
        });
      } else {
        setState(() {
          _resultText =
              'Hata (${response.statusCode}): ${response.body.isEmpty ? 'Bilinmeyen hata' : response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _resultText = 'İstek hatası: $e';
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            const AppTopHeader.withBack(title: 'Ses Sağlığı Ön Tarama Testi'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const Text(
                              'Lütfen \'a\' sesini normal ses yüksekliğinde, rahat bir şekilde 5 saniye boyunca uzatın.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF101012),
                                fontSize: 16,
                                height: 1.34,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: Container(
                                width: 152,
                                height: 96,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F1F1),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: const Color(0xFFE0E0E0)),
                                ),
                                child: const Text(
                                  'A',
                                  style: TextStyle(
                                    color: Color(0xFF141414),
                                    fontSize: 36,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Center(
                              child: Icon(
                                Icons.graphic_eq_rounded,
                                size: 72,
                                color: AppTheme.darkBlue,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Center(
                              child: Column(
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(
                                        begin: 1, end: _isRecording ? 1.08 : 1),
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOut,
                                    builder: (context, value, child) {
                                      return Transform.scale(
                                          scale: value, child: child);
                                    },
                                    child: GestureDetector(
                                      onTap: _onMicPressed,
                                      child: Container(
                                        width: 122,
                                        height: 122,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.darkBlue,
                                          border: Border.all(
                                            color: _isRecording
                                                ? const Color(0xFFF1B97A)
                                                : Colors.transparent,
                                            width: 6,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x2A163B55),
                                              blurRadius: 20,
                                              offset: Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.mic_none_rounded,
                                          size: 62,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _isRecording
                                        ? 'Kaydı Durdur'
                                        : 'Kaydı Başlat',
                                    style: const TextStyle(
                                      color: Color(0xFF18345A),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _statusLabel,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF5F6E84),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_showResultCard) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFD3DFE7)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Analiz Sonucu',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.darkBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SelectableText(
                                      _resultText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.35,
                                        color: Color(0xFF4F4F4F),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFED7BC)),
                        color: const Color(0xFFFFF9F4),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFF25C05),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.priority_high_rounded,
                              color: Color(0xFFF25C05),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Kayıt, başlatıldıktan 5 saniye sonra otomatik olarak duracaktır.',
                              style: TextStyle(
                                color: Color(0xFF1C1C1E),
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
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
