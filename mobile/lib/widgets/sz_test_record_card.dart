import 'package:flutter/material.dart';

import '../models/sz_test_record.dart';
import '../theme/app_theme.dart';
import '../utils/app_formatters.dart';
import '../utils/sz_test_formatters.dart';

class SzTestRecordCard extends StatelessWidget {
  const SzTestRecordCard({
    required this.title,
    required this.record,
    this.showNote = false,
    this.showTime = false,
    super.key,
  });

  final String title;
  final SzTestRecord record;
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
          _RecordMetricRow(
            label: 'Tarih',
            value: formatAppDate(record.createdAt, withTime: showTime),
          ),
          const SizedBox(height: 8),
          _RecordMetricRow(
            label: 'S en uzun',
            value: formatSzSeconds(record.sBest),
          ),
          const SizedBox(height: 8),
          _RecordMetricRow(
            label: 'Z en uzun',
            value: formatSzSeconds(record.zBest),
          ),
          const SizedBox(height: 8),
          _RecordMetricRow(
            label: 'S/Z oranı',
            value: record.ratio.toStringAsFixed(2),
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
                buildSzRatioNote(record.ratio),
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

class _RecordMetricRow extends StatelessWidget {
  const _RecordMetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
