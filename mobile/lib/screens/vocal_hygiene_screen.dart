import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vocal_hygiene_personalization.dart';
import '../services/vocal_hygiene_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';
import 'vocal_hygiene_onboarding_screen.dart';

class VocalHygieneScreen extends StatefulWidget {
  const VocalHygieneScreen({
    super.key,
    this.personalizationResult,
  });

  final VocalHygienePersonalizationResult? personalizationResult;

  @override
  State<VocalHygieneScreen> createState() => _VocalHygieneScreenState();
}

class _VocalHygieneScreenState extends State<VocalHygieneScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.88);

  int _currentPage = 0;
  List<_InfoCardData> _cards = _defaultCards;
  Set<VocalHygieneTopic> _importantTopics = <VocalHygieneTopic>{};
  Map<VocalHygieneTopic, int> _scores = <VocalHygieneTopic, int>{};

  static const List<_InfoCardData> _defaultCards = <_InfoCardData>[
    _InfoCardData(
      topic: VocalHygieneTopic.hydration,
      icon: Icons.water_drop_outlined,
      title: 'Hidrasyon',
      description:
          'Gün boyu su tüketimini yay. Düşük hidrasyon ses tellerinde kuruluğu artırır.',
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.nutrition,
      icon: Icons.restaurant_outlined,
      title: 'Beslenme',
      description:
          'Asitli, çok baharatlı ve yüksek kafeinli alışkanlıkları dengele. Beslenme ses konforunu etkiler.',
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.voiceUsage,
      icon: Icons.record_voice_over_outlined,
      title: 'Ses Kullanımı',
      description:
          'Uzun konuşmalarda tonu zorlamadan nefes destekli konuş. Sesi ani yükseltmekten kaçın.',
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.environmentalFactors,
      icon: Icons.air_outlined,
      title: 'Çevresel Faktörler',
      description:
          'Kuru, tozlu ve gürültülü ortamlarda sesi korumak için mola ve ortam düzenlemesi yap.',
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.irritants,
      icon: Icons.local_cafe_outlined,
      title: 'Tahriş Ediciler',
      description:
          'Kafein ve sigara dumanı gibi tahriş edicilere maruziyeti azaltmak ses kalitesini destekler.',
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.voiceRest,
      icon: Icons.hotel_outlined,
      title: 'Ses İstirahati',
      description:
          'Ses yorgunluğu dönemlerinde planlı sessizlik molaları vererek toparlanmayı hızlandır.',
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.throatClearing,
      icon: Icons.local_drink_outlined,
      title: 'Boğaz Temizleme',
      description:
          'Sert boğaz temizleme yerine yudum su, yutkunma veya nazik öksürük tercih et.',
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.refluxControl,
      icon: Icons.health_and_safety_outlined,
      title: 'Reflü Kontrolü',
      description:
          'Geç saat yemeklerini azalt, yatmadan önce mideyi zorlamamaya çalış. Reflü sesi etkileyebilir.',
    ),
  ];

  static const List<_CategoryData> _defaultCategories = <_CategoryData>[
    _CategoryData(
      title: 'Beslenme',
      relatedTopics: <VocalHygieneTopic>[
        VocalHygieneTopic.hydration,
        VocalHygieneTopic.nutrition,
        VocalHygieneTopic.irritants,
        VocalHygieneTopic.refluxControl,
      ],
      items: <String>[
        'Reflü dostu beslenmeye yönel; geç saatte ağır yemeklerden kaçın.',
        'Günlük su tüketimini gün içine yayarak ses tellerinin nemini koru.',
        'Yüksek kafein tüketimini kademeli azaltarak vokal tahrişi düşür.',
      ],
    ),
    _CategoryData(
      title: 'Ses Kullanımı',
      relatedTopics: <VocalHygieneTopic>[
        VocalHygieneTopic.voiceUsage,
        VocalHygieneTopic.voiceRest,
        VocalHygieneTopic.throatClearing,
      ],
      items: <String>[
        'Uzun konuşmalarda sesini zorlamadan, diyafram destekli nefesle konuş.',
        'Yoğun ses kullanımından sonra kısa sessizlik molaları planla.',
        'Boğaz temizleme refleksi yerine su yudumlama ve yutkunmayı dene.',
      ],
    ),
    _CategoryData(
      title: 'Çevresel Faktörler',
      relatedTopics: <VocalHygieneTopic>[
        VocalHygieneTopic.environmentalFactors,
        VocalHygieneTopic.irritants,
      ],
      items: <String>[
        'Gürültülü ortamlarda sesi yükseltmek yerine ortama yaklaşmayı tercih et.',
        'Kuru ortamlarda hava nemini artırarak boğaz kuruluğunu azalt.',
        'Sigara dumanı ve kimyasal kokulara maruziyeti mümkün olduğunca sınırla.',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _applyInitialPersonalization();
  }

  Future<void> _applyInitialPersonalization() async {
    final initialResult = widget.personalizationResult;
    if (initialResult != null) {
      _applyPersonalization(initialResult);
      return;
    }

    final latestResponse =
        await VocalHygieneRepository.instance.fetchLatestResponse();
    if (!mounted || latestResponse == null) {
      return;
    }

    final computed = VocalHygienePersonalizer.evaluate(latestResponse);
    _applyPersonalization(computed);
  }

  void _applyPersonalization(VocalHygienePersonalizationResult result) {
    final cardsByTopic = <VocalHygieneTopic, _InfoCardData>{
      for (final card in _defaultCards) card.topic: card,
    };

    final ordered = <_InfoCardData>[];
    for (final topic in result.orderedTopics) {
      final card = cardsByTopic[topic];
      if (card != null) {
        ordered.add(card);
      }
    }

    setState(() {
      _cards = ordered.isEmpty ? _defaultCards : ordered;
      _importantTopics = result.importantTopics;
      _scores = result.scores;
      _currentPage = 0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderedCategories = List<_CategoryData>.from(_defaultCategories)
      ..sort((a, b) {
        final aScore = a.relatedTopics.fold<int>(
          0,
          (sum, topic) => sum + (_scores[topic] ?? 0),
        );
        final bScore = b.relatedTopics.fold<int>(
          0,
          (sum, topic) => sum + (_scores[topic] ?? 0),
        );
        final byScore = bScore.compareTo(aScore);
        if (byScore != 0) {
          return byScore;
        }
        return _defaultCategories.indexOf(a).compareTo(
              _defaultCategories.indexOf(b),
            );
      });

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Column(
          children: [
            const AppTopHeader.withBack(
              title: 'Vokal Hijyen',
              showDivider: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            'Öneriler cevaplarına göre sıralandı. Öncelikli kartları önce inceleyebilirsin.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const VocalHygieneOnboardingScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            foregroundColor: AppTheme.homeAccent,
                            side: const BorderSide(color: AppTheme.cardBorder),
                          ),
                          child: const Text('Testi Tekrar Çöz'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 196,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _cards.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = _cards[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _InfoCard(
                            item: item,
                            isImportant: _importantTopics.contains(item.topic),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PaginationDots(
                    count: _cards.length,
                    currentIndex: _currentPage,
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: orderedCategories.map((category) {
                        final isImportantCategory = category.relatedTopics.any(
                          _importantTopics.contains,
                        );
                        return _CategoryCard(
                          category: category,
                          isImportant: isImportantCategory,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.item,
    required this.isImportant,
  });

  final _InfoCardData item;
  final bool isImportant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isImportant ? const Color(0xFFC5D5BE) : AppTheme.cardBorder,
          width: isImportant ? 1.6 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImportant)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.soft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Senin için önemli',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.homeAccent,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: AppTheme.homeAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaginationDots extends StatelessWidget {
  const _PaginationDots({
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentIndex == index ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: currentIndex == index
                ? AppTheme.homeAccent
                : const Color(0xFFCAD0DA),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _InfoCardData {
  const _InfoCardData({
    required this.topic,
    required this.icon,
    required this.title,
    required this.description,
  });

  final VocalHygieneTopic topic;
  final IconData icon;
  final String title;
  final String description;
}

class _CategoryData {
  const _CategoryData({
    required this.title,
    required this.relatedTopics,
    required this.items,
  });

  final String title;
  final List<VocalHygieneTopic> relatedTopics;
  final List<String> items;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.isImportant,
  });

  final _CategoryData category;
  final bool isImportant;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isImportant ? const Color(0xFFC5D5BE) : AppTheme.cardBorder,
          width: isImportant ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImportant)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.soft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Senin için önemli',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.homeAccent,
                ),
              ),
            ),
          Text(
            category.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...category.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $item',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
