import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vocal_hygiene_personalization.dart';
import '../models/vocal_hygiene_question.dart';
import '../models/vocal_hygiene_survey_response.dart';
import '../services/vocal_hygiene_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
import 'vocal_hygiene_screen.dart';

class VocalHygieneOnboardingScreen extends StatefulWidget {
  const VocalHygieneOnboardingScreen({super.key});

  @override
  State<VocalHygieneOnboardingScreen> createState() =>
      _VocalHygieneOnboardingScreenState();
}

class _VocalHygieneOnboardingScreenState
    extends State<VocalHygieneOnboardingScreen> {
  final List<VocalHygieneQuestion> _questions =
      VocalHygieneRepository.questions;
  final Map<String, Set<String>> _selectedAnswers = <String, Set<String>>{};

  int _currentIndex = 0;
  bool _isSubmitting = false;

  VocalHygieneQuestion get _currentQuestion => _questions[_currentIndex];

  bool get _canContinue {
    final selected = _selectedAnswers[_currentQuestion.id];
    return selected != null && selected.isNotEmpty;
  }

  void _toggleChoice(String optionId) {
    final question = _currentQuestion;
    final selected = _selectedAnswers.putIfAbsent(
      question.id,
      () => <String>{},
    );

    if (question.type == VocalHygieneQuestionType.singleChoice) {
      setState(() {
        selected
          ..clear()
          ..add(optionId);
      });
      return;
    }

    setState(() {
      if (optionId == 'none') {
        selected
          ..clear()
          ..add(optionId);
      } else {
        selected.remove('none');
        if (!selected.add(optionId)) {
          selected.remove(optionId);
        }
      }
    });
  }

  Future<void> _continue() async {
    if (!_canContinue || _isSubmitting) {
      return;
    }

    final isLastQuestion = _currentIndex == _questions.length - 1;
    if (!isLastQuestion) {
      setState(() {
        _currentIndex += 1;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final answers = <String, List<String>>{};
    for (final entry in _selectedAnswers.entries) {
      answers[entry.key] = entry.value.toList(growable: false);
    }

    final response = VocalHygieneSurveyResponse(
      answers: answers,
      createdAt: DateTime.now(),
    );
    await VocalHygieneRepository.instance.saveResponse(response);
    final personalization = VocalHygienePersonalizer.evaluate(response);

    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => VocalHygieneScreen(
          personalizationResult: personalization,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIndex + 1) / _questions.length;
    final question = _currentQuestion;
    final selected = _selectedAnswers[question.id] ?? <String>{};
    final isLastQuestion = _currentIndex == _questions.length - 1;

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            const AppTopHeader.withBack(title: 'Vokal Hijyenini Kişiselleştir'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Kısa bir değerlendirme ile sana özel öneriler hazırlayacağız.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF5F6E84),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                      backgroundColor: const Color(0xFFE3E8EE),
                      color: AppTheme.darkBlue,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          'Soru ${_currentIndex + 1}/${_questions.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5F6E84),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.cardBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0D000000),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        question.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: question.options.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final option = question.options[index];
                          final isSelected = selected.contains(option.id);
                          return _OptionCard(
                            label: option.label,
                            isSelected: isSelected,
                            isMultiSelect: question.type ==
                                VocalHygieneQuestionType.multiChoice,
                            onTap: () => _toggleChoice(option.id),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_currentIndex > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _currentIndex -= 1;
                                      });
                                    },
                              child: const Text('Geri'),
                            ),
                          ),
                        if (_currentIndex > 0) const SizedBox(width: 10),
                        Expanded(
                          flex: _currentIndex > 0 ? 1 : 2,
                          child: FilledButton(
                            onPressed: _canContinue ? _continue : null,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isLastQuestion
                                        ? 'Sonuçları Gör'
                                        : 'Devam Et',
                                  ),
                          ),
                        ),
                      ],
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.isSelected,
    required this.isMultiSelect,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isMultiSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFFE6F1F5) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.darkBlue : AppTheme.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isMultiSelect
                    ? (isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank)
                    : (isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                color: isSelected ? AppTheme.darkBlue : const Color(0xFF7D8797),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
