import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../data/badge_service.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(watchBadgesProvider);

    return Scaffold(
      body: badgesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (badges) {
          final earned = badges.where((b) => b.isEarned).toList();
          final unearned = badges.where((b) => !b.isEarned).toList();

          return CustomScrollView(
            slivers: [
              // ---------------------------------------------------------------
              // Summary header
              // ---------------------------------------------------------------
              SliverToBoxAdapter(
                child: _SummaryHeader(
                  earned: earned.length,
                  total: badges.length,
                ),
              ),

              // ---------------------------------------------------------------
              // Earned
              // ---------------------------------------------------------------
              if (earned.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: _SectionLabel(title: 'EARNED'),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.05,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _BadgeTile(
                        badge: earned[index],
                        earned: true,
                      ),
                      childCount: earned.length,
                    ),
                  ),
                ),
              ],

              // ---------------------------------------------------------------
              // Locked
              // ---------------------------------------------------------------
              if (unearned.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: _SectionLabel(title: 'LOCKED'),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.05,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _BadgeTile(
                        badge: unearned[index],
                        earned: false,
                      ),
                      childCount: unearned.length,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary header
// ---------------------------------------------------------------------------

class _SummaryHeader extends StatelessWidget {
  final int earned;
  final int total;

  const _SummaryHeader({required this.earned, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : earned / total;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OneRepColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: OneRepColors.gold, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$earned',
                style: const TextStyle(
                  color: OneRepColors.gold,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  '/ $total',
                  style: const TextStyle(
                    color: OneRepColors.textSecondary,
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.emoji_events,
                color: OneRepColors.gold,
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'ACHIEVEMENTS UNLOCKED',
            style: TextStyle(
              color: OneRepColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: OneRepColors.surfaceHighest,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(OneRepColors.gold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            earned == total && total > 0
                ? '🏆 All achievements unlocked!'
                : '${total - earned} remaining',
            style: const TextStyle(
              color: OneRepColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
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
// Badge tile
// ---------------------------------------------------------------------------

class _BadgeTile extends StatelessWidget {
  final BadgeViewModel badge;
  final bool earned;

  const _BadgeTile({required this.badge, required this.earned});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: AnimatedOpacity(
        opacity: earned ? 1.0 : 0.35,
        duration: const Duration(milliseconds: 300),
        child: Container(
          decoration: BoxDecoration(
            color: OneRepColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: earned
                  ? OneRepColors.gold.withValues(alpha: 0.4)
                  : OneRepColors.surfaceElevated,
              width: earned ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: earned
                        ? OneRepColors.gold.withValues(alpha: 0.15)
                        : OneRepColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: earned
                        ? Border.all(
                            color: OneRepColors.gold.withValues(alpha: 0.3),
                          )
                        : null,
                  ),
                  child: Icon(
                    _iconData(badge.icon),
                    size: 26,
                    color: earned
                        ? OneRepColors.gold
                        : OneRepColors.textDisabled,
                  ),
                ),
                const SizedBox(height: 10),

                // Name
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

                // Earned date or lock icon
                const SizedBox(height: 4),
                if (earned && badge.earnedAt != null)
                  Text(
                    _formatDate(badge.earnedAt!),
                    style: const TextStyle(
                      color: OneRepColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  const Icon(
                    Icons.lock_outline,
                    size: 13,
                    color: OneRepColors.textDisabled,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: OneRepColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BadgeDetailSheet(badge: badge, earned: earned),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  IconData _iconData(String name) => switch (name) {
        'fitness_center' => Icons.fitness_center,
        'local_fire_department' => Icons.local_fire_department,
        'emoji_events' => Icons.emoji_events,
        'military_tech' => Icons.military_tech,
        'trending_up' => Icons.trending_up,
        'bolt' => Icons.bolt,
        'workspace_premium' => Icons.workspace_premium,
        'add_circle' => Icons.add_circle,
        _ => Icons.star,
      };
}

// ---------------------------------------------------------------------------
// Badge detail bottom sheet
// ---------------------------------------------------------------------------

class _BadgeDetailSheet extends StatelessWidget {
  final BadgeViewModel badge;
  final bool earned;

  const _BadgeDetailSheet({required this.badge, required this.earned});

  @override
  Widget build(BuildContext context) {
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

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: earned
                  ? OneRepColors.gold.withValues(alpha: 0.15)
                  : OneRepColors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: earned
                  ? Border.all(
                      color: OneRepColors.gold.withValues(alpha: 0.4),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Icon(
              _iconData(badge.icon),
              size: 36,
              color: earned ? OneRepColors.gold : OneRepColors.textDisabled,
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            badge.name,
            style: const TextStyle(
              color: OneRepColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Description
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

          // Status pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: earned
                  ? OneRepColors.gold.withValues(alpha: 0.12)
                  : OneRepColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: earned
                    ? OneRepColors.gold.withValues(alpha: 0.4)
                    : OneRepColors.surfaceHighest,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  earned ? Icons.check_circle_outline : Icons.lock_outline,
                  color: earned
                      ? OneRepColors.gold
                      : OneRepColors.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  earned && badge.earnedAt != null
                      ? 'Earned ${_formatDate(badge.earnedAt!)}'
                      : 'Not yet earned',
                  style: TextStyle(
                    color: earned
                        ? OneRepColors.gold
                        : OneRepColors.textSecondary,
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

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  IconData _iconData(String name) => switch (name) {
        'fitness_center' => Icons.fitness_center,
        'local_fire_department' => Icons.local_fire_department,
        'emoji_events' => Icons.emoji_events,
        'military_tech' => Icons.military_tech,
        'trending_up' => Icons.trending_up,
        'bolt' => Icons.bolt,
        'workspace_premium' => Icons.workspace_premium,
        'add_circle' => Icons.add_circle,
        _ => Icons.star,
      };
}