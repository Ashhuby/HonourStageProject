// lib/features/workout/presentation/exercise_library_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/badge_service.dart';
import '../data/exercise_repository.dart';
import '../data/personal_best_repository.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends ConsumerWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(watchExercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
        centerTitle: true,
      ),
      body: exercisesAsync.when(
        data: (exercises) => exercises.isEmpty
            ? const Center(child: Text('No exercises found. Add one!'))
            : ListView.builder(
                // Bottom padding so the last item isn't hidden behind the FAB.
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final exercise = exercises[index];
                  return Dismissible(
                    key: ValueKey(exercise.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref
                          .read(exerciseRepositoryProvider.notifier)
                          .deleteExercise(exercise.id);
                    },
                    child: ListTile(
                      title: Text(exercise.name),
                      subtitle: Text(
                          '${exercise.bodyPart} • ${exercise.equipmentType}'),
                      leading: const CircleAvatar(
                        child: Icon(Icons.fitness_center),
                      ),
                      // PR count badge on trailing — gives the user a reason
                      // to tap through to the detail screen.
                      trailing: _PrCountBadge(exerciseId: exercise.id),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ExerciseDetailScreen(exercise: exercise),
                        ),
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExerciseDialog(context, ref),
        label: const Text('Add Exercise'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddExerciseDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final bodyPartController = TextEditingController();
    final equipmentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Exercise'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: 'Exercise Name'),
                autofocus: true,
              ),
              TextField(
                controller: bodyPartController,
                decoration:
                    const InputDecoration(labelText: 'Body Part'),
              ),
              TextField(
                controller: equipmentController,
                decoration:
                    const InputDecoration(labelText: 'Equipment'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                // Add the exercise — isCustom defaults to true in the repo.
                await ref
                    .read(exerciseRepositoryProvider.notifier)
                    .addExercise(
                      nameController.text,
                      bodyPartController.text,
                      equipmentController.text,
                    );

                // Evaluate badges — adding a custom exercise may unlock
                // 'first_custom_exercise'. PR count unchanged so pass 0
                // as a floor; evaluateAll reads the real count internally
                // for PR-related badges.
                final prCount = await ref
                    .read(personalBestRepositoryProvider.notifier)
                    .getTotalPrCount();

                await ref
                    .read(badgeServiceProvider.notifier)
                    .evaluateAll(totalPrCount: prCount);

                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add to Library'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PR count badge widget
// ---------------------------------------------------------------------------
// Shows how many personal records exist for an exercise.
// Renders nothing if there are no PRs — no noise for new exercises.
// Gives users a visual reason to tap through to the detail screen.

class _PrCountBadge extends ConsumerWidget {
  final int exerciseId;

  const _PrCountBadge({required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prsAsync = ref.watch(watchPrsForExerciseProvider(exerciseId));

    return prsAsync.when(
      // No loading indicator — trailing slot is too small and the
      // flicker on list rebuild looks worse than showing nothing.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (prs) {
        if (prs.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '${prs.length} PR${prs.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}