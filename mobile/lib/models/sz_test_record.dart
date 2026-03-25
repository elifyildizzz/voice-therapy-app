import 'dart:convert';

class SzTestRecord {
  const SzTestRecord({
    this.id,
    required this.userId,
    required this.createdAt,
    required this.sAttempts,
    required this.zAttempts,
    required this.sBest,
    required this.zBest,
    required this.ratio,
  });

  factory SzTestRecord.create({
    required String userId,
    required List<double> sAttempts,
    required List<double> zAttempts,
    DateTime? createdAt,
  }) {
    final sBest = sAttempts.isEmpty
        ? 0.0
        : sAttempts
            .reduce((value, element) => value > element ? value : element);
    final zBest = zAttempts.isEmpty
        ? 0.0
        : zAttempts
            .reduce((value, element) => value > element ? value : element);
    final ratio = zBest == 0 ? 0.0 : sBest / zBest;

    return SzTestRecord(
      userId: userId,
      createdAt: createdAt ?? DateTime.now(),
      sAttempts: sAttempts,
      zAttempts: zAttempts,
      sBest: sBest,
      zBest: zBest,
      ratio: ratio,
    );
  }

  factory SzTestRecord.fromDatabase(Map<String, Object?> map) {
    return SzTestRecord(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      sAttempts: _decodeAttempts(map['s_attempts'] as String),
      zAttempts: _decodeAttempts(map['z_attempts'] as String),
      sBest: (map['s_best'] as num).toDouble(),
      zBest: (map['z_best'] as num).toDouble(),
      ratio: (map['ratio'] as num).toDouble(),
    );
  }

  final int? id;
  final String userId;
  final DateTime createdAt;
  final List<double> sAttempts;
  final List<double> zAttempts;
  final double sBest;
  final double zBest;
  final double ratio;

  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'user_id': userId,
      'created_at': createdAt.millisecondsSinceEpoch,
      's_attempts': jsonEncode(sAttempts),
      'z_attempts': jsonEncode(zAttempts),
      's_best': sBest,
      'z_best': zBest,
      'ratio': ratio,
    };
  }

  SzTestRecord copyWith({
    int? id,
    String? userId,
    DateTime? createdAt,
    List<double>? sAttempts,
    List<double>? zAttempts,
    double? sBest,
    double? zBest,
    double? ratio,
  }) {
    return SzTestRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      sAttempts: sAttempts ?? this.sAttempts,
      zAttempts: zAttempts ?? this.zAttempts,
      sBest: sBest ?? this.sBest,
      zBest: zBest ?? this.zBest,
      ratio: ratio ?? this.ratio,
    );
  }

  static List<double> _decodeAttempts(String rawValue) {
    final values = jsonDecode(rawValue) as List<dynamic>;
    return values.map((value) => (value as num).toDouble()).toList();
  }
}
