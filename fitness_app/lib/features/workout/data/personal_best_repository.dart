import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/local_database.dart';

part 'personal_best_repository.g.dart';

/// Defines what a set records and how personal bests are compared.
///
/// Stored as a string in SQLite for readability and forward compatibility.
/// The [value] field is the string written to the database.
enum MetricType {
  weightReps('weightReps'),
  timeOnly('timeOnly'),
  distanceTime('distanceTime'),
  bodyweightReps('bodyweightReps');

  const MetricType(this.value);

  /// The string value stored in the database.
  final String value;

  /// Parses a database string back to a [MetricType].
  /// Returns [MetricType.weightReps] as a safe default for unknown values.
  static MetricType fromString(String s) {
    return MetricType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => MetricType.weightReps,
    );
  }
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
      case 'timeOnly':
        final secs = durationSeconds ?? 0;
        final m = secs ~/ 60;
        final s = secs % 60;
        return m > 0 ? '${m}m ${s.toString().padLeft(2, '0')}s' : '${s}s';
      case 'distanceTime':
        final dist = distanceMetres ?? 0;
        final secs = durationSeconds ?? 0;
        final m = secs ~/ 60;
        final s = secs % 60;
        final distStr = dist >= 1000
            ? '${(dist / 1000).toStringAsFixed(1)}km'
            : '${dist.toStringAsFixed(0)}m';
        return '$distStr in ${m}m ${s.toString().padLeft(2, '0')}s';
      case 'bodyweightReps':
        final w = weight ?? 0;
        return w > 0 ? '${w}kg × ${reps ?? 0} reps' : '${reps ?? 0} reps';
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

/// The single record shown as the target to beat during a session.
///
/// Most metric types keep one row per exercise, but distanceTime keeps one
/// row per distance, so the rows are reduced rather than simply taking the
/// first. Emits null when the exercise has no personal best yet.
@riverpod
Stream<PersonalBest?> watchBestPrForExercise(Ref ref, int exerciseId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.personalBests)
        ..where((pb) => pb.exerciseId.equals(exerciseId))
        ..where((pb) => pb.deletedAt.isNull()))
      .watch()
      .map(
        (prs) => prs.isEmpty
            ? null
            : prs.reduce((best, pb) => _beats(pb, best) ? pb : best),
      );
}

/// Whether [candidate] is the stronger record of the two, judged by the
/// comparator that defines a PR for its metric type.
bool _beats(PersonalBest candidate, PersonalBest current) {
  switch (MetricType.fromString(candidate.metricType)) {
    case MetricType.timeOnly:
      // Longest hold wins.
      return (candidate.durationSeconds ?? 0) > (current.durationSeconds ?? 0);
    case MetricType.distanceTime:
      // One row per distance — the longest distance is the headline record.
      return candidate.distanceMetres > current.distanceMetres;
    case MetricType.bodyweightReps:
      return candidate.reps > current.reps;
    case MetricType.weightReps:
      if (candidate.weight != current.weight) {
        return candidate.weight > current.weight;
      }
      return candidate.reps > current.reps;
  }
}

