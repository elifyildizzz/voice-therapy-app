import 'package:flutter/material.dart';

import '../models/client_form_record.dart';
import '../theme/app_theme.dart';
import '../utils/app_formatters.dart';
import '../utils/client_form_scoring.dart';

class ClientFormRecordCard extends StatelessWidget {
  const ClientFormRecordCard({
    required this.title,
    required this.record,
    this.showNote = false,
    this.showTime = false,
    super.key,
  });

  final String title;
  final ClientFormRecord record;
  final bool showNote;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkBlue,
            ),
          ),
          const SizedBox(height: 12),
          _ClientFormMetricRow(
            label: 'Tarih',
            value: formatAppDate(record.createdAt, withTime: showTime),
          ),
          const SizedBox(height: 8),
          _ClientFormMetricRow(
            label: 'Toplam puan',
            value: record.totalScore.toString(),
          ),
          const SizedBox(height: 8),
          _ClientFormMetricRow(
            label: 'Sonuç',
            value: record.resultLabel,
          ),
          if (showNote) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                buildClientFormResultNote(),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF536274),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClientFormMetricRow extends StatelessWidget {
  const _ClientFormMetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF5F6E84),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
