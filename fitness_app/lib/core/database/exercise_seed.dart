import '../../features/workout/domain/muscle.dart';

/// One row of the default exercise library.
typedef SeedExercise = ({
  String name,
  String equipment,
  String metricType,
  Muscle primary,
  List<Muscle> secondary,
});

/// The 41 exercises every install starts with.
///
/// Shared deliberately: `AppDatabase._seedExercises` writes these on a fresh
/// install, and the v9 migration reads the same list to backfill muscle rows
/// for a library that already exists. Two copies would drift apart, and the
/// migration matches on [name] — so a name that differed between them would
/// silently leave those exercises unclassified.
///
/// Being a plain const list, it is also testable without a database, which
/// `_seedExercises` itself is not (it is skipped under `_isTesting`).
const List<SeedExercise> kSeedExercises = [
  // --- Chest ---------------------------------------------------------------
  (
    name: 'Bench Press',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.chest,
    secondary: [Muscle.triceps, Muscle.frontDelts],
  ),
  (
    name: 'Incline Bench Press',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.chest,
    secondary: [Muscle.frontDelts, Muscle.triceps],
  ),
  (
    name: 'Chest Fly',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.chest,
    secondary: [Muscle.frontDelts],
  ),
  (
    name: 'Dips',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.chest,
    secondary: [Muscle.triceps, Muscle.frontDelts],
  ),
  (
    name: 'Cable Fly',
    equipment: 'Cable',
    metricType: 'weightReps',
    primary: Muscle.chest,
    secondary: [Muscle.frontDelts],
  ),

  // --- Back ----------------------------------------------------------------
  // Deadlift is filed under Lower Back rather than Glutes/Hamstrings: it is an
  // erector-limited hinge, and Back is where the v8 refile established users
  // look for it. It still surfaces under a Legs filter as a secondary match.
  (
    name: 'Deadlift',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.lowerBack,
    secondary: [
      Muscle.glutes,
      Muscle.hamstrings,
      Muscle.traps,
      Muscle.lats,
      Muscle.forearms,
    ],
  ),
  (
    name: 'Barbell Row',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.lats,
    secondary: [
      Muscle.traps,
      Muscle.rearDelts,
      Muscle.biceps,
      Muscle.lowerBack,
    ],
  ),
  (
    name: 'Pull Ups',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.lats,
    secondary: [Muscle.biceps, Muscle.forearms, Muscle.rearDelts],
  ),
  (
    name: 'Chin Ups',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.lats,
    secondary: [Muscle.biceps, Muscle.forearms],
  ),
  (
    name: 'Lat Pulldown',
    equipment: 'Cable',
    metricType: 'weightReps',
    primary: Muscle.lats,
    secondary: [Muscle.biceps, Muscle.rearDelts, Muscle.forearms],
  ),
  (
    name: 'Seated Cable Row',
    equipment: 'Cable',
    metricType: 'weightReps',
    primary: Muscle.lats,
    secondary: [Muscle.traps, Muscle.rearDelts, Muscle.biceps],
  ),
  (
    name: 'T-Bar Row',
    equipment: 'Machine',
    metricType: 'weightReps',
    primary: Muscle.lats,
    secondary: [Muscle.traps, Muscle.rearDelts, Muscle.biceps],
  ),
  (
    name: 'Dead Hang',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    primary: Muscle.lats,
    secondary: [Muscle.forearms, Muscle.traps],
  ),

  // --- Legs ----------------------------------------------------------------
  (
    name: 'Squat',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.quads,
    secondary: [Muscle.glutes, Muscle.hamstrings, Muscle.lowerBack, Muscle.abs],
  ),
  (
    name: 'Romanian Deadlift',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.hamstrings,
    secondary: [Muscle.glutes, Muscle.lowerBack, Muscle.forearms],
  ),
  (
    name: 'Leg Press',
    equipment: 'Machine',
    metricType: 'weightReps',
    primary: Muscle.quads,
    secondary: [Muscle.glutes, Muscle.hamstrings],
  ),
  (
    name: 'Lunges',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.quads,
    secondary: [Muscle.glutes, Muscle.hamstrings],
  ),
  (
    name: 'Leg Curl',
    equipment: 'Machine',
    metricType: 'weightReps',
    primary: Muscle.hamstrings,
    secondary: [Muscle.calves],
  ),
  (
    name: 'Leg Extension',
    equipment: 'Machine',
    metricType: 'weightReps',
    primary: Muscle.quads,
    secondary: [],
  ),
  (
    name: 'Calf Raise',
    equipment: 'Machine',
    metricType: 'weightReps',
    primary: Muscle.calves,
    secondary: [],
  ),

  // --- Shoulders -----------------------------------------------------------
  (
    name: 'Shoulder Press',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.frontDelts,
    secondary: [Muscle.sideDelts, Muscle.triceps],
  ),
  (
    name: 'Overhead Press',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.frontDelts,
    secondary: [Muscle.sideDelts, Muscle.triceps, Muscle.abs],
  ),
  (
    name: 'Lateral Raise',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.sideDelts,
    secondary: [Muscle.traps],
  ),
  (
    name: 'Front Raise',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.frontDelts,
    secondary: [Muscle.sideDelts],
  ),
  (
    name: 'Face Pull',
    equipment: 'Cable',
    metricType: 'weightReps',
    primary: Muscle.rearDelts,
    secondary: [Muscle.traps],
  ),
  (
    name: 'Shrugs',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.traps,
    secondary: [Muscle.forearms],
  ),

  // --- Arms ----------------------------------------------------------------
  (
    name: 'Barbell Curl',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.biceps,
    secondary: [Muscle.forearms],
  ),
  (
    name: 'Dumbbell Curl',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.biceps,
    secondary: [Muscle.forearms],
  ),
  (
    name: 'Hammer Curl',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.biceps,
    secondary: [Muscle.forearms],
  ),
  (
    name: 'Tricep Pushdown',
    equipment: 'Cable',
    metricType: 'weightReps',
    primary: Muscle.triceps,
    secondary: [],
  ),
  (
    name: 'Skull Crushers',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.triceps,
    secondary: [],
  ),
  (
    name: 'Close Grip Bench',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.triceps,
    secondary: [Muscle.chest, Muscle.frontDelts],
  ),

  // --- Core ----------------------------------------------------------------
  (
    name: 'Plank',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    primary: Muscle.abs,
    secondary: [Muscle.obliques, Muscle.lowerBack],
  ),
  (
    name: 'Crunches',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.abs,
    secondary: [],
  ),
  (
    name: 'Russian Twist',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.obliques,
    secondary: [Muscle.abs],
  ),
  (
    name: 'Leg Raise',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.abs,
    secondary: [Muscle.obliques],
  ),
  (
    name: 'Ab Wheel',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.abs,
    secondary: [Muscle.lats, Muscle.lowerBack],
  ),
  (
    name: 'Cable Crunch',
    equipment: 'Cable',
    metricType: 'weightReps',
    primary: Muscle.abs,
    secondary: [Muscle.obliques],
  ),

  // --- Cardio --------------------------------------------------------------
  (
    name: 'Running',
    equipment: 'Body Weight',
    metricType: 'distanceTime',
    primary: Muscle.fullBody,
    secondary: [Muscle.quads, Muscle.hamstrings, Muscle.glutes, Muscle.calves],
  ),
  (
    name: 'Cycling',
    equipment: 'Machine',
    metricType: 'distanceTime',
    primary: Muscle.fullBody,
    secondary: [Muscle.quads, Muscle.glutes, Muscle.calves],
  ),
  (
    name: 'Rowing Machine',
    equipment: 'Machine',
    metricType: 'distanceTime',
    primary: Muscle.fullBody,
    secondary: [Muscle.lats, Muscle.quads, Muscle.biceps, Muscle.lowerBack],
  ),
];
