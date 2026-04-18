import 'package:flutter/material.dart';

import '../models/measurement_record.dart';
import '../services/measurement_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    required this.onBackPressed,
    super.key,
  });

  final VoidCallback onBackPressed;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const List<String> _monthNames = <String>[
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static const List<String> _weekdayLabels = <String>[
    'Paz',
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
  ];

  static const List<String> _weekdayNames = <String>[
    'Pazar',
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
  ];

  final MeasurementRepository _repository = MeasurementRepository.instance;
  Map<DateTime, List<_ProgressRecord>> _recordsByDay =
      <DateTime, List<_ProgressRecord>>{};
  bool _isLoading = true;
  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _selectedDate = today;
    _visibleMonth = DateTime(today.year, today.month);
    _repository.changes.addListener(_handleRepositoryChange);
    if (_repository.hasLoadedCache) {
      _applyRecords(_repository.peekRecords());
      _isLoading = false;
    } else {
      _loadRecords();
    }
  }

  @override
  void dispose() {
    _repository.changes.removeListener(_handleRepositoryChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRecords = _recordsByDay[_selectedDate] ?? const [];
    final vocalGroups = _groupRecords(
      selectedRecords,
      module: _ProgressModule.vocalFunction,
    );
    final breathGroups = _groupRecords(
      selectedRecords,
      module: _ProgressModule.breathControl,
    );
    final monthGrid = _buildMonthCells(_visibleMonth);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          AppTopHeader.withBack(
            title: 'İlerlemeni Takip Et',
            showDivider: true,
            onBackPressed: widget.onBackPressed,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CalendarCard(
                    monthLabel: _formatMonthYear(_visibleMonth),
                    weekdayLabels: _weekdayLabels,
                    cells: monthGrid,
                    selectedDate: _selectedDate,
                    onPreviousMonth: _goToPreviousMonth,
                    onNextMonth: _goToNextMonth,
                    onSelectDate: _selectDate,
                  ),
                  const SizedBox(height: 18),
                  _SelectedDayHeader(
                    formattedDate: _formatLongDate(_selectedDate),
                    totalRecords: selectedRecords.length,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 14),
                  _ModuleSectionCard(
                    title: 'Vokal Fonksiyon Egzersizleri',
                    subtitle: 'Gün içindeki süre ölçümleri',
                    icon: Icons.multitrack_audio_rounded,
                    accentColor: const Color(0xFF6E8F7A),
                    groups: vocalGroups,
                    emptyMessage:
                        'Bugün için vokal fonksiyon egzersizi ölçümü bulunmuyor.',
                  ),
                  const SizedBox(height: 14),
                  _ModuleSectionCard(
                    title: 'Nefes Kontrolü',
                    subtitle: 'Maximum /a/ fonasyonu kayıtları',
                    icon: Icons.air_rounded,
                    accentColor: const Color(0xFF6E8F7A),
                    groups: breathGroups,
                    emptyMessage:
                        'Bugün için maximum /a/ fonasyonu kaydı bulunmuyor.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToPreviousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
      _selectedDate = _bestSelectedDateForVisibleMonth(
        visibleMonth: _visibleMonth,
        preferredDay: _selectedDate.day,
      );
    });
  }

  void _goToNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
      _selectedDate = _bestSelectedDateForVisibleMonth(
        visibleMonth: _visibleMonth,
        preferredDay: _selectedDate.day,
      );
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = _dateOnly(date);
      _visibleMonth = DateTime(date.year, date.month);
    });
  }

  DateTime _bestSelectedDateForVisibleMonth({
    required DateTime visibleMonth,
    required int preferredDay,
  }) {
    final maxDay =
        DateUtils.getDaysInMonth(visibleMonth.year, visibleMonth.month);
    return DateTime(
      visibleMonth.year,
      visibleMonth.month,
      preferredDay.clamp(1, maxDay),
    );
  }

  List<DateTime?> _buildMonthCells(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leadingEmptySlots = firstDayOfMonth.weekday % 7;
    final cells = List<DateTime?>.filled(42, null);

    for (var day = 1; day <= daysInMonth; day++) {
      cells[leadingEmptySlots + day - 1] =
          DateTime(month.year, month.month, day);
    }

    return cells;
  }

  void _handleRepositoryChange() {
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final records = await _repository.fetchRecords();
      if (!mounted) {
        return;
      }
      setState(() {
        _applyRecords(records);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recordsByDay = <DateTime, List<_ProgressRecord>>{};
        _isLoading = false;
      });
    }
  }

  void _applyRecords(List<MeasurementRecord> records) {
    final recordsByDay = <DateTime, List<_ProgressRecord>>{};

    for (final record in records) {
      final day = _dateFromClientDate(record.clientDate);
      recordsByDay.putIfAbsent(day, () => <_ProgressRecord>[]).add(
            _mapMeasurementToProgress(record),
          );
    }

    _recordsByDay = recordsByDay;
  }

  _ProgressRecord _mapMeasurementToProgress(MeasurementRecord record) {
    final displayTitle =
        record.module == MeasurementRepository.vocalFunctionModule &&
                record.exerciseTitle.startsWith('Egzersiz ')
            ? record.exerciseKey
            : record.exerciseTitle;

    return _ProgressRecord(
      module: record.module == MeasurementRepository.vocalFunctionModule
          ? _ProgressModule.vocalFunction
          : _ProgressModule.breathControl,
      title: displayTitle,
      duration: record.duration,
      performedAt: record.performedAt,
    );
  }

  List<_ProgressRecordGroup> _groupRecords(
    List<_ProgressRecord> records, {
    required _ProgressModule module,
  }) {
    final grouped = <String, List<_ProgressRecord>>{};

    for (final record in records) {
      if (record.module != module) {
        continue;
      }
      grouped.putIfAbsent(record.title, () => <_ProgressRecord>[]).add(record);
    }

    final groups = grouped.entries.map((entry) {
      final sortedRecords = [...entry.value]
        ..sort((left, right) => left.performedAt.compareTo(right.performedAt));
      return _ProgressRecordGroup(
        title: entry.key,
        firstRecord: sortedRecords.isNotEmpty ? sortedRecords[0] : null,
        secondRecord: sortedRecords.length > 1 ? sortedRecords[1] : null,
      );
    }).toList()
      ..sort((left, right) {
        final leftTime = left.firstRecord?.performedAt ?? DateTime(0);
        final rightTime = right.firstRecord?.performedAt ?? DateTime(0);
        return leftTime.compareTo(rightTime);
      });

    return groups;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _dateFromClientDate(String value) {
    final parts = value.split('-');
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return _dateOnly(DateTime.now());
  }

  String _formatMonthYear(DateTime date) =>
      '${_monthNames[date.month - 1]} ${date.year}';

  String _formatLongDate(DateTime date) {
    final weekday = _weekdayNames[date.weekday % 7];
    return '$weekday, ${date.day} ${_monthNames[date.month - 1]} ${date.year}';
  }
}

