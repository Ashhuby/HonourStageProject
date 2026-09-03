import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../data/split_repository.dart';
import '../data/session_repository.dart';
import 'active_session_screen.dart';
import 'widgets/exercise_picker_sheet.dart';
import 'widgets/routine_target_dialog.dart';

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
                              '${re.targetSummary}',
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

  Future<void> _showExercisePicker(BuildContext context, WidgetRef ref) async {
    // Exercises already planned for this day are hidden, so the same one
    // cannot be added twice — the dialog this replaced allowed duplicates.
    final planned = await ref.read(
      watchExercisesForRoutineWithNamesProvider(routine.id).future,
    );
    final alreadyAdded = {
      for (final entry in planned) entry.routineExercise.exerciseId,
    };

    if (!context.mounted) return;
    final picked = await showExercisePicker(
      context,
      excludeIds: alreadyAdded,
      title: 'Add to ${routine.name}',
    );
    if (picked == null || !context.mounted) return;

    // Ask for the target in the units the exercise is measured in, rather
    // than defaulting a run to "3 sets of 10 reps".
    final target = await showRoutineTargetDialog(context, picked);
    if (target == null) return;

    await ref
        .read(splitRepositoryProvider.notifier)
        .addExerciseToRoutine(
          routineId: routine.id,
          exerciseId: picked.id,
          targetSets: target.sets,
          targetReps: target.reps,
          targetDistanceMetres: target.distanceMetres,
          targetDurationSeconds: target.durationSeconds,
        );
  }

  /// Starts this routine, first offering a way out of a session that was
  /// never finished — starting over it would strand the sets logged in it.
  Future<void> _startSession(BuildContext context, WidgetRef ref) async {
    // Capture the navigator before dismissing the sheet: popping deactivates
    // the sheet's context, and everything below this line runs after it.
    final navigator = Navigator.of(context);
    Navigator.pop(context);

    final active = await ref.read(watchActiveSessionProvider.future);

    if (active != null) {
      if (!navigator.mounted) return;
      final choice = await showDialog<_InProgressChoice>(
        context: navigator.context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Workout In Progress'),
          content: Text(
            'You have an unfinished ${active.title} session. Resume it, or '
            'discard it and start ${routine.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: OneRepColors.error),
              onPressed: () =>
                  Navigator.pop(dialogContext, _InProgressChoice.discard),
              child: const Text('Discard & Start'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: OneRepColors.gold),
              onPressed: () =>
                  Navigator.pop(dialogContext, _InProgressChoice.resume),
              child: const Text('Resume'),
            ),
          ],
        ),
      );

      switch (choice) {
        case null:
          return;
        case _InProgressChoice.resume:
          navigator.push(
            MaterialPageRoute(
              builder: (_) => ActiveSessionScreen(
                sessionId: active.session.id,
                sessionTitle: active.title,
                routineId: active.routineId,
              ),
            ),
          );
          return;
        case _InProgressChoice.discard:
          await ref
              .read(sessionRepositoryProvider.notifier)
              .deleteSession(active.session.id);
      }
    }

    final sessionId = await ref
        .read(sessionRepositoryProvider.notifier)
        .startSession(routineId: routine.id);

    navigator.push(
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

/// What to do about a session that is already in progress.
enum _InProgressChoice { resume, discard }
