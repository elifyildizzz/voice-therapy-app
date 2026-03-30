import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  static const List<_BottomNavigationItemData> _guestItems = [
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
  ];

  static const List<_BottomNavigationItemData> _authenticatedItems = [
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
    final isAuthenticated = AuthService.instance.currentUser != null;
    final items = isAuthenticated ? _authenticatedItems : _guestItems;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = bottomInset > 4 ? bottomInset - 2 : 6.0;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 2, 24, bottomPadding),
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
          items.length,
          (index) => Expanded(
            child: _BottomNavigationAction(
              item: items[index],
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
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Transform.translate(
            offset: const Offset(0, 2),
            child: Icon(
              isSelected ? item.activeIcon : item.icon,
              size: 27,
              color: isSelected ? AppTheme.darkBlue : const Color(0xFF7D7D7D),
            ),
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
