import 'package:drift/drift.dart';

/// Catalogue of exercises available to the user.
///
/// Pre-seeded with 40 default exercises on database creation.
/// Users may add custom exercises; only rows where [isCustom] is true
/// are synchronised to the remote database.
///
/// [metricType] determines which fields are recorded during a set and how
/// personal bests are compared. Values are defined in [MetricType] and
/// stored as strings for readability and forward compatibility:
///   - weightReps:     weight (kg) + reps. PR = highest weight, then most reps.
///   - timeOnly:       duration (seconds) only. PR = longest duration.
///   - distanceTime:   distance (metres) + time (seconds). PR = shortest time.
///   - bodyweightReps: reps only. PR = most reps in a single set.
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get bodyPart => text()();
  TextColumn get equipmentType => text()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  // Defaults to weightReps so all existing exercises are unaffected by migrations.
  TextColumn get metricType =>
      text().withDefault(const Constant('weightReps'))();

  /// What kind of training this is: `strength`, `cardio` or `mobility`.
  ///
  /// Stores the `ExerciseCategory` enum's `name` — a code identifier, like
  /// `exercise_muscles.muscle` and deliberately unlike [bodyPart], which
  /// stores a display label and is the mistake this column does not repeat.
  ///
  /// Not derivable, which is what justifies storing it: [metricType] cannot
  /// tell a Plank from a hamstring stretch, the primary muscle cannot tell
  /// Running from a Squat, and [equipmentType] files Leg Press, Cycling and
  /// Rowing Machine all as `Machine`.
  TextColumn get category => text().withDefault(const Constant('strength'))();

  /// The within-category section for the one category whose section cannot be
  /// derived. NULL for Strength and Mobility, whose second level is the
  /// primary muscle's group and is therefore already stored.
  ///
  /// The null means "not applicable", not "unknown" — the trigger pair in
  /// `_guardCategoryModality` makes that a constraint rather than a
  /// convention.
  TextColumn get modality => text().nullable()();

  // Sync columns — only written for custom exercises (isCustom == true).
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Which muscles an exercise trains, and in what role.
///
/// The associative entity resolving the many-to-many between [Exercises] and
/// the `Muscle` vocabulary. Exactly one row per exercise carries [isPrimary],
/// enforced by a partial unique index created in the migration — SQLite cannot
/// express "exactly one" as a table constraint, and drift's `@TableIndex`
/// carries no `WHERE` predicate.
///
/// The muscle's group is deliberately NOT stored: group is functionally
/// dependent on muscle, so persisting it would be a transitive dependency and
/// a second place for the two to disagree. It is derived from the `Muscle`
/// enum in Dart.
///
/// These rows carry no sync columns of their own. Only custom exercises sync,
/// and their muscles travel as a projection on the parent's remote row, so
/// this table has no independent remote identity to track.
class ExerciseMuscles extends Table {
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();

  /// The `Muscle` enum's `name` (e.g. `frontDelts`), not its display label —
  /// a code identifier, stable under UI copy changes.
  TextColumn get muscle => text().withLength(min: 1, max: 32)();

  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();

  /// A muscle appears at most once per exercise, in one role — so an exercise
  /// cannot list Chest as both its primary and a secondary.
  @override
  Set<Column> get primaryKey => {exerciseId, muscle};
}

/// A named training programme (e.g. Push/Pull/Legs, Upper/Lower).
///
/// Contains one or more [WorkoutRoutines] representing individual training days.
class WorkoutSplits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// How this split repeats: `none`, `weekly` or `cycle`. Parsed through
  /// `ScheduleMode.byNameOrNone` rather than read directly, so a value written
  /// by a newer version of the app degrades to an unscheduled split instead of
  /// crashing the list.
  TextColumn get scheduleMode => text().withDefault(const Constant('none'))();

  /// How many slots the rotation has. Seven for `weekly`, where slot 0 is
  /// Monday; anything from two upwards for `cycle`.
  IntColumn get cycleLength => integer().withDefault(const Constant(7))();

  /// The split the Splits tab opens on. At most one row is ever true — see
  /// `SplitRepository.setDefaultSplit`, which clears the others in the same
  /// transaction.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// A single training day template within a [WorkoutSplit] (e.g. Push Day).
