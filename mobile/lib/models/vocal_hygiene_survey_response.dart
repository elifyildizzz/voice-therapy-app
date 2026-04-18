class VocalHygieneSurveyResponse {
  const VocalHygieneSurveyResponse({
    this.id,
    this.userId,
    required this.answers,
    required this.createdAt,
  });

  factory VocalHygieneSurveyResponse.fromApi(Map<String, dynamic> map) {
    final rawAnswers = map['answers'];
    final answers = <String, List<String>>{};

    if (rawAnswers is Map<String, dynamic>) {
      for (final entry in rawAnswers.entries) {
        final value = entry.value;
        if (value is List) {
          answers[entry.key] =
              value.map((item) => item.toString()).toList(growable: false);
        }
      }
    }

    return VocalHygieneSurveyResponse(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString(),
      answers: answers,
      createdAt: _readCreatedAt(map['created_at']),
    );
  }

  final String? id;
  final String? userId;
  final Map<String, List<String>> answers;
  final DateTime createdAt;

  String? single(String questionId) {
    final selected = answers[questionId];
    if (selected == null || selected.isEmpty) {
      return null;
    }
    return selected.first;
  }

  List<String> multiple(String questionId) {
    return answers[questionId] ?? const <String>[];
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
