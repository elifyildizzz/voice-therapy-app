import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';

class VocalHygieneScreen extends StatefulWidget {
  const VocalHygieneScreen({super.key});

  @override
  State<VocalHygieneScreen> createState() => _VocalHygieneScreenState();
}

class _VocalHygieneScreenState extends State<VocalHygieneScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  static const List<_InfoCardData> _infoCards = [
    _InfoCardData(
      icon: Icons.water_drop_outlined,
      title: 'Hidrasyon',
      description:
          'Günde en az 2 litre su içmeyi ihmal etme. Ses tellerin nemi sever.',
    ),
    _InfoCardData(
      icon: Icons.local_cafe_outlined,
      title: 'Tahriş Edici Maddeler',
      description:
          'Kafein ve alkol tüketimini sınırla; ses tellerini kurutabilirler.',
    ),
    _InfoCardData(
      icon: Icons.hotel_outlined,
      title: 'Ses İstirahatı',
      description:
          'Günün belirli saatlerinde "sessizlik molaları" ver. Sesini dinlendir.',
    ),
    _InfoCardData(
      icon: Icons.local_drink_outlined,
      title: 'Boğaz Temizleme',
      description:
          'Boğazını sertçe temizlemek yerine bir yudum su içmeyi dene.',
    ),
    _InfoCardData(
      icon: Icons.health_and_safety_outlined,
      title: 'Reflü Kontrolü',
      description:
          'Uykudan en az 3 saat önce yemek yemeyi keserek asit tahrişini önle.',
    ),
  ];

  static const List<_CategoryData> _categories = [
    _CategoryData(
      title: 'Beslenme',
      items: [
        'Reflü dostu diyet planı uygula; baharatlı ve aşırı asitli yiyecekleri azalt.',
        'Hidrasyonu gün içine yay; su içmeyi sadece susadığında değil rutin olarak sürdür.',
        'Ses tellerini kurutabilecek kafeinli içecek ve mentollü ürünleri sınırlı tüket.',
        'Elma gibi su oranı yüksek meyvelerle vokal nemliliği destekle.',
      ],
    ),
    _CategoryData(
      title: 'Ses Kullanımı',
      items: [
        'Doğru konuşma tekniği için göğüs yerine diyafram destekli nefesle konuş.',
        'Bağırmaktan kaçın; gürültülü ortamlarda sesi zorlamak yerine ortama yaklaş.',
        'Fısıldamak da ses tellerini yorabilir, düşük ama doğal bir ton tercih et.',
        'Uzun telefon görüşmelerinde kulaklık kullanarak boyun ve ses yükünü azalt.',
        'Öksürme ve boğaz temizleme refleksini azaltmak için su ile boğazı nemlendir.',
      ],
    ),
    _CategoryData(
      title: 'Çevresel Faktörler',
      items: [
        'Oda nem dengesini koru; kuru dönemlerde hava nemlendirici kullan.',
        'Sigara dumanı ve yoğun kimyasal kokularla doğrudan temastan kaçın.',
        'Gürültülü ortamlarda ses yönetimi yap; uzun süre yüksek sesle konuşma.',
        'Tozlu alanlarda kalma süresini azaltarak ses yolunu tahrişten koru.',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
            const AppTopHeader.withBack(title: 'Vokal Hijyen'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                children: [
                  SizedBox(
                    height: 170,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _infoCards.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = _infoCards[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _InfoCard(item: item),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PaginationDots(
                    count: _infoCards.length,
                    currentIndex: _currentPage,
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: _categories
                          .map((category) => _CategoryCard(category: category))
                          .toList(),
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
  const _InfoCard({required this.item});

  final _InfoCardData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: AppTheme.darkBlue),
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
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Color(0xFF4F4F4F),
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
                ? AppTheme.darkBlue
                : const Color(0xFFCAD0DA),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final _CategoryData category;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
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
          Text(
            category.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1E1E),
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
                  color: Color(0xFF4F4F4F),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCardData {
  const _InfoCardData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _CategoryData {
  const _CategoryData({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;
}
