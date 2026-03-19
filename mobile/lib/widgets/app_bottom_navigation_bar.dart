import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  static const List<_BottomNavigationItemData> _items = [
    _BottomNavigationItemData(
      icon: Icons.medical_services_outlined,
      activeIcon: Icons.medical_services,
      semanticLabel: 'Ses Sağlığı Ön Tarama Testi',
    ),
    _BottomNavigationItemData(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      semanticLabel: 'Ana sayfa',
    ),
    _BottomNavigationItemData(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      semanticLabel: 'Profil',
    ),
  ];

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset + 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(
          _items.length,
          (index) => Expanded(
            child: _BottomNavigationAction(
              item: _items[index],
              isSelected: currentIndex == index,
              onTap: () => onTap(index),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationAction extends StatelessWidget {
  const _BottomNavigationAction({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _BottomNavigationItemData item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: item.semanticLabel,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Icon(
              isSelected ? item.activeIcon : item.icon,
              size: 29,
            color: isSelected ? AppTheme.darkBlue : const Color(0xFF7D7D7D),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationItemData {
  const _BottomNavigationItemData({
    required this.icon,
    required this.activeIcon,
    required this.semanticLabel,
  });

  final IconData icon;
  final IconData activeIcon;
  final String semanticLabel;
}