///
/// Contains an ordered list of exercises via [RoutineExercises].
class WorkoutRoutines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get splitId =>
      integer().references(WorkoutSplits, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get orderIndex => integer()();

  /// Which slots of the split's rotation this routine occupies, as a
  /// comma-separated list of positions — `'0,3'` is Monday and Thursday on a
  /// weekly split.
  ///
  /// A list rather than a single slot because a six-day push/pull/legs runs
  /// each routine twice a week, and a column rather than a join table because
  /// this is a handful of small integers that are only ever read together with
  /// the routine. Parsed by `parseSlots`, which is total: anything it cannot
  /// read becomes an unscheduled routine rather than an error.
  TextColumn get scheduleSlots => text().nullable()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Junction table linking exercises to a routine with ordering and targets.
class RoutineExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().references(WorkoutRoutines, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get orderIndex => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetReps => integer().withDefault(const Constant(10))();

  /// The target for an exercise that is not measured in reps.
  ///
  /// Both null for a lift, where [targetReps] is the plan. A run planned as
  /// "3 sets of 10 reps" was the only thing a routine could say about it,
  /// which is to say nothing at all.
  ///
  /// Which one applies follows the exercise's metric type: `distanceTime`
  /// reads [targetDistanceMetres], `timeOnly` reads [targetDurationSeconds].
  /// Storing both keeps a routine's plan intact if the exercise's metric type
  /// is later changed.
  RealColumn get targetDistanceMetres => real().nullable()();
  IntColumn get targetDurationSeconds => integer().nullable()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// A single completed or in-progress gym session.
///
/// A session without a [routineId] is a freestyle session.
/// Sessions with a null [endTime] are treated as in-progress and are not synced.
class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().nullable().references(WorkoutRoutines, #id)();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get sessionNote => text().nullable()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// A single logged set within a session.
///
/// The fields populated depend on the exercise's [metricType]:
///   - weightReps:     [weight] + [reps]
///   - timeOnly:       [durationSeconds] only
///   - distanceTime:   [distanceMetres] + [durationSeconds]
///   - bodyweightReps: [reps] only (optional [weight] for added load via belt)
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  RealColumn get weight => real().withDefault(const Constant(0.0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get distanceMetres => real().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// The current personal best for a given exercise.
///
/// One row per exercise per [metricType], with one exception: distanceTime
/// keeps a record per distance, because a 400m time and a 5k time are
/// different achievements. [distanceMetres] is therefore part of the record's
/// identity and is 0 for every other metric type — never null, so the unique
/// key can include it (SQLite treats NULLs as distinct, which would let
/// duplicates through).
///
/// Comparators by metric type:
///   - weightReps / weighted bodyweightReps: heaviest weight wins; at equal
///     weight, more reps wins.
///   - bodyweightReps with no added weight: most reps wins.
///   - timeOnly:     longest duration wins.
///   - distanceTime: shortest duration for that distance wins.
///
/// [reps] and [weight] are 0 for metric types where they do not apply, and
/// [durationSeconds] is null unless used. [metricType] is stored here so PR
/// queries avoid a join to [Exercises].
class PersonalBests extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  RealColumn get weight => real().withDefault(const Constant(0.0))();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get distanceMetres => real().withDefault(const Constant(0.0))();
  TextColumn get metricType =>
      text().withDefault(const Constant('weightReps'))();
  DateTimeColumn get achievedAt => dateTime()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    // The identity of a record — also the upsert conflict target. Keyed on
    // reps before v7, which silently created a row per rep count and broke
    // every comparator that assumed a single row.
    {exerciseId, metricType, distanceMetres},
  ];
}

/// A badge that may be earned (or not yet earned) by the user.
///
/// All badge rows are pre-seeded with [earnedAt] = null. Earning a badge
/// sets [earnedAt] to the timestamp of the triggering event and marks the
/// row dirty ([syncedAt] = null) for upload.
class Badges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get badgeKey => text().unique()();
  DateTimeColumn get earnedAt => dateTime().nullable()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
