import 'package:flutter/material.dart';

import '../models/client_form_record.dart';
import '../models/app_user.dart';
import '../models/sz_test_record.dart';
import '../services/auth_service.dart';
import '../services/client_form_repository.dart';
import '../services/sz_test_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_formatters.dart';

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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    _ProfileHeaderCard(
                      fullName: fullName,
                      lastSessionDate: _buildLastSessionLabel(data),
                      onEditPressed:
                          user == null ? null : () => _openProfileEditor(user),
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
            const _EmptyStateCard(
              icon: Icons.straighten_rounded,
              title: 'Henüz ölçüm kaydı yok',
              message: 'S/Z testi sonuçlarınız burada listelenecek.',
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

  Future<void> _openProfileEditor(AppUser user) async {
    final firstNameController = TextEditingController(text: user.firstName);
    final lastNameController = TextEditingController(text: user.lastName);
    final emailController = TextEditingController(text: user.email);
    final formKey = GlobalKey<FormState>();
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Profili Düzenle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Form(
                      key: formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: firstNameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Ad',
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Ad alanı boş bırakılamaz.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: lastNameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Soyad',
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Soyad alanı boş bırakılamaz.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'E-posta',
                            ),
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.isEmpty) {
                                return 'E-posta alanı zorunludur.';
                              }
                              final emailRegex =
                                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                              if (!emailRegex.hasMatch(text)) {
                                return 'Geçerli bir e-posta adresi girin.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final form = formKey.currentState;
                              if (form == null || !form.validate()) {
                                return;
                              }

                              setSheetState(() {
                                isSubmitting = true;
                              });

                              try {
                                await AuthService.instance
                                    .updateCurrentUserProfile(
                                  firstName: firstNameController.text,
                                  lastName: lastNameController.text,
                                  email: emailController.text,
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                _showSnackBar(
                                  'Profil bilgileri güncellendi.',
                                  const Color(0xFF1F7A45),
                                );
                              } on AuthException catch (error) {
                                _showSnackBar(
                                    error.message, const Color(0xFFB42318));
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() {
                                    isSubmitting = false;
                                  });
                                }
                              }
                            },
                      child: Text(isSubmitting ? 'Kaydediliyor...' : 'Kaydet'),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                              await AuthService.instance.signOut();
                            },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Çıkış Yap'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF7A1B1B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
  }

  void _showSnackBar(String message, Color textColor) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        content: Text(
          message,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 30,
              color: Color(0xFF3B5A73),
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
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkBlue,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  lastSessionDate,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5F6E84),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditPressed,
            splashRadius: 22,
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF5C6874),
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
    return Row(
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF2F587A)
                    : const Color(0xFF7B8794),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 3,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF6EA6C8) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
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
              Icon(Icons.trending_up_rounded,
                  color: Color(0xFF2D66D8), size: 22),
              SizedBox(width: 8),
              Text(
                'İlerleme Trendi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkBlue,
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
                  color: Color(0xFF5F6E84),
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
      ..color = const Color(0xFFE8EDF4)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = const Color(0xFF3A7BE0)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pointPaint = Paint()..color = const Color(0xFF3A7BE0);

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
        color: const Color(0xFFEFF3FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE7F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  color: Color(0xFF2D66D8), size: 22),
              SizedBox(width: 8),
              Text(
                'Klinik İçgörüler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkBlue,
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
                      color: Color(0xFF2D66D8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      insight,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFF3A4758),
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
              color: Color(0xFF5F6E84),
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
                        color: Color(0xFF5F6E84),
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
                            color: Color(0xFF1F2937),
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
                                color: Color(0xFF1F2937),
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
              color: Color(0xFF5F6E84),
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
                    color: AppTheme.darkBlue,
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
                color: Color(0xFF1F2937),
                fontSize: 14,
              ),
              children: [
                const TextSpan(
                  text: 'Skor ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7784),
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
              color: const Color(0xFFE9F1F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 20,
              color: Color(0xFF3F6A87),
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
                    color: Color(0xFF5F6E84),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.type,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
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
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _ClinicalCard(
      child: Column(
        children: [
          Icon(icon, size: 42, color: const Color(0xFF4F6477)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF5F6E84),
              height: 1.4,
            ),
          ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECEF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2C3E50),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
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
