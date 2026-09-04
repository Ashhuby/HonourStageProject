import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/sync/sync_service.dart' show SyncResult;
import '../data/badge_service.dart';
import '../data/badge_unlock_queue.dart';
import '../data/rank_up_queue.dart';
import '../data/session_repository.dart';
import '../domain/rank.dart';
import 'widgets/rank_visuals.dart';
import 'split_list_screen.dart';
import 'exercise_library_screen.dart';
import 'active_session_screen.dart';
import 'progress_screen.dart';
import 'badges_screen.dart';
import '../../profile/presentation/profile_screen.dart';

/// Reports what a sync actually did, including what went wrong.
///
/// It used to say "Sync failed" and nothing else, while `SyncResult.errors`
/// carried the reason the whole time — which made a foreign key violation
/// against a server missing its parent rows indistinguishable from being
/// offline.
void _showSyncResult(BuildContext context, WidgetRef ref, SyncResult result) {
  final messenger = ScaffoldMessenger.of(context);

  if (result.success) {
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_done, color: OneRepColors.success, size: 18),
            const SizedBox(width: 10),
            Text('Synced ${result.uploaded} records'),
          ],
        ),
      ),
    );
    return;
  }

  messenger.showSnackBar(
    SnackBar(
      backgroundColor: OneRepColors.surfaceElevated,
      duration: const Duration(seconds: 8),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off, color: OneRepColors.error, size: 18),
              SizedBox(width: 10),
              Text('Sync failed'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.errors.join('\n'),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: OneRepColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
      // The common cause is a server that no longer holds rows this device
      // already uploaded, which nothing recovers from on its own — the parents
      // are never re-sent and every child keeps failing its foreign key.
      action: SnackBarAction(
        label: 'RE-UPLOAD ALL',
        textColor: OneRepColors.gold,
        onPressed: () => ref.read(syncNotifierProvider.notifier).resync(),
      ),
    ),
  );
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  /// The badges tab's index, so the screen can be told when it is on show.
  static const _badgesTab = 3;

  /// Built rather than const because [BadgesScreen] needs to know whether it
  /// is the visible tab: an `IndexedStack` builds every child at launch and
  /// only paints one, so a staggered entrance triggered on first build would
  /// play to nobody and never play again.
  List<Widget> get _screens => [
    const SplitListScreen(),
    const ExerciseLibraryScreen(),
    const ProgressScreen(),
    BadgesScreen(isActive: _currentIndex == _badgesTab),
  ];

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncNotifierProvider);

    ref.listen(syncNotifierProvider, (_, next) {
      next.whenOrNull(
        data: (result) {
          if (result.unauthenticated) return;
          _showSyncResult(context, ref, result);
        },
        // A thrown error never reached the user at all: the listener only
        // handled `data`, so a sync that blew up left the spinner stopping and
        // nothing else happening.
        error: (error, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: OneRepColors.error,
            content: Text('Sync failed: $error'),
          ),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: _OneRepTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, size: 22),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          syncState.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: OneRepColors.gold,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.sync, size: 22),
                  tooltip: 'Sync',
                  onPressed: () =>
                      ref.read(syncNotifierProvider.notifier).sync(),
                ),
          IconButton(
            icon: const Icon(Icons.logout, size: 22),
            tooltip: 'Sign out',
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ----------------------------------------------------------------
          // Session banner — full width, above bottom nav. Offers to resume
          // an unfinished session rather than start a second one.
          // ----------------------------------------------------------------
          ref
              .watch(watchActiveSessionProvider)
              .maybeWhen(
                data: (active) => active == null
                    ? _FreestyleBanner(
                        onTap: () => _startFreestyleSession(context),
                      )
                    : _ResumeBanner(
                        active: active,
                        onTap: () => _resumeSession(context, active),
                        onDiscard: () =>
                            _confirmDiscardSession(context, active),
                      ),
                orElse: () => _FreestyleBanner(
                  onTap: () => _startFreestyleSession(context),
                ),
              ),
          // ----------------------------------------------------------------
          // Bottom navigation
          // ----------------------------------------------------------------
          _OneRepNavBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
          ),
        ],
      ),
    );
  }

  Future<void> _startFreestyleSession(BuildContext context) async {
    final sessionId = await ref
        .read(sessionRepositoryProvider.notifier)
        .startSession(routineId: null);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveSessionScreen(
            sessionId: sessionId,
            sessionTitle: freestyleSessionTitle,
          ),
        ),
      );
    }
  }

  void _resumeSession(BuildContext context, ActiveSession active) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveSessionScreen(
          sessionId: active.session.id,
          sessionTitle: active.title,
          routineId: active.routineId,
        ),
      ),
    );
  }

  Future<void> _confirmDiscardSession(
    BuildContext context,
    ActiveSession active,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard Workout?'),
        content: Text(
          'The unfinished ${active.title} session and every set logged in it '
          'will be deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep It'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: OneRepColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref
          .read(sessionRepositoryProvider.notifier)
          .deleteSession(active.session.id);
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text(
          'You will need to sign in again to access your data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Sign-out resets every badge row, so a celebration still waiting to be
      // shown belongs to an account that no longer has it — and a rank is
      // only ever a sum of those badges.
      ref.read(badgeUnlockQueueProvider.notifier).clear();
      ref.read(rankUpQueueProvider.notifier).clear();
      await ref.read(authRepositoryProvider).signOut();
    }
  }
}

