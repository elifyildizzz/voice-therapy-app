import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceAnalyzeScreen extends StatefulWidget {
  const VoiceAnalyzeScreen({super.key});

  @override
  State<VoiceAnalyzeScreen> createState() => _VoiceAnalyzeScreenState();
}

class _VoiceAnalyzeScreenState extends State<VoiceAnalyzeScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();

  String? _recordedPath;
  String _resultText = 'Henüz analiz yapılmadı.';
  bool _isRecording = false;
  bool _isSending = false;

  String get _backendBaseUrl {
    // Android emülatörde host makine localhost'u için 10.0.2.2 gerekir.
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    // macOS, iOS simülatör ve web için.
    return 'http://127.0.0.1:8000';
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
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      ),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _recordedPath = path;
      _resultText = 'Kayıt alınıyor...';
    });
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();

    setState(() {
      _isRecording = false;
      if (path != null) {
        _recordedPath = path;
        _resultText = 'Kayıt tamamlandı: $path';
      } else {
        _resultText = 'Kayıt durduruldu, dosya bulunamadı.';
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
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ses Analizi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isRecording ? null : _startRecording,
              child: const Text('Ses Kaydı Başlat'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : null,
              child: const Text('Ses Kaydı Durdur'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSending ? null : _sendToBackend,
              child: Text(_isSending ? 'Gönderiliyor...' : 'Backend’e Gönder'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sonuç',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(_resultText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
