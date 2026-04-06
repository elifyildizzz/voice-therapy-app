import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppTopHeader extends StatelessWidget {
  const AppTopHeader._({
    required this.title,
    required this.showBackButton,
    this.subtitle,
    this.onBackPressed,
    super.key,
  });

  const AppTopHeader.home({
    required String title,
    required String subtitle,
    Key? key,
  }) : this._(
          title: title,
          subtitle: subtitle,
          showBackButton: false,
          key: key,
        );

  const AppTopHeader.withBack({
    required String title,
    String? subtitle,
    VoidCallback? onBackPressed,
    Key? key,
  }) : this._(
          title: title,
          subtitle: subtitle,
          onBackPressed: onBackPressed,
          showBackButton: true,
          key: key,
        );

  static const double _homeBodyHeight = 168;
  static const double _backBodyHeight = 138;

  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bodyHeight = showBackButton ? _backBodyHeight : _homeBodyHeight;
    final topPadding = showBackButton ? topInset + 8 : topInset + 12;
    final bottomPadding = showBackButton ? 16.0 : 20.0;

    return Container(
      width: double.infinity,
      height: topInset + bodyHeight,
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary,
            AppTheme.light,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: showBackButton
          ? _BackHeaderContent(
              title: title,
              subtitle: subtitle,
              onBackPressed: onBackPressed ?? () => Navigator.of(context).pop(),
            )
          : _HomeHeaderContent(
              title: title,
              subtitle: subtitle ?? '',
            ),
    );
  }
}

class _HomeHeaderContent extends StatelessWidget {
  const _HomeHeaderContent({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFFE6EFEA),
            fontSize: 14,
            height: 1.42,
          ),
        ),
      ],
    );
  }
}

class _BackHeaderContent extends StatelessWidget {
  const _BackHeaderContent({
    required this.title,
    required this.onBackPressed,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onBackPressed,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  'Geri',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              color: Color(0xFFE6EFEA),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
