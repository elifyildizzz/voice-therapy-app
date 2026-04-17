class MeasurementRecord {
  const MeasurementRecord({
    this.id,
    required this.userId,
    required this.module,
    required this.exerciseKey,
    required this.exerciseTitle,
    required this.duration,
    required this.clientDate,
    required this.performedAt,
    required this.createdAt,
  });

  final String? id;
  final String userId;
  final String module;
  final String exerciseKey;
  final String exerciseTitle;
  final Duration duration;
  final String clientDate;
  final DateTime performedAt;
  final DateTime createdAt;

  factory MeasurementRecord.fromApi(Map<String, dynamic> map) {
    return MeasurementRecord(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString() ?? '',
      module: map['module'] as String? ?? '',
      exerciseKey: map['exercise_key'] as String? ?? '',
      exerciseTitle: map['exercise_title'] as String? ?? '',
      duration:
          Duration(milliseconds: (map['duration_ms'] as num?)?.toInt() ?? 0),
      clientDate: map['client_date'] as String? ?? '',
      performedAt: _readDateTime(map['performed_at']),
      createdAt: _readDateTime(map['created_at']),
    );
  }

  static DateTime _readDateTime(Object? value) {
    if (value is String) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }
}
