class VocalHygieneSurveyResponse {
  const VocalHygieneSurveyResponse({
    required this.answers,
    required this.createdAt,
  });

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
}
