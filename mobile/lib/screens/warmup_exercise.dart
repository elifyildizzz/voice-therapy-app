import 'package:flutter/material.dart';

class WarmupExercise {
  const WarmupExercise({
    required this.titleTr,
    required this.titleEn,
    required this.durationMinutes,
    required this.level,
    required this.levelColor,
    required this.levelTextColor,
    this.videoAssetPath,
    this.thumbnailAssetPath,
    this.durationLabel,
  });

  final String titleTr;
  final String titleEn;
  final int durationMinutes;
  final String level;
  final Color levelColor;
  final Color levelTextColor;
  final String? videoAssetPath;
  final String? thumbnailAssetPath;
  final String? durationLabel;
}
