import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/client_form_questions.dart';
import '../models/client_form_record.dart';
import '../services/client_form_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
import '../widgets/client_form_record_card.dart';

class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final ClientFormRepository _repository = ClientFormRepository.instance;

  final Map<String, int> _responses = <String, int>{};

  bool _isSaving = false;
  ClientFormRecord? _savedRecord;

  bool get _isFormComplete => clientFormQuestions
      .every((question) => _responses[question.fieldKey] != null);

  int get _answeredCount => _responses.length;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveForm() async {
    if (!_isFormComplete || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final savedRecord = await _repository.saveRecord(
        vrqolQ1: _responses['vrqolQ1']!,
        vrqolQ4: _responses['vrqolQ4']!,
        vrqolQ9: _responses['vrqolQ9']!,
        vhiQ3: _responses['vhiQ3']!,
        vhiQ9: _responses['vhiQ9']!,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _savedRecord = savedRecord;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Form sonucu kaydedilirken bir sorun oluştu.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _selectAnswer(String fieldKey, int value) {
    setState(() {
      _responses[fieldKey] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            const AppTopHeader.withBack(
              title: 'Danışan Bilgi Formu',
              showDivider: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ClientFormIntroCard(answeredCount: _answeredCount),
                    const SizedBox(height: 14),
                    const _ClientFormScaleLegend(),
                    const SizedBox(height: 14),
                    ...clientFormQuestions.map(
                      (question) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ClientFormQuestionCard(
                          question: question,
                          selectedValue: _responses[question.fieldKey],
                          onSelect: (value) =>
                              _selectAnswer(question.fieldKey, value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed:
                          _isFormComplete && !_isSaving ? _saveForm : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.darkBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFABC0B4),
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _isSaving ? 'Kaydediliyor...' : 'Kaydet ve Sonucu Gör',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isFormComplete
                          ? 'Tüm sorular yanıtlandı.'
                          : '${clientFormQuestions.length} sorunun tamamını yanıtlayın.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5F6E84),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_savedRecord != null) ...[
                      const SizedBox(height: 16),
                      ClientFormRecordCard(
                        title: 'Form Sonucu',
                        record: _savedRecord!,
                        showNote: true,
                        showTime: true,
                      ),
                    ],
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

class _ClientFormIntroCard extends StatelessWidget {
  const _ClientFormIntroCard({
    required this.answeredCount,
  });

  final int answeredCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lütfen son dönemdeki durumunuza en uygun seçeneği işaretleyin.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Her soru için size en uygun bir cevabı seçin.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'İlerleme: $answeredCount/${clientFormQuestions.length}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientFormScaleLegend extends StatelessWidget {
  const _ClientFormScaleLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ortak Yanıt Ölçeği',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: clientFormScaleOptions
                .map(
                  (option) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text(
                      '${option.value} = ${option.label}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ClientFormQuestionCard extends StatelessWidget {
  const _ClientFormQuestionCard({
    required this.question,
    required this.selectedValue,
    required this.onSelect,
  });

  final ClientFormQuestion question;
  final int? selectedValue;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = selectedValue == null
        ? 'Henüz seçim yapılmadı.'
        : clientFormScaleOptions
            .firstWhere((option) => option.value == selectedValue)
            .label;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8D8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F1B16),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.prompt,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: clientFormScaleOptions
                .map(
                  (option) => _ScaleChoice(
                    value: option.value,
                    isSelected: selectedValue == option.value,
                    onTap: () => onSelect(option.value),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Seçilen: $selectedLabel',
            style: TextStyle(
              fontSize: 12,
              color: selectedValue == null
                  ? const Color(0xFF5F6E84)
                  : AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleChoice extends StatelessWidget {
  const _ScaleChoice({
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  final int value;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: 'Yanıt $value',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 50,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.darkBlue : AppTheme.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? AppTheme.darkBlue : const Color(0xFFD2DFCE),
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x1A2F5D50),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppTheme.homeAccent,
            ),
          ),
        ),
      ),
    );
  }
}
