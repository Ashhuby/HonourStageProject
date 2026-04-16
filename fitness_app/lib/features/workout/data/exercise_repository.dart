import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/local_database.dart';
import 'package:drift/drift.dart';

// This must match the filename exactly
part 'exercise_repository.g.dart';

@riverpod
class ExerciseRepository extends _$ExerciseRepository {
  @override
  void build() {}

  Future<void> addExercise(
    String name,
    String bodyPart,
    String equipmentType, {
    String metricType = 'weightReps',
  }) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: name,
            bodyPart: bodyPart,
            equipmentType: equipmentType,
            isCustom: const Value(true),
            metricType: Value(metricType),
          ),
        );
  }

  Future<void> deleteExercise(int id) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.exercises)..where((e) => e.id.equals(id))).go();
  }
}

// Keep your existing stream provider below if it's in this same file
@riverpod
Stream<List<Exercise>> watchExercises(Ref ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.exercises)
        ..where((e) => e.deletedAt.isNull())
        ..orderBy([(e) => OrderingTerm.asc(e.name)]))
      .watch();
}
