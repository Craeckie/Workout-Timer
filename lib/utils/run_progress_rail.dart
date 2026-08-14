import 'package:flutter/material.dart';

import 'run_plan.dart';

/// segmented progress rail: one segment per exercise, width proportional to
/// its duration, with a small gap where a set repeats and a divider where
/// the workout moves to the next set. Display only, not interactive.
class RunProgressRail extends StatelessWidget {
  const RunProgressRail({
    super.key,
    required this.plan,
    required this.elapsedSeconds,
    this.height = 6,
  });

  final RunPlan plan;

  /// seconds elapsed since the workout's first exercise started (excludes
  /// the countdown lead-in)
  final int elapsedSeconds;

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _RunProgressRailPainter(
            plan: plan,
            elapsedSeconds: elapsedSeconds,
            filledColor: scheme.secondary,
            trackColor: scheme.secondaryContainer,
            dividerColor: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
      ),
    );
  }
}

class _RunProgressRailPainter extends CustomPainter {
  _RunProgressRailPainter({
    required this.plan,
    required this.elapsedSeconds,
    required this.filledColor,
    required this.trackColor,
    required this.dividerColor,
  });

  final RunPlan plan;
  final int elapsedSeconds;
  final Color filledColor;
  final Color trackColor;
  final Color dividerColor;

  static const double _repGap = 2;
  static const double _setDividerWidth = 2;
  static const double _minSegmentWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final steps = plan.steps;
    final totalDuration = plan.totalDuration;
    if (steps.isEmpty || totalDuration == 0) return;

    var gapWidth = 0.0;
    for (final step in steps) {
      switch (step.boundary) {
        case StepBoundary.newRep:
          gapWidth += _repGap;
        case StepBoundary.newSet:
          gapWidth += _setDividerWidth;
        case StepBoundary.none:
          break;
      }
    }

    final availableWidth = (size.width - gapWidth).clamp(0.0, size.width);
    if (availableWidth <= 0) return;

    final rawWidths = steps
        .map((step) => availableWidth * step.exercise.duration / totalDuration)
        .toList(growable: false);

    final isBelowMin =
        rawWidths.map((w) => w < _minSegmentWidth).toList(growable: false);
    final reserved = isBelowMin.where((b) => b).length * _minSegmentWidth;
    final aboveSum = [
      for (var i = 0; i < rawWidths.length; i++)
        if (!isBelowMin[i]) rawWidths[i],
    ].fold(0.0, (sum, w) => sum + w);

    final remaining = (availableWidth - reserved).clamp(0.0, availableWidth);
    final scale = aboveSum > 0 ? remaining / aboveSum : 0.0;

    final widths = List<double>.generate(
      rawWidths.length,
      (i) => isBelowMin[i] ? _minSegmentWidth : rawWidths[i] * scale,
    );

    final filledPaint = Paint()..color = filledColor;
    final trackPaint = Paint()..color = trackColor;
    final dividerPaint = Paint()..color = dividerColor;

    var x = 0.0;
    var elapsedRemaining = elapsedSeconds.toDouble();

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      switch (step.boundary) {
        case StepBoundary.newRep:
          x += _repGap;
        case StepBoundary.newSet:
          canvas.drawRect(
            Rect.fromLTWH(x, 0, _setDividerWidth, size.height),
            dividerPaint,
          );
          x += _setDividerWidth;
        case StepBoundary.none:
          break;
      }

      final width = widths[i];
      final duration = step.exercise.duration;
      final elapsedInSegment =
          duration == 0 ? 0.0 : elapsedRemaining.clamp(0.0, duration.toDouble());
      elapsedRemaining -= duration;

      canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), trackPaint);
      final filledWidth = duration == 0 ? 0.0 : width * elapsedInSegment / duration;
      if (filledWidth > 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, filledWidth, size.height),
          filledPaint,
        );
      }

      x += width;
    }
  }

  @override
  bool shouldRepaint(covariant _RunProgressRailPainter oldDelegate) =>
      oldDelegate.plan != plan ||
      oldDelegate.elapsedSeconds != elapsedSeconds ||
      oldDelegate.filledColor != filledColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.dividerColor != dividerColor;
}
