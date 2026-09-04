/// The badge medallion, and the tier colours it is drawn in.
///
/// Shared by the grid tile, the detail sheet and the unlock celebration so a
/// badge looks like the same object wherever it appears — the celebration is
/// only convincing if the thing that scales into view is recognisably the tile
/// the user will later find on the badges screen.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/badge_catalogue.dart';
import 'session_chips.dart' show badgeIconData;

/// The colour a tier is drawn in.
///
/// An extension rather than a field on [BadgeTier] because the catalogue is
/// pure data with no Flutter dependency — the database imports it.
extension BadgeTierVisuals on BadgeTier {
  Color get color => switch (this) {
    BadgeTier.bronze => OneRepColors.bronze,
    BadgeTier.silver => OneRepColors.silver,
    BadgeTier.gold => OneRepColors.gold,
    BadgeTier.platinum => OneRepColors.platinum,
  };
}

/// A badge's icon in a tinted, rounded frame.
///
/// The frame doubles as the progress indicator: when [progress] is given, its
/// border fills clockwise from the top rather than sitting inside a separate
/// ring. A ring around a rounded square reads as two shapes fighting; a border
/// that fills reads as one object being completed.
class BadgeMedallion extends StatelessWidget {
  const BadgeMedallion({
    super.key,
    required this.badge,
    required this.earned,
    this.size = 52,
    this.progress,
    this.shine,
  });

  final BadgeDefinition badge;
  final bool earned;
  final double size;

  /// Completion in 0..1, drawn around the frame. Null draws a plain border —
  /// which is what an earned badge and a badge with no meaningful halfway
  /// point both want.
  final double? progress;

  /// Sweep position of the highlight, in 0..1. Values outside that range draw
  /// nothing, which lets a caller animate past the end and stop.
  final double? shine;

  double get _radius => size * 0.27;

  @override
  Widget build(BuildContext context) {
    final tint = badge.tier.color;
    final sweep = shine;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fill and icon, clipped so the shine cannot escape the frame.
          ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: earned
                      ? tint.withValues(alpha: 0.15)
                      : OneRepColors.surfaceElevated,
                ),
                Center(
                  child: Icon(
                    badgeIconData(badge.icon),
                    size: size * 0.5,
                    color: earned ? tint : OneRepColors.textDisabled,
                  ),
                ),
                if (earned && sweep != null && sweep >= 0 && sweep <= 1)
                  _Shine(position: sweep, tint: tint),
              ],
            ),
          ),

          // Border, or the progress arc that replaces it.
          CustomPaint(
            painter: _FramePainter(
              radius: _radius,
              progress: progress,
              earned: earned,
              tint: tint,
            ),
          ),
        ],
      ),
    );
  }
}

/// A diagonal highlight travelling left to right across the medallion.
class _Shine extends StatelessWidget {
  const _Shine({required this.position, required this.tint});

  final double position;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Travel from fully off the left edge to fully off the right.
        final dx = (position * 2.4 - 0.7) * width;

        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: 0.35,
            child: Container(
              width: width * 0.34,
              height: constraints.maxHeight * 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tint.withValues(alpha: 0),
                    tint.withValues(alpha: 0.55),
                    tint.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws the medallion's frame, filling it clockwise when there is progress.
class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.radius,
    required this.progress,
    required this.earned,
    required this.tint,
  });

  final double radius;
  final double? progress;
  final bool earned;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = earned ? 1.5 : 2.0;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(stroke / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = earned
          ? tint.withValues(alpha: 0.4)
          : OneRepColors.surfaceHighest;

    final path = Path()..addRRect(rect);
    canvas.drawPath(path, track);

    final fraction = progress;
    if (fraction == null || fraction <= 0) return;

    // Trace the frame from top-centre clockwise, so a nearly-complete badge
    // reads as a nearly-closed loop.
    final metric = path.computeMetrics().first;
    final length = metric.length;
    final start = length * 0.125; // top-centre on a rounded rect
    final travelled = length * fraction.clamp(0.0, 1.0);

    final arc = Path();
    if (start + travelled <= length) {
      arc.addPath(metric.extractPath(start, start + travelled), Offset.zero);
    } else {
      arc.addPath(metric.extractPath(start, length), Offset.zero);
      arc.addPath(
        metric.extractPath(0, start + travelled - length),
        Offset.zero,
      );
    }

    canvas.drawPath(
      arc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = tint.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.progress != progress ||
      old.earned != earned ||
      old.tint != tint ||
      old.radius != radius;
}
