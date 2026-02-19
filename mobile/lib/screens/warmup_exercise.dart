import 'package:flutter/material.dart';

class WarmupExercise {
  const WarmupExercise({
    required this.titleTr,
    required this.titleEn,
    required this.durationMinutes,
    required this.level,
    required this.levelColor,
    required this.levelTextColor,
  });

  final String titleTr;
  final String titleEn;
  final int durationMinutes;
  final String level;
  final Color levelColor;
  final Color levelTextColor;
}
