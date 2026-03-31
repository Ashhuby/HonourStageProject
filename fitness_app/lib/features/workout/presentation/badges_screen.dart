import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/badge_service.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(watchBadgesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        centerTitle: true,
      ),
      body: badgesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (badges) {
          final earned = badges.where((b) => b.isEarned).toList();
          final unearned = badges.where((b) => !b.isEarned).toList();

          return CustomScrollView(
            slivers: [
              // ----------------------------------------------------------------
              // Summary header
              // ----------------------------------------------------------------
              SliverToBoxAdapter(
                child: _SummaryBanner(
                  earned: earned.length,
                  total: badges.length,
                ),
              ),

              // ----------------------------------------------------------------
              // Earned badges
              // ----------------------------------------------------------------
              if (earned.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: _SectionHeader(title: 'Earned'),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
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

              // ----------------------------------------------------------------
              // Unearned badges
              // ----------------------------------------------------------------
              if (unearned.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: _SectionHeader(title: 'Locked'),
                ),
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
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
// Summary banner
// ---------------------------------------------------------------------------

class _SummaryBanner extends StatelessWidget {
  final int earned;
  final int total;

  const _SummaryBanner({required this.earned, required this.total});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : earned / total;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$earned / $total achievements unlocked',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor:
                  colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            earned == total && total > 0
                ? '🏆 All achievements unlocked!'
                : '${total - earned} remaining',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: AnimatedOpacity(
        opacity: earned ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Card(
          elevation: earned ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: earned
                ? BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with background circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: earned
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    _iconData(badge.icon),
                    size: 28,
                    color: earned
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),

                // Badge name
                Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: earned
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),

                // Earned date — only shown when earned
                if (earned && badge.earnedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(badge.earnedAt!),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],

                // Lock icon for unearned
                if (!earned) ...[
                  const SizedBox(height: 4),
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
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

  /// Maps the string icon name stored in [BadgeDefinition] to a
  /// Flutter [IconData]. Centralised here so the mapping is one place.
  IconData _iconData(String name) {
    return switch (name) {
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
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: earned
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
            ),
            child: Icon(
              _iconData(badge.icon),
              size: 40,
              color: earned
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            badge.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),

          // Earned state
          if (earned && badge.earnedAt != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Earned on ${_formatDate(badge.earnedAt!)}',
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline,
                      color: colorScheme.onSurfaceVariant, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Not yet earned',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
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

  IconData _iconData(String name) {
    return switch (name) {
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
}