import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database.dart';
import '../data/split_repository.dart';
import 'widgets/exercise_picker_sheet.dart';
import 'widgets/rename_dialog.dart';
import 'widgets/start_session.dart';
import 'widgets/routine_target_dialog.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_file_rename_outline),
            tooltip: 'Rename split',
            onPressed: () async {
              final name = await showRenameDialog(
                context,
                title: 'Rename split',
                current: split.name,
              );
              if (name == null || !context.mounted) return;
              await ref
                  .read(splitRepositoryProvider.notifier)
                  .renameSplit(split.id, name);
              // The screen holds the split it was pushed with, so the title
              // would otherwise keep the old name until you navigated away.
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
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
                      // Renaming a routine rewrites what session history calls
                      // it too, which is right — they are the same day.
                      onLongPress: () async {
                        final name = await showRenameDialog(
                          context,
                          title: 'Rename day',
                          current: routine.name,
                        );
                        if (name == null) return;
                        await ref
                            .read(splitRepositoryProvider.notifier)
                            .renameRoutine(routine.id, name);
                      },
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
                  // Reorderable, because the order is the order you do
                  // them in. `orderIndex` has existed since routines did and
                  // was until now only ever written, never changed.
                  : ReorderableListView.builder(
                      scrollController: scrollController,
                      itemCount: routineExercises.length,
                      // onReorderItem rather than the deprecated onReorder:
                      // it hands back an index already adjusted for the moved
                      // item's removal, so there is no off-by-one to undo.
                      onReorderItem: (oldIndex, newIndex) {
                        final ids = [
                          for (final e in routineExercises)
                            e.routineExercise.id,
                        ];
                        ids.insert(newIndex, ids.removeAt(oldIndex));
                        ref
                            .read(splitRepositoryProvider.notifier)
                            .reorderRoutineExercises(ids);
                      },
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
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(
                                Icons.drag_handle,
                                color: OneRepColors.textDisabled,
                              ),
                            ),
                            // The target dialog has always accepted an
                            // `initial`; nothing ever passed one, so a plan
                            // could be set once and never corrected.
                            onTap: () => _editTarget(context, ref, re),
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

  /// Changes what this routine plans for one exercise.
  Future<void> _editTarget(
    BuildContext context,
    WidgetRef ref,
    RoutineExerciseWithName entry,
  ) async {
    final target = await showRoutineTargetDialog(
      context,
      entry.exercise,
      initial: (
        sets: entry.routineExercise.targetSets,
        reps: entry.routineExercise.targetReps,
        distanceMetres: entry.routineExercise.targetDistanceMetres,
        durationSeconds: entry.routineExercise.targetDurationSeconds,
      ),
    );
    if (target == null) return;

    await ref
        .read(splitRepositoryProvider.notifier)
        .updateRoutineExerciseTarget(
          entry.routineExercise.id,
          targetSets: target.sets,
          targetReps: target.reps,
          targetDistanceMetres: target.distanceMetres,
          targetDurationSeconds: target.durationSeconds,
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
  Future<void> _startSession(BuildContext context, WidgetRef ref) =>
      startRoutineSession(
        context,
        ref,
        routineId: routine.id,
        routineName: routine.name,
        // The sheet has to close before anything else: everything after this
        // runs past an async gap, by which point its context is deactivated.
        popFirst: true,
      );
}
