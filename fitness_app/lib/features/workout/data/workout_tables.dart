import 'package:drift/drift.dart';

// 1. THE DICTIONARY: What is a "Bench Press"?
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get bodyPart => text()(); // e.g., Chest, Legs
  TextColumn get equipmentType => text()(); // e.g., Barbell, Dumbbell
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

// 2. THE PLAN: The PPL Split
class WorkoutSplits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // e.g., "6-Day PPL"
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 3. THE BLUEPRINT: The "Day" template
class WorkoutRoutines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get splitId => integer().references(WorkoutSplits, #id)();
  TextColumn get name => text()(); // e.g., "Push Day"
  IntColumn get orderIndex => integer()(); // To keep Day 1, Day 2 in order
}

// 4. THE EVENT: A specific trip to the gym
class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Nullable routineId allows for "Freestyle" sessions!
  IntColumn get routineId => integer().nullable().references(WorkoutRoutines, #id)();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get sessionNote => text().nullable()();
}

// 5. THE DATA: The actual weight and reps
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(WorkoutSessions, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  RealColumn get weight => real()();
  IntColumn get reps => integer()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}