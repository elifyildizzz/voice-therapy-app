import 'package:flutter/material.dart';

import '../models/client_form_record.dart';
import '../models/sz_test_record.dart';
import '../services/auth_service.dart';
import '../services/client_form_repository.dart';
import '../services/sz_test_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_formatters.dart';
import 'settings_screen.dart';
import 'sz_test_screen.dart';

const Color _profileAccentGreen = AppTheme.homeAccent;
const Color _profileTabAccentGreen = AppTheme.buttonPrimary;
const Color _profileSoftGreen = Color(0xFFF0F5E9);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _ProfileTab {
  measurements,
  questionnaires,
  activity,
}

enum _ClinicalStatus {
  normal,
  risk,
  borderline,
}

class _ProfileScreenState extends State<ProfileScreen> {
  _ProfileTab _activeTab = _ProfileTab.measurements;

  Future<_ProfileData> _loadProfileData() async {
    final questionnaires = await ClientFormRepository.instance.fetchRecords();
    final measurements = await SzTestRepository.instance.fetchRecords();

    return _ProfileData(
      measurements: measurements,
      questionnaires: questionnaires,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            AuthService.instance.currentUserNotifier,
            ClientFormRepository.instance.changes,
            SzTestRepository.instance.changes,
          ]),
          builder: (context, _) {
            return FutureBuilder<_ProfileData>(
              future: _loadProfileData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data ??
                    const _ProfileData(
                      measurements: <SzTestRecord>[],
                      questionnaires: <ClientFormRecord>[],
                    );

                final user = AuthService.instance.currentUser;
                final fullName = user == null
                    ? 'Profil'
                    : '${user.firstName} ${user.lastName}'.trim();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    _ProfileHeaderCard(
                      fullName: fullName,
                      lastSessionDate: _buildLastSessionLabel(data),
                      onEditPressed: user == null ? null : _openSettings,
                    ),
                    const SizedBox(height: 18),
                    _ProfileTabs(
                      activeTab: _activeTab,
                      onTabSelected: (tab) {
                        setState(() {
                          _activeTab = tab;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ..._buildActiveContent(data),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  String _buildLastSessionLabel(_ProfileData data) {
    final candidates = <DateTime>[];
    candidates.addAll(data.measurements.map((item) => item.createdAt));
    candidates.addAll(data.questionnaires.map((item) => item.createdAt));

    if (candidates.isEmpty) {
      return 'Son seans: Kayıt bulunmuyor';
    }

    candidates.sort((a, b) => b.compareTo(a));
    return 'Son seans: ${formatAppDate(candidates.first)}';
  }

  List<Widget> _buildActiveContent(_ProfileData data) {
    switch (_activeTab) {
      case _ProfileTab.measurements:
        final items = data.measurements
            .map(
              (record) => _MeasurementItem(
                date: formatAppDate(record.createdAt),
                name: 'S/Z Oranı',
                value: record.ratio.toStringAsFixed(2),
                unit: '',
                status: _resolveMeasurementStatus(record.ratio),
              ),
            )
            .toList(growable: false);

        final content = <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ProgressTrendCard(
              points: _buildTrendPoints(data.measurements),
            ),
          ),
        ];

        if (items.isEmpty) {
          content.add(
            _EmptyStateCard(
              icon: Icons.straighten_rounded,
              title: 'Henüz ölçüm kaydı yok',
              message: 'S/Z testi sonuçlarınız burada listelenecek.',
              actionLabel: 'İlk Ölçümü Ekle',
              onActionPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SzTestScreen(),
                  ),
                );
              },
            ),
          );
          return content;
        }

        content.addAll(
          items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MeasurementCard(item: item),
            ),
          ),
        );
        content.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _InsightsCard(
              insights: _buildInsights(data),
            ),
          ),
        );
        return content;

      case _ProfileTab.questionnaires:
        final items = data.questionnaires
            .map(
              (record) => _QuestionnaireItem(
                date: formatAppDate(record.createdAt),
                name: 'Danışan Bilgi Formu',
                score: record.totalScore,
                interpretation: record.resultLabel,
                status: _resolveQuestionnaireStatus(record.totalScore),
              ),
            )
            .toList(growable: false);

        if (items.isEmpty) {
          return const [
            _EmptyStateCard(
              icon: Icons.assignment_outlined,
              title: 'Henüz anket kaydı yok',
              message: 'Anket geçmişiniz burada listelenecek.',
            ),
          ];
        }

        return items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QuestionnaireCard(item: item),
              ),
            )
            .toList();

      case _ProfileTab.activity:
        final items = _buildActivityItems(data);

        if (items.isEmpty) {
          return const [
            _EmptyStateCard(
              icon: Icons.history,
              title: 'Henüz aktivite yok',
              message: 'Yaptığınız işlemler burada kronolojik görünür.',
            ),
          ];
        }

        return items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActivityCard(item: item),
              ),
            )
            .toList();
    }
  }

  List<_ActivityItem> _buildActivityItems(_ProfileData data) {
    final items = <_ActivityItem>[];

    for (final record in data.measurements) {
      items.add(
        _ActivityItem(
          date: formatAppDate(record.createdAt),
          type: 'Ölçüm',
          description:
              'S/Z testi tamamlandı (Oran: ${record.ratio.toStringAsFixed(2)})',
          createdAt: record.createdAt,
        ),
      );
    }

    for (final record in data.questionnaires) {
      items.add(
        _ActivityItem(
          date: formatAppDate(record.createdAt),
          type: 'Anket',
          description:
              'Danışan bilgi formu dolduruldu (Skor: ${record.totalScore})',
          createdAt: record.createdAt,
        ),
      );
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  _ClinicalStatus _resolveMeasurementStatus(double ratio) {
    if (ratio <= 1.4) {
      return _ClinicalStatus.normal;
    }
    if (ratio <= 1.6) {
      return _ClinicalStatus.borderline;
    }
    return _ClinicalStatus.risk;
  }

  _ClinicalStatus _resolveQuestionnaireStatus(int totalScore) {
    if (totalScore <= 9) {
      return _ClinicalStatus.normal;
    }
    if (totalScore <= 14) {
      return _ClinicalStatus.borderline;
    }
    return _ClinicalStatus.risk;
  }

  List<_TrendPoint> _buildTrendPoints(List<SzTestRecord> measurements) {
    if (measurements.isEmpty) {
      return const <_TrendPoint>[];
    }

    final ascending = [...measurements]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final recent = ascending.length > 6
        ? ascending.sublist(ascending.length - 6)
        : ascending;

    return recent
        .map(
          (item) => _TrendPoint(
            label: '${_monthLabel(item.createdAt.month)} ${item.createdAt.day}',
            value: item.ratio,
          ),
        )
        .toList(growable: false);
  }

  List<String> _buildInsights(_ProfileData data) {
    final insights = <String>[];
    final measurements = data.measurements;
    final questionnaires = data.questionnaires;

    if (measurements.length >= 2) {
      final latest = measurements[0].ratio;
      final previous = measurements[1].ratio;
      final latestDistance = (latest - 1.0).abs();
      final previousDistance = (previous - 1.0).abs();
      if (latestDistance < previousDistance) {
        insights.add(
          'S/Z oranı son ölçümde önceki seansa göre iyileşti.',
        );
      } else if (latestDistance > previousDistance) {
        insights.add(
          'S/Z oranı son ölçümde bir miktar dalgalandı, düzenli takip önerilir.',
        );
      } else {
        insights.add('S/Z oranı son iki seansta benzer seyrediyor.');
      }
    } else {
      insights.add('Trend değerlendirmesi için en az 2 S/Z kaydı gerekiyor.');
    }

    if (measurements.length >= 3) {
      final values = measurements.take(5).map((item) => item.ratio).toList();
      final minValue = values.reduce((a, b) => a < b ? a : b);
      final maxValue = values.reduce((a, b) => a > b ? a : b);
      if ((maxValue - minValue) <= 0.25) {
        insights.add('Ses stabilitesi son ölçümlerde tutarlı ilerliyor.');
      } else {
        insights
            .add('Ses stabilitesinde değişkenlik var, egzersize devam edin.');
      }
    }

    if (questionnaires.length >= 2) {
      final latest = questionnaires[0].totalScore;
      final previous = questionnaires[1].totalScore;
      if (latest < previous) {
        insights.add('Anket puanlarında olumlu yönde bir gelişim görünüyor.');
      } else if (latest > previous) {
        insights
            .add('Anket puanları yükselmiş; klinik takip sıklaştırılabilir.');
      } else {
        insights.add('Anket puanları stabil seyrediyor.');
      }
    } else if (questionnaires.length == 1) {
      insights.add(
          'Anket trendi için ikinci bir kayıt oluştuğunda karşılaştırma yapılacak.');
    }

    return insights.take(3).toList(growable: false);
  }

  String _monthLabel(int month) {
    const monthLabels = <int, String>{
      1: 'Oca',
      2: 'Şub',
      3: 'Mar',
      4: 'Nis',
      5: 'May',
      6: 'Haz',
      7: 'Tem',
      8: 'Ağu',
      9: 'Eyl',
      10: 'Eki',
      11: 'Kas',
      12: 'Ara',
    };
    return monthLabels[month] ?? month.toString();
  }
}

class _ProfileData {
  const _ProfileData({
    required this.measurements,
    required this.questionnaires,
  });

  final List<SzTestRecord> measurements;
  final List<ClientFormRecord> questionnaires;
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.fullName,
    required this.lastSessionDate,
    required this.onEditPressed,
  });

  final String fullName;
  final String lastSessionDate;
  final VoidCallback? onEditPressed;

  @override
  Widget build(BuildContext context) {
    final segments = fullName.trim().split(RegExp(r'\s+'));
    final initials = segments.isEmpty
        ? 'P'
        : segments
            .take(2)
            .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
            .join();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.cardBorder,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F111827),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lastSessionDate,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditPressed,
            splashRadius: 22,
            icon: const Icon(
              Icons.settings_outlined,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({
    required this.activeTab,
    required this.onTabSelected,
  });

  final _ProfileTab activeTab;
  final ValueChanged<_ProfileTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: 'Ölçümler',
              isActive: activeTab == _ProfileTab.measurements,
              onTap: () => onTabSelected(_ProfileTab.measurements),
            ),
          ),
          Expanded(
            child: _TabButton(
              title: 'Anketler',
              isActive: activeTab == _ProfileTab.questionnaires,
              onTap: () => onTabSelected(_ProfileTab.questionnaires),
            ),
          ),
          Expanded(
            child: _TabButton(
              title: 'Aktivite',
              isActive: activeTab == _ProfileTab.activity,
              onTap: () => onTabSelected(_ProfileTab.activity),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  final String title;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? _profileTabAccentGreen : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: isActive ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressTrendCard extends StatelessWidget {
  const _ProgressTrendCard({
    required this.points,
  });

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return _ClinicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: _profileAccentGreen,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'İlerleme Trendi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (points.length < 2)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Grafik için en az 2 ölçüm kaydı gerekli.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                ),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: _TrendChart(points: points),
            ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.points,
  });

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final values = points.map((point) => point.value).toList(growable: false);
    var minValue = values.reduce((a, b) => a < b ? a : b);
    var maxValue = values.reduce((a, b) => a > b ? a : b);
    if ((maxValue - minValue) < 0.2) {
      minValue -= 0.1;
      maxValue += 0.1;
    }

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _TrendChartPainter(
              values: values,
              minValue: minValue,
              maxValue: maxValue,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              points.first.label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7784)),
            ),
            if (points.length > 2)
              Text(
                points[points.length ~/ 2].label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7784)),
              ),
            Text(
              points.last.label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7784)),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.values,
    required this.minValue,
    required this.maxValue,
  });

  final List<double> values;
  final double minValue;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }

    const leftPadding = 6.0;
    const rightPadding = 6.0;
    const topPadding = 8.0;
    const bottomPadding = 8.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = AppTheme.cardBorder
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = _profileAccentGreen
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pointPaint = Paint()..color = _profileAccentGreen;

    for (var i = 0; i < 4; i++) {
      final y = topPadding + (chartHeight * i / 3);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    for (var i = 0; i < 3; i++) {
      final x = leftPadding + (chartWidth * i / 2);
      canvas.drawLine(
        Offset(x, topPadding),
        Offset(x, size.height - bottomPadding),
        gridPaint,
      );
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = leftPadding + (chartWidth * i / (values.length - 1));
      final normalized = (values[i] - minValue) / (maxValue - minValue);
      final y = topPadding + chartHeight * (1 - normalized);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < values.length; i++) {
      final x = leftPadding + (chartWidth * i / (values.length - 1));
      final normalized = (values[i] - minValue) / (maxValue - minValue);
      final y = topPadding + chartHeight * (1 - normalized);
      canvas.drawCircle(Offset(x, y), 4.8, pointPaint);
      canvas.drawCircle(
        Offset(x, y),
        2.8,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue;
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({
    required this.insights,
  });

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.soft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  color: AppTheme.terracotta, size: 22),
              SizedBox(width: 8),
              Text(
                'Klinik İçgörüler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: AppTheme.terracotta,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      insight,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({
    required this.item,
  });

  final _MeasurementItem item;

  @override
  Widget build(BuildContext context) {
    return _ClinicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.date,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.value,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            height: 1,
                          ),
                        ),
                        if (item.unit.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              item.unit,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(status: item.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionnaireCard extends StatelessWidget {
  const _QuestionnaireCard({
    required this.item,
  });

  final _QuestionnaireItem item;

  @override
  Widget build(BuildContext context) {
    return _ClinicalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.date,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _StatusBadge(
                status: item.status,
                textOverride: item.interpretation,
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
              children: [
                const TextSpan(
                  text: 'Skor ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
                TextSpan(
                  text: '${item.score}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.item,
  });

  final _ActivityItem item;

  @override
  Widget build(BuildContext context) {
    return _ClinicalCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _profileSoftGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 20,
              color: _profileAccentGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.date,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.type,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _profileAccentGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return _ClinicalCard(
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _profileSoftGreen,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 38, color: _profileAccentGreen),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textMuted,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onActionPressed != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _profileTabAccentGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: onActionPressed,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClinicalCard extends StatelessWidget {
  const _ClinicalCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    this.textOverride,
  });

  final _ClinicalStatus status;
  final String? textOverride;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final String label;

    switch (status) {
      case _ClinicalStatus.normal:
        background = const Color(0xFFE9F7EE);
        foreground = const Color(0xFF237A44);
        label = 'Normal';
      case _ClinicalStatus.risk:
        background = const Color(0xFFFBEAEC);
        foreground = const Color(0xFFB43545);
        label = 'Risk';
      case _ClinicalStatus.borderline:
        background = const Color(0xFFFFF7E5);
        foreground = const Color(0xFF9A6A00);
        label = 'Sınırda';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        textOverride ?? label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MeasurementItem {
  const _MeasurementItem({
    required this.date,
    required this.name,
    required this.value,
    required this.unit,
    required this.status,
  });

  final String date;
  final String name;
  final String value;
  final String unit;
  final _ClinicalStatus status;
}

class _TrendPoint {
  const _TrendPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class _QuestionnaireItem {
  const _QuestionnaireItem({
    required this.date,
    required this.name,
    required this.score,
    required this.interpretation,
    required this.status,
  });

  final String date;
  final String name;
  final int score;
  final String interpretation;
  final _ClinicalStatus status;
}

class _ActivityItem {
  const _ActivityItem({
    required this.date,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  final String date;
  final String type;
  final String description;
  final DateTime createdAt;
}
