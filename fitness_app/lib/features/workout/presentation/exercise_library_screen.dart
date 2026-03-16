import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/exercise_repository.dart';

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
                decoration: const InputDecoration(labelText: 'Exercise Name'),
                autofocus: true,
              ),
              TextField(
                controller: bodyPartController,
                decoration: const InputDecoration(labelText: 'Body Part'),
              ),
              TextField(
                controller: equipmentController,
                decoration: const InputDecoration(labelText: 'Equipment'),
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
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(exerciseRepositoryProvider.notifier).addExercise(
                      nameController.text,
                      bodyPartController.text,
                      equipmentController.text,
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Add to Library'),
          ),
        ],
      ),
    );
  }
}