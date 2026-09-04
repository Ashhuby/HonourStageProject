/// The badge grid tile and the "next up" row.
///
/// Both exist to answer the question the old screen could not: a locked badge
/// rendered at 35% opacity behind a padlock says only that you have not earned
/// it, which the user already knew. These say how far in you are.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/badge_service.dart';
import '../../data/badge_stats.dart';
import 'badge_visuals.dart';

/// One badge in the grid.
class BadgeTile extends StatelessWidget {
  const BadgeTile({
    super.key,
    required this.badge,
    required this.stats,
    required this.entrance,
    this.onTap,
  });

  final BadgeViewModel badge;

  /// The stats snapshot, used to draw progress on locked tiles. Null while it
  /// is still loading — the tile renders without a ring rather than flashing a
  /// zero.
  final BadgeStats? stats;

  /// Staggered entrance in 0..1: 0 hides the tile, 1 seats it.
  final double entrance;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final earned = badge.isEarned;
    final tint = badge.tier.color;
    final snapshot = stats;

    final showRing =
        !earned && badge.definition.showsProgress && snapshot != null;
    final fraction = showRing
        ? progressFractionFor(badge.definition, snapshot)
        : null;

    return Opacity(
      // Locked tiles stay dimmed, but not as far as before: a tile carrying a
      // real number is worth reading, and 35% was too faint to read it at.
      opacity: (earned ? 1.0 : 0.62) * entrance.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - entrance.clamp(0.0, 1.0))),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: OneRepColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: earned
                    ? tint.withValues(alpha: 0.4)
                    : OneRepColors.surfaceElevated,
                width: earned ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BadgeMedallion(
                    badge: badge.definition,
                    earned: earned,
                    progress: fraction,
                    // The shine sweeps once as the tile arrives. A permanent
                    // shimmer on three dozen tiles is a repaint every frame
                    // for an effect nobody is looking at by then.
                    shine: earned ? (entrance - 0.25) / 0.6 : null,
                  ),
                  const SizedBox(height: 10),

                  Text(
                    badge.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: earned
                          ? OneRepColors.textPrimary
                          : OneRepColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  _TileFooter(
                    badge: badge,
                    stats: snapshot,
                    showRing: showRing,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The earned date, the progress figure, or a padlock.
class _TileFooter extends StatelessWidget {
  const _TileFooter({
    required this.badge,
    required this.stats,
    required this.showRing,
  });

  final BadgeViewModel badge;
  final BadgeStats? stats;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final earnedAt = badge.earnedAt;
    if (earnedAt != null) {
      return Text(
        formatShortDate(earnedAt),
        style: TextStyle(
          color: badge.tier.color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final snapshot = stats;
    if (showRing && snapshot != null) {
      final progress = progressFor(badge.definition, snapshot);
      final stat = badge.definition.stat;
      return Text(
        stat.formatPair(progress.current, progress.target, compact: true),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: OneRepColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return const Icon(
      Icons.lock_outline,
      size: 13,
      color: OneRepColors.textDisabled,
    );
  }
}

// ---------------------------------------------------------------------------
// Next up
// ---------------------------------------------------------------------------

/// A badge the user is close to, as a full-width row with a bar.
///
/// The grid shows every badge at the same size regardless of how near it is;
/// this is the one place the screen has an opinion about what to do next.
class BadgeNextUpRow extends StatelessWidget {
  const BadgeNextUpRow({
    super.key,
    required this.badge,
    required this.stats,
    this.onTap,
  });

  final BadgeViewModel badge;
  final BadgeStats stats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = badge.tier.color;
    final progress = progressFor(badge.definition, stats);
    final fraction = progressFractionFor(badge.definition, stats);
    final stat = badge.definition.stat;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: OneRepColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: tint, width: 3)),
        ),
        child: Row(
          children: [
            BadgeMedallion(
              badge: badge.definition,
              earned: false,
              size: 40,
              progress: fraction,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    badge.name,
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 5,
                      backgroundColor: OneRepColors.surfaceHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(tint),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stat.formatPair(progress.current, progress.target),
                    style: const TextStyle(
                      color: OneRepColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(fraction * 100).round()}%',
              style: TextStyle(
                color: tint,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
