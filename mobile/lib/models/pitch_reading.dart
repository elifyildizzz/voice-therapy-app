class PitchReading {
  const PitchReading({
    required this.timestamp,
    required this.hz,
    required this.confidence,
  });

  final DateTime timestamp;
  final double? hz;
  final double confidence;

  bool get isReliable => hz != null;
}
