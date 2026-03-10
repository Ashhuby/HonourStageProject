import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/core/database/local_database.dart';
import '../data/split_repository.dart';

class SplitDetailScreen extends ConsumerWidget {
  final WorkoutSplit split;

  const SplitDetailScreen({super.key, required this.split});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(watchRoutinesForSplitProvider(split.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(split.name),
        centerTitle: true,
      ),
      body: routinesAsync.when(
        data: (routines) => routines.isEmpty
            ? const Center(
                child: Text('No days yet. Add a training day to get started.'),
              )
            : ListView.builder(
                itemCount: routines.length,
                itemBuilder: (context, index) {
                  final routine = routines[index];
                  return Dismissible(
                    key: ValueKey(routine.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref
                          .read(splitRepositoryProvider.notifier)
                          .deleteRoutine(routine.id);
                    },
                    child: ListTile(
                      title: Text(routine.name),
                      subtitle: Text('Day ${routine.orderIndex + 1}'),
                      leading: CircleAvatar(
                        child: Text('${routine.orderIndex + 1}'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showRoutineExercisesSheet(
                        context,
                        ref,
                        routine,
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRoutineDialog(context, ref),
        label: const Text('Add Day'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddRoutineDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Training Day'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Day Name',
            hintText: 'e.g. Push Day',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref
                    .read(splitRepositoryProvider.notifier)
                    .addRoutineToSplit(nameController.text, split.id);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showRoutineExercisesSheet(
    BuildContext context,
    WidgetRef ref,
    WorkoutRoutine routine,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => RoutineExercisesSheet(routine: routine),
    );
  }
}

// --- Bottom sheet showing exercises for a routine ---

class RoutineExercisesSheet extends ConsumerWidget {
  final WorkoutRoutine routine;

  const RoutineExercisesSheet({super.key, required this.routine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routineExercisesAsync =
        ref.watch(watchExercisesForRoutineProvider(routine.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  routine.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddExerciseDialog(context, ref),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: routineExercisesAsync.when(
              data: (routineExercises) => routineExercises.isEmpty
                  ? const Center(
                      child: Text('No exercises yet. Tap + to add some.'),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: routineExercises.length,
                      itemBuilder: (context, index) {
                        final re = routineExercises[index];
                        return Dismissible(
                          key: ValueKey(re.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            ref
                                .read(splitRepositoryProvider.notifier)
                                .removeExerciseFromRoutine(re.id);
                          },
                          child: ListTile(
                            title: Text('Exercise #${re.exerciseId}'),
                            subtitle: Text(
                              '${re.targetSets} sets × ${re.targetReps} reps',
                            ),
                            leading: const CircleAvatar(
                              child: Icon(Icons.fitness_center),
                            ),
                          ),
                        );
                      },
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseDialog(BuildContext context, WidgetRef ref) {
    // Placeholder — we will replace this with a proper
    // exercise picker in the next step
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Exercise'),
        content: const Text(
          'Exercise picker coming next.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}