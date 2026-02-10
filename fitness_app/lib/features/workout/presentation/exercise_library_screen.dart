import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/exercise_repository.dart';

class ExerciseLibraryScreen extends ConsumerWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This watches our database stream
    final exercisesAsync = ref.watch(watchExercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
        centerTitle: true,
      ),
      body: exercisesAsync.when(
        // 1. Success State: We have data!
        data: (exercises) => exercises.isEmpty 
          ? const Center(child: Text('No exercises found. Did the seed run?'))
          : ListView.builder(
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
                  title: Text(exercise.name),
                  subtitle: Text('${exercise.bodyPart} • ${exercise.equipmentType}'),
                );
              },
            ),
        // 2. Loading State: Waiting for SQLite to respond
        loading: () => const Center(child: CircularProgressIndicator()),
        // 3. Error State: Something went wrong
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}