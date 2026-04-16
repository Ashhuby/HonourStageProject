import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../data/split_repository.dart';
import '../data/exercise_repository.dart';
import '../data/session_repository.dart';
import 'active_session_screen.dart';

class SplitDetailScreen extends ConsumerWidget {
  final WorkoutSplit split;

  const SplitDetailScreen({super.key, required this.split});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(watchRoutinesForSplitProvider(split.id));

    return Scaffold(
      appBar: AppBar(title: Text(split.name), centerTitle: true),
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
                      color: OneRepColors.error,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(
                        Icons.delete,
                        color: OneRepColors.textPrimary,
                      ),
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
                      onTap: () =>
                          _showRoutineExercisesSheet(context, ref, routine),
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
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: RoutineExercisesSheet(routine: routine),
      ),
    );
  }
}

// --- Bottom sheet showing exercises for a routine ---

class RoutineExercisesSheet extends ConsumerWidget {
  final WorkoutRoutine routine;

  const RoutineExercisesSheet({super.key, required this.routine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routineExercisesAsync = ref.watch(
      watchExercisesForRoutineWithNamesProvider(routine.id),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    routine.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add exercise to plan',
                  onPressed: () => _showExercisePicker(context, ref),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  onPressed: () => _startSession(context, ref),
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
                          key: ValueKey(re.routineExercise.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: OneRepColors.error,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(
                              Icons.delete,
                              color: OneRepColors.textPrimary,
                            ),
                          ),
                          onDismissed: (_) {
                            ref
                                .read(splitRepositoryProvider.notifier)
                                .removeExerciseFromRoutine(
                                  re.routineExercise.id,
                                );
                          },
                          child: ListTile(
                            title: Text(re.exerciseName),
                            subtitle: Text(
                              '${re.bodyPart} • ${re.equipmentType} — '
                              '${re.routineExercise.targetSets} sets × '
                              '${re.routineExercise.targetReps} reps',
                            ),
                            leading: const CircleAvatar(
                              child: Icon(Icons.fitness_center),
                            ),
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  void _showExercisePicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => ExercisePickerDialog(routineId: routine.id),
    );
  }

  Future<void> _startSession(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);

    final sessionId = await ref
        .read(sessionRepositoryProvider.notifier)
        .startSession(routineId: routine.id);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveSessionScreen(
            sessionId: sessionId,
            sessionTitle: routine.name,
            routineId: routine.id,
          ),
        ),
      );
    }
  }
}

// --- Exercise picker dialog ---

class ExercisePickerDialog extends ConsumerWidget {
  final int routineId;

  const ExercisePickerDialog({super.key, required this.routineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(watchExercisesProvider);

    return AlertDialog(
      title: const Text('Add Exercise'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: exercisesAsync.when(
          data: (exercises) => ListView.builder(
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return ListTile(
                title: Text(exercise.name),
                subtitle: Text(
                  '${exercise.bodyPart} • ${exercise.equipmentType}',
                ),
                onTap: () {
                  ref
                      .read(splitRepositoryProvider.notifier)
                      .addExerciseToRoutine(
                        routineId: routineId,
                        exerciseId: exercise.id,
                      );
                  Navigator.pop(context);
                },
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
