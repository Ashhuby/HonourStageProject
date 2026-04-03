import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// Metric type — defines what a set records and how PRs are compared.
// Stored as a string in SQLite for readability and forward compatibility.
// ---------------------------------------------------------------------------
// weightReps:     weight (kg) + reps. PR = highest weight for a given rep count.
// timeOnly:       duration (seconds) only. PR = longest duration. e.g. Plank.
// distanceTime:   distance (metres) + time (seconds). PR = shortest time for
//                 a given distance. e.g. 5km run.
// bodyweightReps: reps only, no weight tracked. PR = most reps in a set.
//                 Can also add weight (belt) — treated as weightReps when > 0.
// ---------------------------------------------------------------------------

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get bodyPart => text()();
  TextColumn get equipmentType => text()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
<<<<<<< HEAD
  // Sync columns — only used for custom exercises (isCustom == true).
  // Seeded default exercises are global and never synced per-user.
=======
  // metricType — one of: weightReps, timeOnly, distanceTime, bodyweightReps
  // Defaults to weightReps so existing exercises are unaffected.
  TextColumn get metricType =>
      text().withDefault(const Constant('weightReps'))();
  // Sync columns — only used for custom exercises (isCustom == true).
>>>>>>> develop
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

// THE PLAN: The PPL Split
class WorkoutSplits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

// THE BLUEPRINT: The "Day" template
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

// THE LINK: Which exercises belong to a routine template
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

// THE EVENT: A specific trip to the gym
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

// THE DATA: The actual weight/reps/time/distance logged per set.
// Fields used depend on metricType of the exercise:
//   weightReps:     weight + reps
//   timeOnly:       durationSeconds only (weight=0, reps=0)
//   distanceTime:   distanceMetres + durationSeconds (weight=0, reps=0)
//   bodyweightReps: reps only (weight=0 unless added weight via belt)
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  RealColumn get weight => real().withDefault(const Constant(0.0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  // Time-based fields
  IntColumn get durationSeconds => integer().nullable()();
  // Distance-based fields
  RealColumn get distanceMetres => real().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

// THE RECORD: Best performance ever for a given exercise.
// What constitutes a "best" depends on metricType:
//   weightReps:     highest weight for a given rep count → UNIQUE (exerciseId, reps)
//   timeOnly:       longest duration → UNIQUE (exerciseId, metricType)
//   distanceTime:   shortest time for a given distance → UNIQUE (exerciseId, distanceMetres)
//   bodyweightReps: most reps in a single set → UNIQUE (exerciseId, metricType)
//
// durationSeconds and distanceMetres are nullable — only populated for
// relevant metric types. weight and reps default to 0 for non-applicable types.
class PersonalBests extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  // weightReps / bodyweightReps fields
  IntColumn get reps => integer().withDefault(const Constant(0))();
  RealColumn get weight => real().withDefault(const Constant(0.0))();
  // timeOnly / distanceTime fields
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get distanceMetres => real().nullable()();
  // metricType stored here so PR queries don't need to join Exercises
  TextColumn get metricType =>
      text().withDefault(const Constant('weightReps'))();
  DateTimeColumn get achievedAt => dateTime()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        // weightReps: one PR per rep count
        {exerciseId, reps},
      ];
}

// THE ACHIEVEMENT: A badge earned (or not yet earned) by the user.
class Badges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get badgeKey => text().unique()();
  DateTimeColumn get earnedAt => dateTime().nullable()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

// THE RECORD: Best weight ever lifted for a given exercise + rep count.
class PersonalBests extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get reps => integer()();
  RealColumn get weight => real()();
  DateTimeColumn get achievedAt => dateTime()();
  // Sync columns
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {exerciseId, reps},
      ];
}

// THE ACHIEVEMENT: A badge earned (or not yet earned) by the user.
class Badges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get badgeKey => text().unique()();
  DateTimeColumn get earnedAt => dateTime().nullable()();
  // Sync columns
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}