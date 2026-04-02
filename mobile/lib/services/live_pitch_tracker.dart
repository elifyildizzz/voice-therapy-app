import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../models/pitch_reading.dart';

class PitchTrackerException implements Exception {
  const PitchTrackerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LivePitchTracker {
  LivePitchTracker({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder(),
        _hannWindow = List<double>.generate(
          _frameSize,
          (index) => 0.5 * (1 - cos((2 * pi * index) / (_frameSize - 1))),
        );

  static const int _sampleRate = 16000;
  static const int _frameSize = 2048;
  static const int _hopSize = 256;
  static const double _minFrequency = 60;
  static const double _maxFrequency = 500;
  static const double _rmsThreshold = 0.008;
  static const double _yinThreshold = 0.18;
  static const double _fallbackThreshold = 0.28;
  static const double _minConfidence = 0.45;
  static const int _bridgeInvalidFrames = 4;
  static const int _invalidFramesBeforeGap = 14;

  final AudioRecorder _recorder;
  final List<double> _hannWindow;
  final StreamController<PitchReading> _readingsController =
      StreamController<PitchReading>.broadcast();

  StreamSubscription<Uint8List>? _audioSubscription;
  List<double> _sampleBuffer = <double>[];
  int _bufferOffset = 0;
  double? _smoothedHz;
  int _invalidFrameCount = 0;
  bool _isRunning = false;

  Stream<PitchReading> get readings => _readingsController.stream;

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) {
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw const PitchTrackerException('Mikrofon izni verilmedi.');
    }

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        streamBufferSize: 4096,
      ),
    );

    _resetSessionState();
    _isRunning = true;

    _audioSubscription = stream.listen(
      _handleAudioChunk,
      onError: (Object error, StackTrace stackTrace) {
        _readingsController.addError(error, stackTrace);
      },
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    if (_isRunning) {
      try {
        await _recorder.stop();
      } catch (_) {
        // Ignore teardown issues to keep the UI responsive.
      }
    }

    _isRunning = false;
    _resetSessionState();
  }

  Future<void> dispose() async {
    await stop();
    await _readingsController.close();
    await _recorder.dispose();
  }

  void _handleAudioChunk(Uint8List chunk) {
    if (!_isRunning || chunk.lengthInBytes < 2) {
      return;
    }

    final byteData = ByteData.sublistView(chunk);
    for (var index = 0; index <= chunk.lengthInBytes - 2; index += 2) {
      _sampleBuffer.add(
        byteData.getInt16(index, Endian.little) / 32768.0,
      );
    }

    while (_sampleBuffer.length - _bufferOffset >= _frameSize) {
      final frame = _sampleBuffer.sublist(
        _bufferOffset,
        _bufferOffset + _frameSize,
      );
      _bufferOffset += _hopSize;

      final estimate = _estimatePitch(frame);
      if (estimate == null) {
        _invalidFrameCount += 1;
        if (_smoothedHz != null && _invalidFrameCount <= _bridgeInvalidFrames) {
          _emitReading(
            hz: _smoothedHz,
            confidence: 0.0,
          );
          continue;
        }

        if (_invalidFrameCount >= _invalidFramesBeforeGap) {
          _smoothedHz = null;
          _emitReading(hz: null, confidence: 0.0);
        }
      } else {
        _invalidFrameCount = 0;
        _smoothedHz = _smoothedHz == null
            ? estimate.hz
            : _smoothedHz! +
                (_smoothingAlpha(estimate.confidence) *
                    (estimate.hz - _smoothedHz!));
        _emitReading(
          hz: _smoothedHz,
          confidence: estimate.confidence,
        );
      }
    }

    if (_bufferOffset > _frameSize * 4) {
      _sampleBuffer = _sampleBuffer.sublist(_bufferOffset);
      _bufferOffset = 0;
    }
  }

  void _emitReading({
    required double? hz,
    required double confidence,
  }) {
    if (_readingsController.isClosed) {
      return;
    }

    _readingsController.add(
      PitchReading(
        timestamp: DateTime.now(),
        hz: hz,
        confidence: confidence,
      ),
    );
  }

