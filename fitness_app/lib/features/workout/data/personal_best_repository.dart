import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:fitness_app/core/database/database_provider.dart';
import 'package:fitness_app/core/database/local_database.dart';

part 'personal_best_repository.g.dart';

// ---------------------------------------------------------------------------
// Metric type constants — mirrors workout_tables.dart metricType values.
// ---------------------------------------------------------------------------
class MetricType {
  static const weightReps = 'weightReps';
  static const timeOnly = 'timeOnly';
  static const distanceTime = 'distanceTime';
  static const bodyweightReps = 'bodyweightReps';
}

// ---------------------------------------------------------------------------
// PrResult — returned to UI when a new PR is detected.
// Fields are nullable because different metric types populate different fields.
// ---------------------------------------------------------------------------
class PrResult {
  final int exerciseId;
  final String exerciseName;
  final String metricType;
  // weightReps / bodyweightReps
  final double? weight;
  final int? reps;
  // timeOnly / distanceTime
  final int? durationSeconds;
  // distanceTime
  final double? distanceMetres;

  const PrResult({
    required this.exerciseId,
    required this.exerciseName,
    required this.metricType,
    this.weight,
    this.reps,
    this.durationSeconds,
    this.distanceMetres,
  });

  /// Human-readable summary for the PR banner.
  String get summary {
    switch (metricType) {
      case MetricType.timeOnly:
        final secs = durationSeconds ?? 0;
        final m = secs ~/ 60;
        final s = secs % 60;
        return m > 0
            ? '${m}m ${s.toString().padLeft(2, '0')}s'
            : '${s}s';
      case MetricType.distanceTime:
        final dist = distanceMetres ?? 0;
        final secs = durationSeconds ?? 0;
        final m = secs ~/ 60;
        final s = secs % 60;
        final distStr = dist >= 1000
            ? '${(dist / 1000).toStringAsFixed(1)}km'
            : '${dist.toStringAsFixed(0)}m';
        return '$distStr in ${m}m ${s.toString().padLeft(2, '0')}s';
      case MetricType.bodyweightReps:
        final w = weight ?? 0;
        return w > 0
            ? '${w}kg × ${reps ?? 0} reps'
            : '${reps ?? 0} reps';
      default: // weightReps
        return '${weight ?? 0}kg × ${reps ?? 0} reps';
    }
  }
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

@riverpod
Stream<List<PersonalBest>> watchPrsForExercise(Ref ref, int exerciseId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.personalBests)
        ..where((pb) => pb.exerciseId.equals(exerciseId))
        ..where((pb) => pb.deletedAt.isNull())
        ..orderBy([(pb) => OrderingTerm.asc(pb.reps)]))
      .watch();
}

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

  /// Master PR check — routes to the correct algorithm based on metricType.
  Future<PrResult?> checkAndSavePr({
    required int exerciseId,
    required String exerciseName,
    required String metricType,
    // weightReps / bodyweightReps
    double weight = 0.0,
    int reps = 0,
    // timeOnly
    int? durationSeconds,
    // distanceTime
    double? distanceMetres,
  }) async {
    switch (metricType) {
      case MetricType.timeOnly:
        return _checkTimePr(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          durationSeconds: durationSeconds ?? 0,
        );
      case MetricType.distanceTime:
        return _checkDistanceTimePr(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          distanceMetres: distanceMetres ?? 0,
          durationSeconds: durationSeconds ?? 0,
        );
      case MetricType.bodyweightReps:
        // Bodyweight reps: if weight > 0 treat like weightReps (added weight).
        // Otherwise PR = most reps in a single set.
        if (weight > 0) {
          return _checkWeightRepsPr(
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            metricType: metricType,
            weight: weight,
            reps: reps,
          );
        }
        return _checkBodyweightRepsPr(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          reps: reps,
        );
      default: // weightReps
        return _checkWeightRepsPr(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          metricType: metricType,
          weight: weight,
          reps: reps,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // weightReps — weight is king. One PR row per exercise.
  // A new PR is set when:
  //   1. Weight is higher than the current best (regardless of reps), OR
  //   2. Weight equals current best AND reps are higher.
  // ---------------------------------------------------------------------------

  Future<PrResult?> _checkWeightRepsPr({
    required int exerciseId,
    required String exerciseName,
    required String metricType,
    required double weight,
    required int reps,
  }) async {
    final db = ref.read(databaseProvider);

    // One row per exercise — find any existing PR for this exercise
    final existing = await (db.select(db.personalBests)
          ..where((pb) => pb.exerciseId.equals(exerciseId))
          ..where((pb) => pb.metricType.equals(metricType))
          ..where((pb) => pb.deletedAt.isNull())
          ..orderBy([(pb) => OrderingTerm.desc(pb.weight)])
          ..limit(1))
        .getSingleOrNull();

    bool isNewPr;
    if (existing == null) {
      isNewPr = true;
    } else if (weight > existing.weight) {
      // Higher weight always wins
      isNewPr = true;
    } else if (weight == existing.weight && reps > existing.reps) {
      // Same weight, more reps
      isNewPr = true;
    } else {
      isNewPr = false;
    }

    if (!isNewPr) return null;

    // Upsert — use reps=0 sentinel as the unique key so one row per exercise
    await db.into(db.personalBests).insert(
      PersonalBestsCompanion.insert(
        exerciseId: exerciseId,
        reps: Value(reps),
        weight: Value(weight),
        metricType: Value(metricType),
        achievedAt: DateTime.now(),
      ),
      onConflict: DoUpdate(
        (old) => PersonalBestsCompanion.custom(
          weight: Variable(weight),
          reps: Variable(reps),
          achievedAt: Variable(DateTime.now()),
        ),
        target: [db.personalBests.exerciseId, db.personalBests.metricType],
      ),
    );

    return PrResult(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      metricType: metricType,
      weight: weight,
      reps: reps,
    );
  }

  // ---------------------------------------------------------------------------
  // bodyweightReps — most reps in a single set (no added weight)
  // Uses reps=0 as the unique key slot (sentinel for "max reps" record)
  // ---------------------------------------------------------------------------

  Future<PrResult?> _checkBodyweightRepsPr({
    required int exerciseId,
    required String exerciseName,
    required int reps,
  }) async {
    final db = ref.read(databaseProvider);

    // Use reps=0 as the unique slot for "max reps" record.
    // This avoids needing a new unique constraint.
    final existing = await (db.select(db.personalBests)
          ..where((pb) => pb.exerciseId.equals(exerciseId))
          ..where((pb) => pb.metricType.equals(MetricType.bodyweightReps))
          ..where((pb) => pb.deletedAt.isNull()))
        .getSingleOrNull();

    final isNewPr = existing == null || reps > (existing.reps);
    if (!isNewPr) return null;

    await db.into(db.personalBests).insert(
      PersonalBestsCompanion.insert(
        exerciseId: exerciseId,
        reps: Value(reps),
        weight: const Value(0.0),
        metricType: const Value(MetricType.bodyweightReps),
        achievedAt: DateTime.now(),
      ),
      onConflict: DoUpdate(
        (old) => PersonalBestsCompanion.custom(
          reps: Variable(reps),
          achievedAt: Variable(DateTime.now()),
        ),
        target: [db.personalBests.exerciseId, db.personalBests.metricType],
      ),
    );

    return PrResult(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      metricType: MetricType.bodyweightReps,
      reps: reps,
      weight: 0.0,
    );
  }

  // ---------------------------------------------------------------------------
  // timeOnly — longest duration (higher is better)
  // ---------------------------------------------------------------------------

  Future<PrResult?> _checkTimePr({
    required int exerciseId,
    required String exerciseName,
    required int durationSeconds,
  }) async {
    final db = ref.read(databaseProvider);

    final existing = await (db.select(db.personalBests)
          ..where((pb) => pb.exerciseId.equals(exerciseId))
          ..where((pb) => pb.metricType.equals(MetricType.timeOnly))
          ..where((pb) => pb.deletedAt.isNull()))
        .getSingleOrNull();

    final existingDuration = existing?.durationSeconds ?? 0;
    final isNewPr = existing == null || durationSeconds > existingDuration;
    if (!isNewPr) return null;

    // Use reps=0 as a sentinel for time-only PRs (no rep concept).
    await db.into(db.personalBests).insert(
      PersonalBestsCompanion.insert(
        exerciseId: exerciseId,
        reps: const Value(0),
        weight: const Value(0.0),
        durationSeconds: Value(durationSeconds),
        metricType: const Value(MetricType.timeOnly),
        achievedAt: DateTime.now(),
      ),
      onConflict: DoUpdate(
        (old) => PersonalBestsCompanion.custom(
          durationSeconds: Variable(durationSeconds),
          achievedAt: Variable(DateTime.now()),
        ),
        target: [db.personalBests.exerciseId, db.personalBests.reps],
      ),
    );

    return PrResult(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      metricType: MetricType.timeOnly,
      durationSeconds: durationSeconds,
    );
  }

  // ---------------------------------------------------------------------------
  // distanceTime — shortest time for a given distance (lower is better)
  // ---------------------------------------------------------------------------

  Future<PrResult?> _checkDistanceTimePr({
    required int exerciseId,
    required String exerciseName,
    required double distanceMetres,
    required int durationSeconds,
  }) async {
    final db = ref.read(databaseProvider);

    // PR per distance — find existing record for this exact distance.
    final existing = await (db.select(db.personalBests)
          ..where((pb) => pb.exerciseId.equals(exerciseId))
          ..where((pb) => pb.metricType.equals(MetricType.distanceTime))
          ..where((pb) => pb.distanceMetres.equals(distanceMetres))
          ..where((pb) => pb.deletedAt.isNull()))
        .getSingleOrNull();

    final existingTime = existing?.durationSeconds ?? 999999;
    // Lower time is better for distance PRs
    final isNewPr = existing == null || durationSeconds < existingTime;
    if (!isNewPr) return null;

    // Use reps=0 as sentinel, store distance in distanceMetres column.
    await db.into(db.personalBests).insert(
      PersonalBestsCompanion.insert(
        exerciseId: exerciseId,
        reps: const Value(0),
        weight: const Value(0.0),
        durationSeconds: Value(durationSeconds),
        distanceMetres: Value(distanceMetres),
        metricType: const Value(MetricType.distanceTime),
        achievedAt: DateTime.now(),
      ),
      onConflict: DoUpdate(
        (old) => PersonalBestsCompanion.custom(
          durationSeconds: Variable(durationSeconds),
          achievedAt: Variable(DateTime.now()),
        ),
        target: [db.personalBests.exerciseId, db.personalBests.reps],
      ),
    );

    return PrResult(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      metricType: MetricType.distanceTime,
      durationSeconds: durationSeconds,
      distanceMetres: distanceMetres,
    );
  }

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