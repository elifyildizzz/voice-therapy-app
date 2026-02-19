import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'warmup_exercise.dart';

class WarmupVideoScreen extends StatelessWidget {
  const WarmupVideoScreen({
    super.key,
    required this.exercise,
  });

  final WarmupExercise exercise;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.titleTr),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppTheme.darkBlue,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 84,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              exercise.titleEn,
              style: const TextStyle(fontSize: 18, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            const Text(
              'Video içerikleri hazır olduğunda bu alana gerçek oynatıcı eklenecek.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
