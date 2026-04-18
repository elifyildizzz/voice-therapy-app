import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class AppTopHeader extends StatelessWidget {
  const AppTopHeader._({
    required this.title,
    required this.showBackButton,
    required this.isHomeHeader,
    required this.showDivider,
    this.subtitle,
    this.onBackPressed,
    this.bodyHeight,
    this.bottomPadding,
    this.borderRadius,
    this.homeTitleMaxLines,
    super.key,
  });

  const AppTopHeader.home({
    required String title,
    required String subtitle,
    double? bodyHeight,
    double? bottomPadding,
    BorderRadiusGeometry? borderRadius,
    int? titleMaxLines,
    Key? key,
  }) : this._(
          title: title,
          subtitle: subtitle,
          showBackButton: false,
          isHomeHeader: true,
          showDivider: false,
          bodyHeight: bodyHeight,
          bottomPadding: bottomPadding,
          borderRadius: borderRadius,
          homeTitleMaxLines: titleMaxLines,
          key: key,
        );

  const AppTopHeader.withBack({
    required String title,
    String? subtitle,
    VoidCallback? onBackPressed,
    bool showBackButton = true,
    bool showDivider = false,
    Key? key,
  }) : this._(
          title: title,
          subtitle: subtitle,
          onBackPressed: onBackPressed,
          showBackButton: showBackButton,
          isHomeHeader: false,
          showDivider: showDivider,
          key: key,
        );

  static const double _homeBodyHeight = 152;

  final String title;
  final String? subtitle;
  final bool showBackButton;
  final bool isHomeHeader;
  final bool showDivider;
  final VoidCallback? onBackPressed;
  final double? bodyHeight;
  final double? bottomPadding;
  final BorderRadiusGeometry? borderRadius;
  final int? homeTitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    if (!isHomeHeader) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, topInset + 8, 20, 6),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(color: AppTheme.cardBorder),
                  )
                : null,
          ),
          child: _BackHeaderContent(
            title: title,
            showBackButton: showBackButton,
            onBackPressed: onBackPressed ??
                () {
                  // Avoid popping the root route when this header is used inside
                  // a tab (e.g. VoiceAnalyzeConsentScreen) where there is no stack.
                  Navigator.of(context).maybePop();
                },
          ),
        ),
      );
    }

    final resolvedBodyHeight = bodyHeight ?? _homeBodyHeight;
    final topPadding = topInset + 12;
    final resolvedBottomPadding = bottomPadding ?? 14.0;
    final resolvedBorderRadius = borderRadius ?? BorderRadius.zero;

    return Container(
      width: double.infinity,
      height: topInset + resolvedBodyHeight,
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, resolvedBottomPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.headerStart,
            AppTheme.headerEnd,
          ],
        ),
        borderRadius: resolvedBorderRadius,
      ),
      child: _HomeHeaderContent(
        title: title,
        subtitle: subtitle ?? '',
        titleMaxLines: homeTitleMaxLines ?? 2,
      ),
    );
  }
}

class _HomeHeaderContent extends StatelessWidget {
  const _HomeHeaderContent({
    required this.title,
    required this.subtitle,
    required this.titleMaxLines,
  });

  final String title;
  final String subtitle;
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          title,
          maxLines: titleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFE6EFEA),
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _BackHeaderContent extends StatelessWidget {
  const _BackHeaderContent({
    required this.title,
    required this.showBackButton,
    required this.onBackPressed,
  });

  final String title;
  final bool showBackButton;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBackButton) ...[
          GestureDetector(
            onTap: onBackPressed,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}
