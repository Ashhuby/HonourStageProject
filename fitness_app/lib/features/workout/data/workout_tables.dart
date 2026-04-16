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
  // Sync columns — only written for custom exercises (isCustom == true).
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// A named training programme (e.g. Push/Pull/Legs, Upper/Lower).
///
/// Contains one or more [WorkoutRoutines] representing individual training days.
class WorkoutSplits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
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
/// One row per exercise is maintained by [PersonalBestRepository].
/// For weightReps, weight is the primary comparator; more reps at equal weight
/// constitutes a new PR. All other metric types use a single scalar comparator
/// (duration for timeOnly; time for a given distance in distanceTime).
///
/// [reps] and [weight] default to 0 for metric types where they are not
/// applicable. [durationSeconds] and [distanceMetres] are null unless used.
/// [metricType] is stored here so PR queries avoid a join to [Exercises].
class PersonalBests extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  RealColumn get weight => real().withDefault(const Constant(0.0))();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get distanceMetres => real().nullable()();
  TextColumn get metricType =>
      text().withDefault(const Constant('weightReps'))();
  DateTimeColumn get achievedAt => dateTime()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    // One PR row per exercise — enforced by the upsert conflict target.
    {exerciseId, reps},
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
