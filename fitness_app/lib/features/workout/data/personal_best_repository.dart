import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';

part 'personal_best_repository.g.dart';

// ---------------------------------------------------------------------------
// Data class returned to the UI when a new PR is detected.
// Kept separate from the Drift-generated PersonalBest row so the UI layer
// has a clean, intention-revealing type to pattern-match on.
// ---------------------------------------------------------------------------
class PrResult {
  final int exerciseId;
  final String exerciseName;
  final double weight;
  final int reps;

  const PrResult({
    required this.exerciseId,
    required this.exerciseName,
    required this.weight,
    required this.reps,
  });
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

/// Watches all PRs for a single exercise, ordered by rep count ascending.
/// Used on the exercise detail / progress screen.
@riverpod
Stream<List<PersonalBest>> watchPrsForExercise(Ref ref, int exerciseId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.personalBests)
        ..where((pb) => pb.exerciseId.equals(exerciseId))
        ..where((pb) => pb.deletedAt.isNull())
        ..orderBy([(pb) => OrderingTerm.asc(pb.reps)]))
      .watch();
}

/// Returns the single heaviest PR for an exercise regardless of rep count.
/// "Best lift" for use in strength percentile benchmarking.
@riverpod
Future<PersonalBest?> getBestLiftForExercise(Ref ref, int exerciseId) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.personalBests)
        ..where((pb) => pb.exerciseId.equals(exerciseId))
        ..where((pb) => pb.deletedAt.isNull())
        ..orderBy([(pb) => OrderingTerm.desc(pb.weight)])
        ..limit(1))
      .getSingleOrNull();
}

/// Watches all PRs across all exercises. Used on the badges screen to count
/// total PRs earned (for the 'pr_10' badge trigger).
@riverpod
Stream<List<PersonalBest>> watchAllPrs(Ref ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.personalBests)
        ..where((pb) => pb.deletedAt.isNull()))
      .watch();
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

@riverpod
class PersonalBestRepository extends _$PersonalBestRepository {
  @override
  void build() {}

  /// Core PR detection algorithm.
  ///
  /// Checks whether [weight] at [reps] for [exerciseId] beats the existing
  /// record (if any). If it does, upserts the new PR and returns a [PrResult]
  /// so the caller can notify the user. Returns null if no PR was set.
  ///
  /// Definition: a PR is the highest weight lifted for a SPECIFIC rep count.
  /// 100kg x 5 reps and 80kg x 10 reps are tracked independently.
  /// Rationale: conflating rep counts (e.g. using 1RM equivalence formulas)
  /// introduces estimation error and confuses users. Direct comparison is
  /// unambiguous and matches how athletes naturally think about PRs.
  Future<PrResult?> checkAndSavePr({
    required int exerciseId,
    required String exerciseName,
    required double weight,
    required int reps,
  }) async {
    final db = ref.read(databaseProvider);

    // Fetch the existing PR for this exact (exercise, reps) combination.
    final existing = await (db.select(db.personalBests)
          ..where((pb) => pb.exerciseId.equals(exerciseId))
          ..where((pb) => pb.reps.equals(reps))
          ..where((pb) => pb.deletedAt.isNull()))
        .getSingleOrNull();

    // No PR exists yet for this rep count — any completed set is a PR.
    // Weight is beaten — strictly greater than, not equal.
    // Equal weight at same reps is not a new PR; it's a match.
    final isNewPr = existing == null || weight > existing.weight;

    if (!isNewPr) return null;

    // Upsert: insert if no row exists for (exerciseId, reps),
    // update weight + achievedAt if the new weight is better.
    // The unique constraint on (exerciseId, reps) defined in workout_tables.dart
    // makes this a clean single-statement operation.
    await db.into(db.personalBests).insertOnConflictUpdate(
          PersonalBestsCompanion.insert(
            exerciseId: exerciseId,
            reps: reps,
            weight: weight,
            achievedAt: DateTime.now(),
          ),
        );

    return PrResult(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      weight: weight,
      reps: reps,
    );
  }

  /// Returns the total count of all-time PRs set across all exercises.
  /// Used by BadgeService to evaluate the 'first_pr' and 'pr_10' triggers.
  Future<int> getTotalPrCount() async {
    final db = ref.read(databaseProvider);
    final countExpr = db.personalBests.id.count();
    final query = db.selectOnly(db.personalBests)
      ..where(db.personalBests.deletedAt.isNull())
      ..addColumns([countExpr]);
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }
}