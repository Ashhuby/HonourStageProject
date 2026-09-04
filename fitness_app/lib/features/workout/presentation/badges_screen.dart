import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/badge_service.dart';
import '../data/badge_stats.dart';
import '../domain/rank.dart';
import 'widgets/badge_tile.dart';
import 'widgets/badge_visuals.dart';
import 'widgets/rank_visuals.dart';

/// How many badges the "next up" section suggests.
const int _kNextUpCount = 3;

/// How long the staggered grid entrance takes end to end.
const Duration _kStaggerDuration = Duration(milliseconds: 950);

/// The share of the entrance one tile's own fade occupies. The remainder is
/// spread across the tiles as their start offsets.
const double _kTileWindow = 0.55;

class BadgesScreen extends ConsumerStatefulWidget {
  const BadgesScreen({super.key, this.isActive = true});

  /// Whether this is the visible tab. Drives the entrance animation — see the
  /// note on `_screens` in `home_screen.dart`.
  final bool isActive;

  @override
  ConsumerState<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends ConsumerState<BadgesScreen>
    with SingleTickerProviderStateMixin {
  // Constructed in initState, not as a `late final` initialiser: a screen
  // disposed before its first build would otherwise create the controller
  // from inside dispose(), where the element is no longer active.
  late final AnimationController _stagger;

  /// Null means every category.
  BadgeCategory? _filter;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(vsync: this, duration: _kStaggerDuration);
    if (widget.isActive) _stagger.forward();
  }

  @override
  void didUpdateWidget(BadgesScreen old) {
    super.didUpdateWidget(old);
    // Replay each time the tab is opened. The collection is the point of the
    // screen, and watching it assemble is most of the reward for filling it.
    if (widget.isActive && !old.isActive) _stagger.forward(from: 0);
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgesAsync = ref.watch(watchBadgesProvider);

    // Subscribed to only while this is the visible tab. The provider
    // recomputes on every write to the set and session tables, and this screen
    // stays mounted inside the home screen's IndexedStack — without the guard
    // it would recompute the whole snapshot after every set logged during a
    // workout happening two routes away.
    final stats = widget.isActive
        ? ref.watch(badgeProgressProvider).valueOrNull
        : null;

    return Scaffold(
      body: badgesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (badges) => _BadgesBody(
          badges: badges,
          stats: stats,
          stagger: _stagger,
          filter: _filter,
          onFilter: (category) => setState(() => _filter = category),
        ),
      ),
    );
  }
}

class _BadgesBody extends StatelessWidget {
  const _BadgesBody({
    required this.badges,
    required this.stats,
    required this.stagger,
    required this.filter,
    required this.onFilter,
  });

  final List<BadgeViewModel> badges;
  final BadgeStats? stats;
  final Animation<double> stagger;
  final BadgeCategory? filter;
  final ValueChanged<BadgeCategory?> onFilter;

  /// The unearned badges the user is closest to finishing.
  ///
  /// Badges with no meaningful halfway point are excluded: "train before 6am"
  /// is never 60% done, and listing it as a suggestion would say nothing about
  /// what to do next. Zero-progress badges are excluded for the same reason —
  /// a suggestion the user has not started is not a near miss.
  List<BadgeViewModel> _nextUp(BadgeStats snapshot) {
    final candidates =
        badges
            .where((b) => !b.isEarned && b.definition.showsProgress)
            .map(
              (b) => (
                badge: b,
                fraction: progressFractionFor(b.definition, snapshot),
              ),
            )
            .where((entry) => entry.fraction > 0)
            .toList()
          ..sort((a, b) => b.fraction.compareTo(a.fraction));

    return [for (final entry in candidates.take(_kNextUpCount)) entry.badge];
  }

