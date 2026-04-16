import '../utils/client_form_scoring.dart';

class ClientFormRecord {
  const ClientFormRecord({
    this.id,
    required this.userId,
    required this.createdAt,
    required this.vrqolQ1,
    required this.vrqolQ4,
    required this.vrqolQ9,
    required this.vhiQ3,
    required this.vhiQ9,
    required this.totalScore,
    required this.resultLabel,
  });

  factory ClientFormRecord.create({
    required String userId,
    required int vrqolQ1,
    required int vrqolQ4,
    required int vrqolQ9,
    required int vhiQ3,
    required int vhiQ9,
    DateTime? createdAt,
  }) {
    final totalScore = calculateClientFormTotalScore(
      vrqolQ1: vrqolQ1,
      vrqolQ4: vrqolQ4,
      vrqolQ9: vrqolQ9,
      vhiQ3: vhiQ3,
      vhiQ9: vhiQ9,
    );

    return ClientFormRecord(
      userId: userId,
      createdAt: createdAt ?? DateTime.now(),
      vrqolQ1: vrqolQ1,
      vrqolQ4: vrqolQ4,
      vrqolQ9: vrqolQ9,
      vhiQ3: vhiQ3,
      vhiQ9: vhiQ9,
      totalScore: totalScore,
      resultLabel: resolveClientFormResultLabel(totalScore),
    );
  }

  factory ClientFormRecord.fromApi(Map<String, dynamic> map) {
    final responses = map['responses'];
    final responseMap = responses is Map<String, dynamic> ? responses : map;

    return ClientFormRecord(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString() ?? '',
      createdAt: _readCreatedAt(map['created_at']),
      vrqolQ1: responseMap['vrqol_q1'] as int,
      vrqolQ4: responseMap['vrqol_q4'] as int,
      vrqolQ9: responseMap['vrqol_q9'] as int,
      vhiQ3: responseMap['vhi_q3'] as int,
      vhiQ9: responseMap['vhi_q9'] as int,
      totalScore: map['total_score'] as int,
      resultLabel: map['result_label'] as String,
    );
  }

  factory ClientFormRecord.fromDatabase(Map<String, Object?> map) {
    return ClientFormRecord(
      id: map['id']?.toString(),
      userId: map['user_id'] as String,
      createdAt: _readCreatedAt(map['created_at']),
      vrqolQ1: map['vrqol_q1'] as int,
      vrqolQ4: map['vrqol_q4'] as int,
      vrqolQ9: map['vrqol_q9'] as int,
      vhiQ3: map['vhi_q3'] as int,
      vhiQ9: map['vhi_q9'] as int,
      totalScore: map['total_score'] as int,
      resultLabel: map['result_label'] as String,
    );
  }

  final String? id;
  final String userId;
  final DateTime createdAt;
  final int vrqolQ1;
  final int vrqolQ4;
  final int vrqolQ9;
  final int vhiQ3;
  final int vhiQ9;
  final int totalScore;
  final String resultLabel;

  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'user_id': userId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'vrqol_q1': vrqolQ1,
      'vrqol_q4': vrqolQ4,
      'vrqol_q9': vrqolQ9,
      'vhi_q3': vhiQ3,
      'vhi_q9': vhiQ9,
      'total_score': totalScore,
      'result_label': resultLabel,
    };
  }

  ClientFormRecord copyWith({
    String? id,
    String? userId,
    DateTime? createdAt,
    int? vrqolQ1,
    int? vrqolQ4,
    int? vrqolQ9,
    int? vhiQ3,
    int? vhiQ9,
    int? totalScore,
    String? resultLabel,
  }) {
    return ClientFormRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      vrqolQ1: vrqolQ1 ?? this.vrqolQ1,
      vrqolQ4: vrqolQ4 ?? this.vrqolQ4,
      vrqolQ9: vrqolQ9 ?? this.vrqolQ9,
      vhiQ3: vhiQ3 ?? this.vhiQ3,
      vhiQ9: vhiQ9 ?? this.vhiQ9,
      totalScore: totalScore ?? this.totalScore,
      resultLabel: resultLabel ?? this.resultLabel,
    );
  }

  static DateTime _readCreatedAt(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }
}
