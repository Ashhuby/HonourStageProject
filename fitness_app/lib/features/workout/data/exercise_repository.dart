import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';

// This must match the filename exactly
part 'exercise_repository.g.dart'; 

@riverpod
class ExerciseRepository extends _$ExerciseRepository {
  @override
  void build() {
    // No initialization needed for this notifier
  }

  Future<void> addExercise(String name, String bodyPart, String equipmentType) async {
    final db = ref.read(databaseProvider);
    
    await db.into(db.exercises).insert(
      ExercisesCompanion.insert(
        name: name,
        bodyPart: bodyPart,
        equipmentType: equipmentType,
      ),
    );
  }
}

// Keep your existing stream provider below if it's in this same file
@riverpod
Stream<List<Exercise>> watchExercises(WatchExercisesRef ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.exercises).watch();
}