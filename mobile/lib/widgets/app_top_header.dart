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
    VoidCallback? onBackPressed,
    Key? key,
  }) : this._(
          title: title,
          onBackPressed: onBackPressed,
          showBackButton: true,
          key: key,
        );

  static const double _homeBodyHeight = 154;
  static const double _backBodyHeight = 126;

  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bodyHeight = showBackButton ? _backBodyHeight : _homeBodyHeight;
    final topPadding = showBackButton ? topInset + 8 : topInset + 10;
    final bottomPadding = showBackButton ? 12.0 : 14.0;

    return Container(
      width: double.infinity,
      height: topInset + bodyHeight,
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      decoration: const BoxDecoration(
        color: AppTheme.darkBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: showBackButton ? _buildBackHeader(context) : _buildHomeHeader(),
    );
  }

  Widget _buildBackHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onBackPressed ?? () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(
            width: 40,
            height: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildHomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 34),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle!,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