class _SelectedDayHeader extends StatelessWidget {
  const _SelectedDayHeader({
    required this.formattedDate,
    required this.totalRecords,
    required this.isLoading,
  });

  final String formattedDate;
  final int totalRecords;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formattedDate,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isLoading
              ? 'Kayıtlar yükleniyor...'
              : totalRecords == 0
                  ? 'Bugün için henüz kayıt yok.'
                  : 'Toplam $totalRecords kayıt bulundu.',
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.monthLabel,
    required this.weekdayLabels,
    required this.cells,
    required this.selectedDate,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
  });

  final String monthLabel;
  final List<String> weekdayLabels;
  final List<DateTime?> cells;
  final DateTime selectedDate;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _MonthArrowButton(
                icon: Icons.chevron_left_rounded,
                onTap: onPreviousMonth,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
              _MonthArrowButton(
                icon: Icons.chevron_right_rounded,
                onTap: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: weekdayLabels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF7A7F87),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          Transform.translate(
            offset: const Offset(0, -10),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 0,
                  crossAxisSpacing: 2,
                  childAspectRatio: 1.12,
                ),
                itemCount: cells.length,
                itemBuilder: (context, index) {
                  final date = cells[index];
                  if (date == null) {
                    return const SizedBox.shrink();
                  }

                  final day = DateTime(date.year, date.month, date.day);
                  final isSelected = DateUtils.isSameDay(day, selectedDate);

                  return _CalendarDayCell(
                    date: day,
                    isSelected: isSelected,
                    onTap: () => onSelectDate(day),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 26,
        height: 26,
        child: Icon(
          icon,
          color: Colors.black,
          size: 22,
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF708B7B) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleSectionCard extends StatelessWidget {
  const _ModuleSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.groups,
    required this.emptyMessage,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<_ProgressRecordGroup> groups;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (groups.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE9E3DA)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                emptyMessage,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppTheme.textMuted,
                ),
              ),
            )
          else
            ...groups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GroupedRecordTile(
                  group: group,
                  accentColor: accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupedRecordTile extends StatelessWidget {
  const _GroupedRecordTile({
    required this.group,
    required this.accentColor,
  });

  final _ProgressRecordGroup group;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E3DA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MeasurementRow(
            label: '1. Ölçüm',
            duration: group.firstRecord?.duration,
          ),
          const SizedBox(height: 8),
          _MeasurementRow(
            label: '2. Ölçüm',
            duration: group.secondRecord?.duration,
          ),
        ],
      ),
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({
    required this.label,
    required this.duration,
  });

  final String label;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          duration != null ? _formatDuration(duration!) : '-',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

enum _ProgressModule {
  vocalFunction,
  breathControl,
}

class _ProgressRecord {
  const _ProgressRecord({
    required this.module,
    required this.title,
    required this.duration,
    required this.performedAt,
  });

  final _ProgressModule module;
  final String title;
  final Duration duration;
  final DateTime performedAt;
}

class _ProgressRecordGroup {
  const _ProgressRecordGroup({
    required this.title,
    required this.firstRecord,
    required this.secondRecord,
  });

  final String title;
  final _ProgressRecord? firstRecord;
  final _ProgressRecord? secondRecord;
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inMilliseconds / 1000;
  return '${totalSeconds.toStringAsFixed(1)} sn';
}
