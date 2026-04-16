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
  List<_InfoCardData> _cards = _defaultCards;
  VocalHygieneTopic? _expandedTopic;
  Set<VocalHygieneTopic> _importantTopics = <VocalHygieneTopic>{};

  static const List<_InfoCardData> _defaultCards = <_InfoCardData>[
    _InfoCardData(
      topic: VocalHygieneTopic.hydration,
      icon: Icons.water_drop_outlined,
      title: 'Hidrasyon',
      description:
          'Gün boyu su tüketimini yay. Düşük hidrasyon ses tellerinde kuruluğu artırır.',
      tips: <String>[
        'Gün içinde aralıklı su iç; uzun süre susuz kalma.',
        'Kafeinli içecek tükettiğinde su ile dengelemeyi unutma.',
        'Kuru ortamlarda su alımını artır ve nem desteği kullan.',
      ],
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.nutrition,
      icon: Icons.restaurant_outlined,
      title: 'Beslenme',
      description:
          'Asitli, çok baharatlı ve yüksek kafeinli alışkanlıkları dengele. Beslenme ses konforunu etkiler.',
      tips: <String>[
        'Geç saatte ağır, yağlı ve baharatlı öğünlerden kaçın.',
        'Asitli ve gazlı içecekleri sınırlayarak tahrişi azalt.',
        'Ses kullanımından önce çok sıcak veya çok soğuk tüketimleri azalt.',
      ],
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.voiceUsage,
      icon: Icons.record_voice_over_outlined,
      title: 'Ses Kullanımı',
      description:
          'Uzun konuşmalarda tonu zorlamadan nefes destekli konuş. Sesi ani yükseltmekten kaçın.',
      tips: <String>[
        'Konuşurken diyafram desteği kullan ve orta şiddette kal.',
        'Uzun konuşmalarda kısa sessizlik molaları planla.',
        'Gürültülü ortamda bağırmak yerine kaynağa yaklaşmayı tercih et.',
      ],
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.environmentalFactors,
      icon: Icons.air_outlined,
      title: 'Çevresel Faktörler',
      description:
          'Kuru, tozlu ve gürültülü ortamlarda sesi korumak için mola ve ortam düzenlemesi yap.',
      tips: <String>[
        'Kuru ortamda nemlendirici kullanarak boğaz kuruluğunu azalt.',
        'Klima veya ısıtıcıya doğrudan maruziyeti sınırla.',
        'Tozlu ve gürültülü ortamlarda sesini zorlamamaya dikkat et.',
      ],
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.irritants,
      icon: Icons.local_cafe_outlined,
      title: 'Tahriş Ediciler',
      description:
          'Kafein ve sigara dumanı gibi tahriş edicilere maruziyeti azaltmak ses kalitesini destekler.',
      tips: <String>[
        'Sigara dumanı ve kimyasal kokulara maruziyeti mümkün olduğunca azalt.',
        'Yoğun parfüm ve aerosol kullanımında sesini dinlendir.',
        'Tahriş hissi arttığında su tüketip sesi zorlamaya ara ver.',
      ],
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.voiceRest,
      icon: Icons.hotel_outlined,
      title: 'Ses İstirahati',
      description:
          'Ses yorgunluğu dönemlerinde planlı sessizlik molaları vererek toparlanmayı hızlandır.',
      tips: <String>[
        'Yoğun ses kullanımından sonra 5-10 dakikalık sessizlik molası ver.',
        'Dinlenme döneminde fısıltı yerine normal tonda kısa konuş.',
        'Yorgunluk veya hastalıkta ses yükünü geçici olarak azalt.',
      ],
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.throatClearing,
      icon: Icons.local_drink_outlined,
      title: 'Boğaz Temizleme',
      description:
          'Sert boğaz temizleme yerine yudum su, yutkunma veya nazik öksürük tercih et.',
      tips: <String>[
        'Sert boğaz temizleme yerine yutkunma veya yudum suyu tercih et.',
        'İhtiyaç halinde nazik öksürükle boğazı zorlamadan rahatlat.',
        'Tekrarlayan boğaz temizleme alışkanlığını fark edip azalt.',
      ],
    ),
    _InfoCardData(
      topic: VocalHygieneTopic.refluxControl,
      icon: Icons.health_and_safety_outlined,
      title: 'Reflü Kontrolü',
      description:
          'Geç saat yemeklerini azalt, yatmadan önce mideyi zorlamamaya çalış. Reflü sesi etkileyebilir.',
      tips: <String>[
        'Yatmadan en az 2-3 saat önce yemek yemeyi bitirmeye çalış.',
        'Kafein, çikolata ve baharatlı gıdaları tolere edebildiğin düzeyde azalt.',
        'Gece reflü artıyorsa yatışta baş-boyun bölgesini hafif yükselt.',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _expandedTopic = _cards.isNotEmpty ? _cards.first.topic : null;
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
      _expandedTopic = _resolveInitialExpandedTopic(_cards, _importantTopics);
    });
  }

  VocalHygieneTopic? _resolveInitialExpandedTopic(
    List<_InfoCardData> cards,
    Set<VocalHygieneTopic> importantTopics,
  ) {
    for (final card in cards) {
      if (importantTopics.contains(card.topic)) {
        return card.topic;
      }
    }
    return cards.isNotEmpty ? cards.first.topic : null;
  }

  void _toggleTopic(VocalHygieneTopic topic) {
    setState(() {
      _expandedTopic = _expandedTopic == topic ? null : topic;
    });
  }

  void _openOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const VocalHygieneOnboardingScreen(),
      ),
    );
  }

  List<String> _resolveTips(_InfoCardData item) {
    final tips = item.tips;
    if (tips != null && tips.isNotEmpty) {
      return tips;
    }

    for (final defaultCard in _defaultCards) {
      if (defaultCard.topic == item.topic) {
        return defaultCard.tips ?? const <String>[];
      }
    }

    return const <String>[];
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
            const AppTopHeader.withBack(
              title: 'Vokal Hijyen',
              showDivider: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Öneriler cevaplarına göre sıralandı. Öncelikli kartları önce inceleyebilirsin.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: _cards.map((item) {
                        final isImportant =
                            _importantTopics.contains(item.topic);
                        return _TopicAccordionCard(
                          item: item,
                          isImportant: isImportant,
                          isExpanded: _expandedTopic == item.topic,
                          tips: _resolveTips(item),
                          onTap: () => _toggleTopic(item.topic),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _RetakeTestCard(
                      onPressed: _openOnboarding,
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

class _TopicAccordionCard extends StatelessWidget {
  const _TopicAccordionCard({
    required this.item,
    required this.isImportant,
    required this.isExpanded,
    required this.tips,
    required this.onTap,
  });

  final _InfoCardData item;
  final bool isImportant;
  final bool isExpanded;
  final List<String> tips;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isImportant && isExpanded
        ? const Color(0xFFB6C8AA)
        : AppTheme.cardBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EDDB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.icon,
                        color: const Color(0xFF788A59),
                        size: 26,
                      ),
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
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.chevron_right_rounded,
                      color: const Color(0xFF788A59),
                      size: 30,
                    ),
                  ],
                ),
                if (isImportant)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: tips.map((tip) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: Color(0xFF1F2937),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tip,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RetakeTestCard extends StatelessWidget {
  const _RetakeTestCard({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6E4C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analizini Yenile',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.autorenew_rounded,
                  color: Color(0xFF788A59),
                  size: 24,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ses Testi: Verilerini güncel tutmak için testi yenileyebilirsin.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE2EEE3),
                foregroundColor: AppTheme.homeAccent,
                disabledBackgroundColor: const Color(0xFFDCE7D6),
                disabledForegroundColor: AppTheme.homeAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: const Text('Testi Tekrar Çöz'),
            ),
          ),
        ],
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
    this.tips,
  });

  final VocalHygieneTopic topic;
  final IconData icon;
  final String title;
  final String description;
  final List<String>? tips;
}
