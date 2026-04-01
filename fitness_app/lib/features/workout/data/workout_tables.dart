import 'package:drift/drift.dart';

// THE DICTIONARY: What is a "Bench Press"?
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get bodyPart => text()();
  TextColumn get equipmentType => text()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  // Sync columns — only used for custom exercises (isCustom == true).
  // Seeded default exercises are global and never synced per-user.
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
  // Sync columns
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
  // Sync columns
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
  // Sync columns
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
  // Sync columns
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

// THE DATA: The actual weight and reps
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  RealColumn get weight => real()();
  IntColumn get reps => integer()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  // Sync columns
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