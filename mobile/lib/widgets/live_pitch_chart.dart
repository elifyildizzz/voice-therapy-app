import 'package:flutter/material.dart';

import '../models/pitch_reading.dart';
import '../theme/app_theme.dart';

class LivePitchChart extends StatelessWidget {
  const LivePitchChart({
    required this.points,
    this.window = const Duration(seconds: 6),
    this.minHz = 60,
    this.maxHz = 500,
    super.key,
  });

  final List<PitchReading> points;
  final Duration window;
  final double minHz;
  final double maxHz;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFBF8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CustomPaint(
                      painter: _LivePitchChartPainter(
                        points: points,
                        now: now,
                        window: window,
                        minHz: minHz,
                        maxHz: maxHz,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 12,
                child: _AxisLabel('${maxHz.toInt()} Hz'),
              ),
              Positioned(
                left: 8,
                top: 102,
                child: _AxisLabel('${((minHz + maxHz) / 2).round()} Hz'),
              ),
              Positioned(
                left: 8,
                bottom: 12,
                child: _AxisLabel('${minHz.toInt()} Hz'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${window.inSeconds} sn önce',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Text(
              'Şimdi',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }
}

class _LivePitchChartPainter extends CustomPainter {
  const _LivePitchChartPainter({
    required this.points,
    required this.now,
    required this.window,
    required this.minHz,
    required this.maxHz,
  });

  final List<PitchReading> points;
  final DateTime now;
  final Duration window;
  final double minHz;
  final double maxHz;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);

    if (points.isEmpty) {
      _paintEmptyState(canvas, size);
      return;
    }

    final windowStart = now.subtract(window);
    final visiblePoints = points
        .where((point) => !point.timestamp.isBefore(windowStart))
        .toList(growable: false);

    if (visiblePoints.every((point) => point.hz == null)) {
      _paintEmptyState(canvas, size);
      return;
    }

    final path = Path();
    Offset? lastOffset;
    Offset? latestReliableOffset;

    for (final point in visiblePoints) {
      final hz = point.hz;
      if (hz == null) {
        lastOffset = null;
        continue;
      }

      final elapsedMs = point.timestamp
          .difference(windowStart)
          .inMilliseconds
          .clamp(0, window.inMilliseconds)
          .toDouble();
      final x = size.width * elapsedMs / window.inMilliseconds;
      final normalized =
          ((hz.clamp(minHz, maxHz) - minHz) / (maxHz - minHz)).clamp(0.0, 1.0);
      final y = size.height - (normalized * size.height);
      final offset = Offset(x, y);

      if (lastOffset == null) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        final controlX = (lastOffset.dx + offset.dx) / 2;
        path.cubicTo(
          controlX,
          lastOffset.dy,
          controlX,
          offset.dy,
          offset.dx,
          offset.dy,
        );
      }

      lastOffset = offset;
      latestReliableOffset = offset;
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.light.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.primary;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    if (latestReliableOffset != null) {
      final pointFill = Paint()..color = AppTheme.primary;
      final pointStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white;

      canvas.drawCircle(latestReliableOffset, 5.5, pointFill);
      canvas.drawCircle(latestReliableOffset, 5.5, pointStroke);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppTheme.cardBorder;

    const horizontalLines = 4;
    const verticalLines = 6;

    for (var index = 1; index < horizontalLines; index += 1) {
      final dy = (size.height / horizontalLines) * index;
      canvas.drawLine(
        Offset(0, dy),
        Offset(size.width, dy),
        gridPaint,
      );
    }

    for (var index = 1; index < verticalLines; index += 1) {
      final dx = (size.width / verticalLines) * index;
      canvas.drawLine(
        Offset(dx, 0),
        Offset(dx, size.height),
        gridPaint,
      );
    }
  }

  void _paintEmptyState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Ses bekleniyor',
        style: TextStyle(
          color: AppTheme.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _LivePitchChartPainter oldDelegate) {
    if (oldDelegate.points.length != points.length) {
      return true;
    }

    if (points.isEmpty) {
      return oldDelegate.now != now;
    }

    final previousLast = oldDelegate.points.last;
    final currentLast = points.last;

    return previousLast.timestamp != currentLast.timestamp ||
        previousLast.hz != currentLast.hz ||
        oldDelegate.now != now;
  }
}