@riverpod
Stream<List<PersonalBest>> watchAllPrs(Ref ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.personalBests,
  )..where((pb) => pb.deletedAt.isNull())).watch();
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
      case 'timeOnly':
        return _checkTimePr(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          durationSeconds: durationSeconds ?? 0,
        );
      case 'distanceTime':
        return _checkDistanceTimePr(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          distanceMetres: distanceMetres ?? 0,
          durationSeconds: durationSeconds ?? 0,
        );
      case 'bodyweightReps':
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
    final existing = await _existingRecord(
      exerciseId: exerciseId,
      metricType: metricType,
    );

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

    await _upsertRecord(
      exerciseId: exerciseId,
      metricType: metricType,
      weight: weight,
      reps: reps,
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
  // bodyweightReps — most reps in a single set (no added weight).
  // Sets with added weight route to _checkWeightRepsPr and share this record:
  // whichever set last won its comparator is the one held.
  // ---------------------------------------------------------------------------

  Future<PrResult?> _checkBodyweightRepsPr({
    required int exerciseId,
    required String exerciseName,
    required int reps,
  }) async {
    final existing = await _existingRecord(
      exerciseId: exerciseId,
      metricType: MetricType.bodyweightReps.value,
    );

    final isNewPr = existing == null || reps > existing.reps;
    if (!isNewPr) return null;

    await _upsertRecord(
      exerciseId: exerciseId,
      metricType: MetricType.bodyweightReps.value,
      reps: reps,
    );

    return PrResult(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      metricType: MetricType.bodyweightReps.value,
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
    final existing = await _existingRecord(
      exerciseId: exerciseId,
      metricType: MetricType.timeOnly.value,
    );

    final existingDuration = existing?.durationSeconds ?? 0;
    final isNewPr = existing == null || durationSeconds > existingDuration;
    if (!isNewPr) return null;

    await _upsertRecord(
      exerciseId: exerciseId,
      metricType: MetricType.timeOnly.value,
      durationSeconds: durationSeconds,
    );

    return PrResult(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      metricType: MetricType.timeOnly.value,
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
    // PR per distance — find the existing record for this exact distance.
    final existing = await _existingRecord(
      exerciseId: exerciseId,
      metricType: MetricType.distanceTime.value,
      distanceMetres: distanceMetres,
    );

    // Sentinel value used when no existing distance PR is recorded.
    const noExistingTime = 999999;
    final existingTime = existing?.durationSeconds ?? noExistingTime;
    // Lower time is better for distance PRs
    final isNewPr = existing == null || durationSeconds < existingTime;
    if (!isNewPr) return null;

    await _upsertRecord(
      exerciseId: exerciseId,
      metricType: MetricType.distanceTime.value,
      durationSeconds: durationSeconds,
      distanceMetres: distanceMetres,
    );

    return PrResult(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      metricType: MetricType.distanceTime.value,
      durationSeconds: durationSeconds,
      distanceMetres: distanceMetres,
    );
  }

  // ---------------------------------------------------------------------------
  // Record access — one row per (exercise, metric type, distance)
  // ---------------------------------------------------------------------------

  /// The record currently held for this exercise under [metricType], or null
  /// if none has been set.
  Future<PersonalBest?> _existingRecord({
    required int exerciseId,
    required String metricType,
    double distanceMetres = 0.0,
  }) {
    final db = ref.read(databaseProvider);
    return (db.select(db.personalBests)
          ..where((pb) => pb.exerciseId.equals(exerciseId))
          ..where((pb) => pb.metricType.equals(metricType))
          ..where((pb) => pb.distanceMetres.equals(distanceMetres))
          ..where((pb) => pb.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Writes the record, replacing the one held for the same
  /// (exercise, metric type, distance).
  ///
  /// Every field the comparators read is written on conflict — a partial
  /// update leaves a record describing a set that never happened. [syncedAt]
  /// is cleared so the new record uploads on the next sync.
  Future<void> _upsertRecord({
    required int exerciseId,
    required String metricType,
    double weight = 0.0,
    int reps = 0,
    int? durationSeconds,
    double distanceMetres = 0.0,
  }) async {
    final db = ref.read(databaseProvider);
    final achievedAt = DateTime.now();

    await db
        .into(db.personalBests)
        .insert(
          PersonalBestsCompanion.insert(
            exerciseId: exerciseId,
            reps: Value(reps),
            weight: Value(weight),
            durationSeconds: Value(durationSeconds),
            distanceMetres: Value(distanceMetres),
            metricType: Value(metricType),
            achievedAt: achievedAt,
          ),
          onConflict: DoUpdate(
            (old) => PersonalBestsCompanion.custom(
              weight: Variable(weight),
              reps: Variable(reps),
              durationSeconds: Variable(durationSeconds),
              distanceMetres: Variable(distanceMetres),
              achievedAt: Variable(achievedAt),
              syncedAt: const Variable(null),
            ),
            target: [
              db.personalBests.exerciseId,
              db.personalBests.metricType,
              db.personalBests.distanceMetres,
            ],
          ),
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
