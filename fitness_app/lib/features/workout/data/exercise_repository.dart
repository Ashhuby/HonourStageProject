import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fitness_app/core/database/database_provider.dart'; 
import 'package:fitness_app/core/database/local_database.dart';

part 'exercise_repository.g.dart';

@riverpod
Stream<List<Exercise>> watchExercises(WatchExercisesRef ref) {
  final db = ref.watch(databaseProvider);
  
  return db.select(db.exercises).watch();
}