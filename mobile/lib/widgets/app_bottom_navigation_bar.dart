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
      label: 'Ön Tarama',
      semanticLabel: 'Ses Sağlığı Ön Tarama Testi',
      icon: Icons.multitrack_audio_outlined,
      activeIcon: Icons.multitrack_audio_rounded,
    ),
    _BottomNavigationItemData(
      label: 'Ana Sayfa',
      semanticLabel: 'Ana sayfa',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
  ];

  static const List<_BottomNavigationItemData> _authenticatedItems = [
    _BottomNavigationItemData(
      label: 'Ön Tarama',
      semanticLabel: 'Ses Sağlığı Ön Tarama Testi',
      icon: Icons.multitrack_audio_outlined,
      activeIcon: Icons.multitrack_audio_rounded,
    ),
    _BottomNavigationItemData(
      label: 'Ana Sayfa',
      semanticLabel: 'Ana sayfa',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _BottomNavigationItemData(
      label: 'Profil',
      semanticLabel: 'Profil',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = AuthService.instance.currentUser != null;
    final items = isAuthenticated ? _authenticatedItems : _guestItems;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: const Border(top: BorderSide(color: AppTheme.cardBorder)),
        boxShadow: AppTheme.softShadow,
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
    const selectedColor = AppTheme.homeAccent;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 24,
                color: isSelected ? selectedColor : AppTheme.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.fade,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? selectedColor : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationItemData {
  const _BottomNavigationItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String semanticLabel;
}
