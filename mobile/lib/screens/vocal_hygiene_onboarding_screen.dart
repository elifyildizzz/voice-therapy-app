import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vocal_hygiene_personalization.dart';
import '../models/vocal_hygiene_question.dart';
import '../models/vocal_hygiene_survey_response.dart';
import '../services/vocal_hygiene_repository.dart';
import '../theme/app_theme.dart';
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
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: AppTheme.homeCard,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            _VocalHygieneSurveyHeader(
              progress: progress,
              currentQuestion: _currentIndex + 1,
              totalQuestions: _questions.length,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_currentIndex + 1}-) ${question.title}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: question.options.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                          flex: _currentIndex > 0 ? 2 : 1,
                          child: FilledButton(
                            onPressed: _canContinue ? _continue : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.homeIconBackground,
                              foregroundColor: AppTheme.homeAccent,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: AppTheme.homeAccent,
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

class _VocalHygieneSurveyHeader extends StatelessWidget {
  const _VocalHygieneSurveyHeader({
    required this.progress,
    required this.currentQuestion,
    required this.totalQuestions,
  });

  final double progress;
  final int currentQuestion;
  final int totalQuestions;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 18),
      decoration: const BoxDecoration(
        color: AppTheme.homeCard,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x120F1B16),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.homeAccent,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Vokal Hijyenini Kişiselleştir',
            style: TextStyle(
              color: AppTheme.homeAccent,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kısa bir değerlendirme ile sana özel öneriler hazırlayacağız.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Soru $currentQuestion/$totalQuestions',
                style: const TextStyle(
                  color: AppTheme.homeAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.72),
              color: AppTheme.homeAccent,
            ),
          ),
        ],
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
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.soft : AppTheme.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? AppTheme.homeAccent : AppTheme.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected ? null : AppTheme.softShadow,
          ),
          child: Row(
            children: [
              Icon(
                isMultiSelect
                    ? (isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded)
                    : (isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded),
                color: isSelected ? AppTheme.homeAccent : AppTheme.cardBorder,
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
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