// ---------------------------------------------------------------------------
// App bar title
// ---------------------------------------------------------------------------

class _OneRepTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: OneRepColors.gold,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.fitness_center,
            color: OneRepColors.background,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'ONE REP',
          style: TextStyle(
            color: OneRepColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Freestyle banner — sits above bottom nav, full width
// ---------------------------------------------------------------------------

/// Offers a way back into a session that was started and never finished.
///
/// Without it an interrupted workout is unreachable: in-progress sessions are
/// excluded from history and from sync, so the sets logged before the
/// interruption are simply lost.
class _ResumeBanner extends ConsumerWidget {
  final ActiveSession active;
  final VoidCallback onTap;
  final VoidCallback onDiscard;

  const _ResumeBanner({
    required this.active,
    required this.onTap,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setCount =
        ref.watch(watchSetCountForSessionProvider(active.session.id)).value ??
        0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: const BoxDecoration(
          color: OneRepColors.surfaceElevated,
          border: Border(top: BorderSide(color: OneRepColors.gold, width: 2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.play_circle_outline,
              color: OneRepColors.gold,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'RESUME ${active.title.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: OneRepColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$setCount ${setCount == 1 ? 'set' : 'sets'} logged • '
                    'started ${formatShortDate(active.session.startTime)}',
                    style: const TextStyle(
                      color: OneRepColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: OneRepColors.textSecondary,
              tooltip: 'Discard workout',
              onPressed: onDiscard,
            ),
          ],
        ),
      ),
    );
  }
}

class _FreestyleBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _FreestyleBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          color: OneRepColors.gold,
          border: Border(
            top: BorderSide(color: OneRepColors.background, width: 1),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              color: OneRepColors.background,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'START FREESTYLE SESSION',
              style: TextStyle(
                color: OneRepColors.background,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom navigation bar
// ---------------------------------------------------------------------------

class _OneRepNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _OneRepNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: OneRepColors.surface,
        border: Border(
          top: BorderSide(color: OneRepColors.surfaceElevated, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.view_week_outlined,
                activeIcon: Icons.view_week,
                label: 'Splits',
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.fitness_center_outlined,
                activeIcon: Icons.fitness_center,
                label: 'Exercises',
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart,
                label: 'Progress',
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _BadgesNavItem(active: currentIndex == 3, onTap: () => onTap(3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Badges tab, wearing the user's rank.
///
/// The rank is a summary of a screen the user is not looking at, so it earns
/// its place here: a crest on the tab means the ladder is visible from
/// anywhere in the app rather than only from the screen that explains it.
class _BadgesNavItem extends ConsumerWidget {
  const _BadgesNavItem({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Falls back to no crest while the badges are loading rather than to Iron,
    // which would flash the lowest rank at a user who is not on it.
    final badges = ref.watch(watchBadgesProvider).valueOrNull;
    final rank = badges == null
        ? null
        : rankForPoints(
            rankPointsOf([
              for (final badge in badges)
                if (badge.isEarned) badge.tier,
            ]),
          );

    return _NavItem(
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events,
      label: 'Badges',
      active: active,
      onTap: onTap,
      corner: rank == null
          ? null
          : RankCrest(rank: rank, size: 16, showNumeral: false),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// A small marker pinned to the icon's top-right, for a tab that has
  /// something to say while you are elsewhere.
  final Widget? corner;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.corner,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? OneRepColors.gold.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    active ? activeIcon : icon,
                    size: 22,
                    color: active
                        ? OneRepColors.gold
                        : OneRepColors.textSecondary,
                  ),
                  if (corner != null)
                    Positioned(top: -5, right: -8, child: corner!),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? OneRepColors.gold : OneRepColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
