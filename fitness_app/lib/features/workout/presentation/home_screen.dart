import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/session_repository.dart';
import 'split_list_screen.dart';
import 'exercise_library_screen.dart';
import 'active_session_screen.dart';
import 'progress_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Honour Stage Fitness'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.calendar_view_week), text: 'Splits'),
              Tab(icon: Icon(Icons.fitness_center), text: 'Exercises'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Progress'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const SplitListScreen(),
            const ExerciseLibraryScreen(),
            ProgressScreen(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'freestyle',
          icon: const Icon(Icons.play_arrow),
          label: const Text('Freestyle'),
          onPressed: () => _startFreestyleSession(context, ref),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerFloat,
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
          ),
        ),
      );
    }
  }
}