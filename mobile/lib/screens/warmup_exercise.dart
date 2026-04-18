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
    this.videoCropTopFraction = 0,
    this.videoCropHeightFraction = 1,
    this.thumbnailAssetPath,
    this.iconAssetPath,
    this.durationLabel,
    this.howToText,
    this.measurementInstruction,
    this.supportsMeasurement = false,
  });

  final String titleTr;
  final String titleEn;
  final int durationMinutes;
  final String level;
  final Color levelColor;
  final Color levelTextColor;
  final String? videoAssetPath;
  final double videoCropTopFraction;
  final double videoCropHeightFraction;
  final String? thumbnailAssetPath;
  final String? iconAssetPath;
  final String? durationLabel;
  final String? howToText;
  final String? measurementInstruction;
  final bool supportsMeasurement;
}