  @override
  Widget build(BuildContext context) {
    final earnedTotal = badges.where((b) => b.isEarned).length;

    final visible = filter == null
        ? badges
        : badges.where((b) => b.category == filter).toList();
    final earned = visible.where((b) => b.isEarned).toList();
    final locked = visible.where((b) => !b.isEarned).toList();

    final snapshot = stats;
    final nextUp = snapshot == null
        ? const <BadgeViewModel>[]
        : _nextUp(snapshot);

    // One running index across both grids, so the stagger sweeps the screen
    // once rather than restarting at the "LOCKED" heading.
    var tileIndex = 0;
    Widget grid(List<BadgeViewModel> group) {
      final offsets = [for (final _ in group) tileIndex++];

      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.05,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _StaggeredTile(
            stagger: stagger,
            position: offsets[index],
            total: visible.length,
            badge: group[index],
            stats: snapshot,
          ),
          childCount: group.length,
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _SummaryHeader(
            badges: badges,
            earned: earnedTotal,
            total: badges.length,
          ),
        ),

        if (nextUp.isNotEmpty && snapshot != null) ...[
          const SliverToBoxAdapter(child: _SectionLabel(title: 'NEXT UP')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: nextUp.length,
              itemBuilder: (context, index) => BadgeNextUpRow(
                badge: nextUp[index],
                stats: snapshot,
                onTap: () => showBadgeDetail(context, nextUp[index], snapshot),
              ),
            ),
          ),
        ],

        SliverToBoxAdapter(
          child: _CategoryFilter(selected: filter, onChanged: onFilter),
        ),

