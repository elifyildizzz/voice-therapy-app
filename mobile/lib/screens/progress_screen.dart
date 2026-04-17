import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({
    required this.onBackPressed,
    super.key,
  });

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          AppTopHeader.withBack(
            title: 'İlerleme',
            showDivider: true,
            onBackPressed: onBackPressed,
          ),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
