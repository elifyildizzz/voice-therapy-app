import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/client_form_record.dart';
import '../models/sz_test_record.dart';
import '../services/client_form_repository.dart';
import '../services/sz_test_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
import '../widgets/client_form_record_card.dart';
import '../widgets/sz_test_record_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<_ProfileHistoryData> _loadHistory() async {
    final clientFormRecords =
        await ClientFormRepository.instance.fetchRecords();
    final szTestRecords = await SzTestRepository.instance.fetchRecords();

    return _ProfileHistoryData(
      clientFormRecords: clientFormRecords,
      szTestRecords: szTestRecords,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            const AppTopHeader.home(
              title: 'Profil',
              subtitle:
                  'Danışan formu ve S/Z test geçmişinizi buradan takip edin.',
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  ClientFormRepository.instance.changes,
                  SzTestRepository.instance.changes,
                ]),
                builder: (context, _) {
                  return FutureBuilder<_ProfileHistoryData>(
                    future: _loadHistory(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final history = snapshot.data ??
                          const _ProfileHistoryData(
                            clientFormRecords: <ClientFormRecord>[],
                            szTestRecords: <SzTestRecord>[],
                          );

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                        children: [
                          const _ProfileSectionIntro(
                            title: 'Danışan Bilgi Formu Geçmişi',
                            description:
                                'Form sonuçlarınızı tarih, toplam puan ve sonuç etiketi ile burada görebilirsiniz.',
                          ),
                          const SizedBox(height: 14),
                          if (history.clientFormRecords.isEmpty)
                            const _EmptyHistoryCard(
                              icon: Icons.assignment_outlined,
                              message:
                                  'Danışan Bilgi Formu sonuçları burada listelenecek.',
                            )
                          else
                            ...history.clientFormRecords.map(
                              (record) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ClientFormRecordCard(
                                  title: 'Kayıt #${record.id ?? '-'}',
                                  record: record,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          const _ProfileSectionIntro(
                            title: 'S/Z Test Geçmişi',
                            description:
                                'S/Z oranı testi sonuçlarınızı tarih, süre ve oran bilgileriyle burada izleyebilirsiniz.',
                          ),
                          const SizedBox(height: 14),
                          if (history.szTestRecords.isEmpty)
                            const _EmptyHistoryCard(
                              icon: Icons.mic_none_rounded,
                              message:
                                  'S/Z oranı testi sonuçları burada listelenecek.',
                            )
                          else
                            ...history.szTestRecords.map(
                              (record) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: SzTestRecordCard(
                                  title: 'Kayıt #${record.id ?? '-'}',
                                  record: record,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHistoryData {
  const _ProfileHistoryData({
    required this.clientFormRecords,
    required this.szTestRecords,
  });

  final List<ClientFormRecord> clientFormRecords;
  final List<SzTestRecord> szTestRecords;
}

class _ProfileSectionIntro extends StatelessWidget {
  const _ProfileSectionIntro({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF5F6E84),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 46,
            color: AppTheme.darkBlue,
          ),
          const SizedBox(height: 12),
          const Text(
            'Henüz kayıt bulunmuyor.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF5F6E84),
            ),
          ),
        ],
      ),
    );
  }
}
