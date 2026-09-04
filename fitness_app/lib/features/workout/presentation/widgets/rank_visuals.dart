/// The rank crest, and the colours a rank is drawn in.
///
/// A hexagon rather than the rounded square [BadgeMedallion] uses, because the
/// two sit next to each other in the badges header and one summarises the
/// other — if they shared a silhouette the rank would read as just another
/// badge. The silhouette is also what carries the rank down to the sixteen
/// pixels the nav bar allows, where the numeral is dropped and the colour has
/// to do the work alone.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/rank.dart';

/// The colour a rank is drawn in.
///
/// An extension rather than a field on [Rank] because the ladder is pure data
/// with no Flutter dependency — the award path reads it without importing any
/// of this.
extension RankVisuals on Rank {
  Color get color => switch (this) {
    Rank.sand => OneRepColors.sand,
    Rank.pebble => OneRepColors.pebble,
    Rank.stone => OneRepColors.stone,
    Rank.boulder => OneRepColors.boulder,
    Rank.cliff => OneRepColors.cliff,
    Rank.mountain => OneRepColors.mountain,
  };
}

/// A rank's numeral inside a tinted hexagon.
class RankCrest extends StatelessWidget {
  const RankCrest({
    super.key,
    required this.rank,
    this.size = 56,
    this.progress,
    this.glow = false,
    this.showNumeral = true,
  });

  final Rank rank;
  final double size;

  /// Whether to draw the numeral. Off below roughly twenty pixels, where
  /// "VI" is a smudge — the crest there is a colour and a shape, and the name
  /// is one tap away.
  final bool showNumeral;

  /// Progress towards the next rank in 0..1, traced around the hexagon. The
  /// border fills rather than a separate ring sitting outside it, matching
  /// [BadgeMedallion]. Null draws a plain border.
  final double? progress;

  /// Whether to cast a soft halo in the rank's colour. Used where the crest
  /// is the subject — the celebration — and not where it is a label.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final tint = rank.color;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: tint.withValues(alpha: 0.35),
                    blurRadius: size * 0.5,
                    spreadRadius: size * 0.05,
                  ),
                ]
              : null,
        ),
        child: CustomPaint(
          painter: _CrestPainter(tint: tint, progress: progress),
          child: showNumeral
              ? Center(
                  child: Text(
                    rank.numeral,
                    style: TextStyle(
                      color: tint,
                      // Sized off the crest so the numeral holds its
                      // proportions from the header to the celebration.
                      fontSize: size * (rank.numeral.length > 2 ? 0.30 : 0.36),
                      fontWeight: FontWeight.w800,
                      letterSpacing: size * 0.02,
                      height: 1,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// The hexagon: a tinted fill, and a border that doubles as the progress arc.
class _CrestPainter extends CustomPainter {
  const _CrestPainter({required this.tint, required this.progress});

  final Color tint;
  final double? progress;

  /// A pointy-top hexagon inscribed in [size].
  Path _hexagon(Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 1;
    final path = Path();

    for (var i = 0; i < 6; i++) {
      // Start at the top and work clockwise, so the progress arc begins where
      // the eye does.
      final angle = -math.pi / 2 + i * math.pi / 3;
      final point = centre + Offset(math.cos(angle), math.sin(angle)) * radius;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final hex = _hexagon(size);

    canvas.drawPath(hex, Paint()..color = tint.withValues(alpha: 0.14));

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      // Floored rather than purely proportional: at nav-bar size a hairline
      // border disappears against the surface behind it.
      ..strokeWidth = math.max(1.2, size.width * 0.035)
      ..strokeCap = StrokeCap.round;

    final fraction = progress;
    if (fraction == null) {
      canvas.drawPath(hex, stroke..color = tint.withValues(alpha: 0.55));
      return;
    }

    // The unfilled remainder stays visible so the shape survives at 0%.
    canvas.drawPath(hex, stroke..color = tint.withValues(alpha: 0.18));
    if (fraction <= 0) return;

    final metric = hex.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * fraction.clamp(0.0, 1.0)),
      stroke..color = tint,
    );
  }

  @override
  bool shouldRepaint(_CrestPainter old) =>
      old.tint != tint || old.progress != progress;
}
