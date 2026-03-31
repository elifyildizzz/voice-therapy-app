enum VocalHygieneQuestionType { singleChoice, multiChoice }

class VocalHygieneOption {
  const VocalHygieneOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class VocalHygieneQuestion {
  const VocalHygieneQuestion({
    required this.id,
    required this.title,
    required this.type,
    required this.options,
  });

  final String id;
  final String title;
  final VocalHygieneQuestionType type;
  final List<VocalHygieneOption> options;
}
