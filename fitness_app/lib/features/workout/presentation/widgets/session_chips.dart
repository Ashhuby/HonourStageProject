import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/badge_service.dart';
import '../../domain/session_highlights.dart';

/// Maps a badge's icon name to its [IconData].
///
/// Shared with the badges screen rather than duplicated: a badge showing one
/// icon in its chip and another in the trophy cabinet would be worse than no
/// icon at all.
IconData badgeIconData(String name) => switch (name) {
  'fitness_center' => Icons.fitness_center,
  'local_fire_department' => Icons.local_fire_department,
  'emoji_events' => Icons.emoji_events,
  'military_tech' => Icons.military_tech,
  'trending_up' => Icons.trending_up,
  'bolt' => Icons.bolt,
  'workspace_premium' => Icons.workspace_premium,
  'add_circle' => Icons.add_circle,
  // The activity badges. These were missing from the badges screen's own
  // copy of this map, so they had been rendering as the fallback star.
  'directions_run' => Icons.directions_run,
  'route' => Icons.route,
  'self_improvement' => Icons.self_improvement,
  // The tiered catalogue. Covered by a test that walks kAllBadges and asserts
  // no definition falls through to the star — the fallback is silent, and has
  // swallowed a badge's icon once already.
  'event_available' => Icons.event_available,
  'calendar_month' => Icons.calendar_month,
  'verified' => Icons.verified,
  'diamond' => Icons.diamond,
  'whatshot' => Icons.whatshot,
  'shield' => Icons.shield,
  'date_range' => Icons.date_range,
  'replay' => Icons.replay,
  'scale' => Icons.scale,
  'inventory_2' => Icons.inventory_2,
  'landscape' => Icons.landscape,
  'leaderboard' => Icons.leaderboard,
  'accessibility_new' => Icons.accessibility_new,
  'filter_2' => Icons.filter_2,
  'directions_walk' => Icons.directions_walk,
  'map' => Icons.map,
  'timer' => Icons.timer,
  'grid_view' => Icons.grid_view,
  'accessibility' => Icons.accessibility,
  'architecture' => Icons.architecture,
  'edit_note' => Icons.edit_note,
  'wb_twilight' => Icons.wb_twilight,
  'bedtime' => Icons.bedtime,
  'weekend' => Icons.weekend,
  'repeat' => Icons.repeat,
  _ => Icons.star,
};

/// What was notable about a session, as a row of chips.
///
/// Replaces a "COMPLETED" badge that carried no information — it had no
/// condition at all, and could not have had a meaningful one, since the
/// history list is fed by a query that filters on `endTime IS NOT NULL`.
///
/// A session with nothing notable renders nothing. Most sessions are ordinary
/// and saying so is not worth a row of chrome.
class SessionChips extends StatelessWidget {
  const SessionChips({
    super.key,
    required this.highlights,
    this.compact = false,
  });

  final SessionHighlights? highlights;

  /// The history row shows counts; the detail sheet names names.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final notable = highlights;
    if (notable == null || notable.isEmpty) return const SizedBox.shrink();

    final chips = <Widget>[];

    if (notable.prCount > 0) {
      chips.add(
        _Chip(
          icon: Icons.trending_up,
          label: notable.prCount == 1 ? '1 PR' : '${notable.prCount} PRs',
          color: OneRepColors.gold,
        ),
      );
    }

    for (final key in notable.badgeKeys) {
      final badge = kAllBadges.where((b) => b.key == key).firstOrNull;
      if (badge == null) continue;
      chips.add(
        _Chip(
          icon: badgeIconData(badge.icon),
          label: badge.name,
          color: OneRepColors.coral,
        ),
      );
    }

    final firsts = notable.firstTimeExercises;
    if (firsts.isNotEmpty) {
      if (compact) {
        chips.add(
          _Chip(
            icon: Icons.auto_awesome,
            label: firsts.length == 1 ? '1 new' : '${firsts.length} new',
            color: OneRepColors.success,
          ),
        );
      } else {
        for (final name in firsts) {
          chips.add(
            _Chip(
              icon: Icons.auto_awesome,
              label: 'First $name',
              color: OneRepColors.success,
            ),
          );
        }
      }
    }

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