        if (earned.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionLabel(title: 'EARNED')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: grid(earned),
          ),
        ],

        if (locked.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionLabel(title: 'LOCKED')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            sliver: grid(locked),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// A tile that fades and lifts into place on its turn.
class _StaggeredTile extends StatelessWidget {
  const _StaggeredTile({
    required this.stagger,
    required this.position,
    required this.total,
    required this.badge,
    required this.stats,
  });

  final Animation<double> stagger;
  final int position;
  final int total;
  final BadgeViewModel badge;
  final BadgeStats? stats;

  @override
  Widget build(BuildContext context) {
    // Start offsets share whatever the tile's own fade window leaves over, so
    // the sweep takes the same time whether there are six badges or sixty.
    final spread = total <= 1 ? 0.0 : (1 - _kTileWindow) / (total - 1);
    final begin = position * spread;

    return AnimatedBuilder(
      animation: stagger,
      builder: (context, _) {
        final entrance = Interval(
          begin,
          begin + _kTileWindow,
          curve: Curves.easeOut,
        ).transform(stagger.value);

        return BadgeTile(
          badge: badge,
          stats: stats,
          entrance: entrance,
          onTap: () => showBadgeDetail(context, badge, stats),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Summary header
// ---------------------------------------------------------------------------

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.badges,
    required this.earned,
    required this.total,
  });

  final List<BadgeViewModel> badges;
  final int earned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final byTier = <BadgeTier, int>{
      for (final tier in BadgeTier.values)
        tier: badges.where((b) => b.isEarned && b.tier == tier).length,
    };

    // The rank is read off the badges already on screen rather than from a
    // provider of its own. There is no second source of truth to fall out of
    // step, and the header cannot show a rank the grid below it disagrees
    // with.
    final standing = standingFor(
      rankPointsOf([
        for (final badge in badges)
          if (badge.isEarned) badge.tier,
      ]),
    );
    final rank = standing.rank;
    final tint = rank.color;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OneRepColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: tint, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RankCrest(rank: rank, size: 62, progress: standing.fraction),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rank.label.toUpperCase(),
                      style: TextStyle(
                        color: tint,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      // Points, not badges: the two differ, and the header is
                      // the only place that explains why a platinum badge
                      // moved the bar further than a bronze one.
                      standing.next == null
                          ? '${standing.points} pts · top rank'
                          : '${standing.points} pts · '
                                '${standing.pointsToNext} to '
                                '${standing.next!.label}',
                      style: const TextStyle(
                        color: OneRepColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$earned',
                    style: const TextStyle(
                      color: OneRepColors.gold,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'of $total',
                    style: const TextStyle(
                      color: OneRepColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress through the current rank, not through the catalogue. The
          // badge count beside the crest already says how much is left
          // overall, and a bar that only fills once every badge is earned
          // barely moves.
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: standing.fraction,
              minHeight: 6,
              backgroundColor: OneRepColors.surfaceHighest,
              valueColor: AlwaysStoppedAnimation<Color>(tint),
            ),
          ),
          const SizedBox(height: 12),

          // The tier breakdown, which the single count cannot show: thirty
          // bronze badges and thirty platinum ones are not the same collection.
          Row(
            children: [
              for (final tier in BadgeTier.values)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _TierCount(tier: tier, count: byTier[tier] ?? 0),
                ),
              const Spacer(),
              Text(
                earned == total && total > 0
                    ? 'All unlocked'
                    : '${total - earned} to go',
                style: const TextStyle(
                  color: OneRepColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TierCount extends StatelessWidget {
  const _TierCount({required this.tier, required this.count});

  final BadgeTier tier;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tint = tier.color;
    final has = count > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: has ? tint : OneRepColors.surfaceHighest,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$count',
          style: TextStyle(
            color: has ? tint : OneRepColors.textDisabled,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category filter
// ---------------------------------------------------------------------------

/// Filter chips across the badge categories.
///
/// Same idiom as the exercise library's `CategoryChips` — a scrolling row of
/// `FilterChip`s where a null selection means everything.
class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.selected, required this.onChanged});

  final BadgeCategory? selected;
  final ValueChanged<BadgeCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        children: [
          _Chip(
            label: 'All',
            selected: selected == null,
            onSelected: () => onChanged(null),
          ),
          for (final category in BadgeCategory.values)
            _Chip(
              label: category.label,
              selected: selected == category,
              onSelected: () => onChanged(category),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected
              ? OneRepColors.background
              : OneRepColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: OneRepColors.surface,
        selectedColor: OneRepColors.gold,
        side: BorderSide(
          color: selected ? OneRepColors.gold : OneRepColors.surfaceElevated,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        title,
        style: const TextStyle(
          color: OneRepColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge detail bottom sheet
// ---------------------------------------------------------------------------

/// Opens the detail sheet for [badge].
void showBadgeDetail(
  BuildContext context,
  BadgeViewModel badge,
  BadgeStats? stats,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: OneRepColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _BadgeDetailSheet(badge: badge, stats: stats),
  );
}

class _BadgeDetailSheet extends StatelessWidget {
  const _BadgeDetailSheet({required this.badge, required this.stats});

  final BadgeViewModel badge;
  final BadgeStats? stats;

  @override
  Widget build(BuildContext context) {
    final earned = badge.isEarned;
    final tint = badge.tier.color;
    final snapshot = stats;
    final showProgress =
        !earned && badge.definition.showsProgress && snapshot != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: OneRepColors.surfaceHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          BadgeMedallion(
            badge: badge.definition,
            earned: earned,
            size: 76,
            progress: showProgress
                ? progressFractionFor(badge.definition, snapshot)
                : null,
          ),
          const SizedBox(height: 16),

          Text(
            badge.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OneRepColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),

          // Tier and category, so a badge's place in the collection is legible
          // without going back to the grid and counting colours.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MetaPill(
                label: badge.tier.label.toUpperCase(),
                color: tint,
                filled: true,
              ),
              const SizedBox(width: 8),
              _MetaPill(
                label: badge.category.label.toUpperCase(),
                color: OneRepColors.textSecondary,
                filled: false,
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OneRepColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          if (showProgress) ...[
            _DetailProgress(badge: badge, stats: snapshot, tint: tint),
            const SizedBox(height: 16),
          ],

          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: earned
                  ? tint.withValues(alpha: 0.12)
                  : OneRepColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: earned
                    ? tint.withValues(alpha: 0.4)
                    : OneRepColors.surfaceHighest,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  earned ? Icons.check_circle_outline : Icons.lock_outline,
                  color: earned ? tint : OneRepColors.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  earned && badge.earnedAt != null
                      ? 'Earned ${formatShortDate(badge.earnedAt!)}'
                      : 'Not yet earned',
                  style: TextStyle(
                    color: earned ? tint : OneRepColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The progress bar and figure on a locked badge's sheet.
class _DetailProgress extends StatelessWidget {
  const _DetailProgress({
    required this.badge,
    required this.stats,
    required this.tint,
  });

  final BadgeViewModel badge;
  final BadgeStats stats;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final progress = progressFor(badge.definition, stats);
    final fraction = progressFractionFor(badge.definition, stats);
    final stat = badge.definition.stat;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: OneRepColors.surfaceHighest,
            valueColor: AlwaysStoppedAnimation<Color>(tint),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          stat.formatPair(progress.current, progress.target),
          style: const TextStyle(
            color: OneRepColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.color,
    required this.filled,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
