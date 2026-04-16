import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../core/sync/sync_provider.dart';
import '../data/session_repository.dart';
import 'split_list_screen.dart';
import 'exercise_library_screen.dart';
import 'active_session_screen.dart';
import 'progress_screen.dart';
import 'badges_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  static const _screens = [
    SplitListScreen(),
    ExerciseLibraryScreen(),
    ProgressScreen(),
    BadgesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncNotifierProvider);

    ref.listen(syncNotifierProvider, (_, next) {
      next.whenOrNull(
        data: (result) {
          if (result.unauthenticated) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    result.success ? Icons.cloud_done : Icons.cloud_off,
                    color: result.success
                        ? OneRepColors.success
                        : OneRepColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    result.success
                        ? 'Synced ${result.uploaded} records'
                        : 'Sync failed',
                  ),
                ],
              ),
            ),
          );
        },
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
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ----------------------------------------------------------------
          // Freestyle banner — full width, above bottom nav
          // ----------------------------------------------------------------
          _FreestyleBanner(
            onTap: () => _startFreestyleSession(context),
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
            sessionTitle: 'Freestyle Session',
          ),
        ),
      );
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
            top: BorderSide(
              color: OneRepColors.background,
              width: 1,
            ),
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

  const _OneRepNavBar({
    required this.currentIndex,
    required this.onTap,
  });

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
              _NavItem(
                icon: Icons.emoji_events_outlined,
                activeIcon: Icons.emoji_events,
                label: 'Badges',
                active: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? OneRepColors.gold.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                active ? activeIcon : icon,
                size: 22,
                color: active
                    ? OneRepColors.gold
                    : OneRepColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w400,
                color: active
                    ? OneRepColors.gold
                    : OneRepColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}