  _PitchEstimate? _estimatePitch(List<double> frame) {
    final mean = frame.reduce((sum, sample) => sum + sample) / frame.length;
    final windowed = List<double>.filled(frame.length, 0.0);
    var rmsSum = 0.0;

    for (var index = 0; index < frame.length; index += 1) {
      final sample = (frame[index] - mean) * _hannWindow[index];
      windowed[index] = sample;
      rmsSum += sample * sample;
    }

    final rms = sqrt(rmsSum / windowed.length);
    if (rms < _rmsThreshold) {
      return null;
    }

    final tauMin = (_sampleRate / _maxFrequency).floor();
    final tauMax = min(
      (_sampleRate / _minFrequency).ceil(),
      windowed.length ~/ 2,
    );

    final difference = List<double>.filled(tauMax + 1, 0.0);
    for (var tau = 1; tau <= tauMax; tau += 1) {
      var sum = 0.0;
      for (var index = 0; index < windowed.length - tau; index += 1) {
        final delta = windowed[index] - windowed[index + tau];
        sum += delta * delta;
      }
      difference[tau] = sum;
    }

    final cumulative = List<double>.filled(tauMax + 1, 1.0);
    var runningSum = 0.0;
    for (var tau = 1; tau <= tauMax; tau += 1) {
      runningSum += difference[tau];
      cumulative[tau] =
          runningSum == 0 ? 1.0 : (difference[tau] * tau) / runningSum;
    }

    final tauEstimate = _selectTau(cumulative, tauMin, tauMax);
    if (tauEstimate == null) {
      return null;
    }

    final refinedTau = _refineTau(cumulative, tauEstimate);
    final hz = _sampleRate / refinedTau;
    final confidence = (1 - cumulative[tauEstimate]).clamp(0.0, 1.0);

    if (hz.isNaN ||
        hz.isInfinite ||
        hz < _minFrequency ||
        hz > _maxFrequency ||
        confidence < _minConfidence) {
      return null;
    }

    return _PitchEstimate(hz: hz, confidence: confidence);
  }

  int? _selectTau(List<double> cumulative, int tauMin, int tauMax) {
    for (var tau = tauMin; tau <= tauMax; tau += 1) {
      if (cumulative[tau] < _yinThreshold) {
        var currentTau = tau;
        while (currentTau + 1 <= tauMax &&
            cumulative[currentTau + 1] < cumulative[currentTau]) {
          currentTau += 1;
        }
        return currentTau;
      }
    }

    var bestTau = tauMin;
    var bestValue = cumulative[tauMin];

    for (var tau = tauMin + 1; tau <= tauMax; tau += 1) {
      if (cumulative[tau] < bestValue) {
        bestValue = cumulative[tau];
        bestTau = tau;
      }
    }

    if (bestValue > _fallbackThreshold) {
      return null;
    }

    return bestTau;
  }

  double _refineTau(List<double> cumulative, int tauEstimate) {
    if (tauEstimate <= 1 || tauEstimate >= cumulative.length - 1) {
      return tauEstimate.toDouble();
    }

    final left = cumulative[tauEstimate - 1];
    final center = cumulative[tauEstimate];
    final right = cumulative[tauEstimate + 1];
    final denominator = (2 * center) - left - right;

    if (denominator.abs() < 1e-6) {
      return tauEstimate.toDouble();
    }

    return tauEstimate + ((right - left) / (2 * denominator));
  }

  double _smoothingAlpha(double confidence) {
    if (confidence >= 0.8) {
      return 0.52;
    }
    if (confidence >= 0.6) {
      return 0.4;
    }
    return 0.26;
  }

  void _resetSessionState() {
    _sampleBuffer = <double>[];
    _bufferOffset = 0;
    _smoothedHz = null;
    _invalidFrameCount = 0;
  }
}

class _PitchEstimate {
  const _PitchEstimate({
    required this.hz,
    required this.confidence,
  });

  final double hz;
  final double confidence;
}
