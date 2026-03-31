// lib/features/workout/presentation/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../core/sync/sync_provider.dart';
import '../data/session_repository.dart';
import 'split_list_screen.dart';
import 'exercise_library_screen.dart';
import 'active_session_screen.dart';
import 'progress_screen.dart';
import 'badges_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncNotifierProvider);

    ref.listen(syncNotifierProvider, (_, next) {
      next.whenOrNull(
        data: (result) {
          if (result.unauthenticated) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.success
                  ? 'Synced ${result.uploaded} records'
                  : 'Sync failed: ${result.errors.join(', ')}'),
              backgroundColor: result.success ? Colors.green : Colors.red,
            ),
          );
        },
      );
    });

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('One Rep'),
          centerTitle: true,
          actions: [
            // Profile button
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile & Settings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              ),
            ),
            // Manual sync button
            syncState.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.sync),
                    tooltip: 'Sync now',
                    onPressed: () =>
                        ref.read(syncNotifierProvider.notifier).sync(),
                  ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.calendar_view_week), text: 'Splits'),
              Tab(icon: Icon(Icons.fitness_center), text: 'Exercises'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Progress'),
              Tab(icon: Icon(Icons.emoji_events), text: 'Badges'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SplitListScreen(),
            ExerciseLibraryScreen(),
            ProgressScreen(),
            BadgesScreen(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'freestyle',
          icon: const Icon(Icons.play_arrow),
          label: const Text('Freestyle'),
          onPressed: () => _startFreestyleSession(context, ref),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Future<void> _startFreestyleSession(
      BuildContext context, WidgetRef ref) async {
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
            routineId: null, // explicit — freestyle shows full library
          ),
        ),
      );     
    }
  }
}