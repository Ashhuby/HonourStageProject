import '../../features/workout/domain/activity.dart';
import '../../features/workout/domain/muscle.dart';

/// One row of the default exercise library.
///
/// A class rather than a record so [category], [modality] and [since] can
/// default — the 41 strength rows say nothing about any of them — and so the
/// const constructor can assert the modality rule at compile time, for the
/// whole const list, alongside the database trigger that enforces it at
/// runtime.
class SeedExercise {
  const SeedExercise({
    required this.name,
    required this.equipment,
    required this.metricType,
    this.primary,
    this.secondary = const [],
    this.category = ExerciseCategory.strength,
    this.modality,
    this.since = 9,
  }) : assert(
         (category == ExerciseCategory.cardio) == (modality != null),
         'modality is required for cardio and forbidden otherwise',
       );

  final String name;
  final String equipment;
  final String metricType;

  /// Null for an activity that trains nothing in particular — a yoga flow,
  /// say. Such a row renders under "Unassigned" rather than being given a
  /// muscle it does not deserve.
  final Muscle? primary;

  final List<Muscle> secondary;
  final ExerciseCategory category;
  final CardioModality? modality;

  /// The schema version that introduced this row.
  ///
  /// The v10 migration inserts only rows newer than the version it is
  /// upgrading *from*. That is the one narrow case where seeding from a
  /// migration is safe: a name that has never shipped cannot have been
  /// deliberately deleted by the user. Without this field someone will
  /// eventually widen the insert and start resurrecting deletions.
  final int since;
}

const List<SeedExercise> kSeedExercises = [
  // --- Chest ---------------------------------------------------------------
  SeedExercise(
    name: 'Bench Press',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.chest,
    secondary: [Muscle.triceps, Muscle.frontDelts],
  ),
  SeedExercise(
    name: 'Incline Bench Press',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.chest,
    secondary: [Muscle.frontDelts, Muscle.triceps],
  ),
  SeedExercise(
    name: 'Chest Fly',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.chest,
    secondary: [Muscle.frontDelts],
  ),
  SeedExercise(
    name: 'Dips',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.chest,
    secondary: [Muscle.triceps, Muscle.frontDelts],
  ),
  SeedExercise(
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
  SeedExercise(
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
  SeedExercise(
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
  SeedExercise(
    name: 'Pull Ups',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.lats,
    secondary: [Muscle.biceps, Muscle.forearms, Muscle.rearDelts],
  ),
  SeedExercise(
    name: 'Chin Ups',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.lats,
    secondary: [Muscle.biceps, Muscle.forearms],
  ),
  SeedExercise(
    name: 'Lat Pulldown',
    equipment: 'Cable',
    metricType: 'weightReps',
    primary: Muscle.lats,
    secondary: [Muscle.biceps, Muscle.rearDelts, Muscle.forearms],
  ),
  SeedExercise(
    name: 'Seated Cable Row',
    equipment: 'Cable',
    metricType: 'weightReps',
    primary: Muscle.lats,
    secondary: [Muscle.traps, Muscle.rearDelts, Muscle.biceps],
  ),
  SeedExercise(
    name: 'T-Bar Row',
    equipment: 'Machine',
    metricType: 'weightReps',
    primary: Muscle.lats,
    secondary: [Muscle.traps, Muscle.rearDelts, Muscle.biceps],
  ),
  SeedExercise(
    name: 'Dead Hang',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    primary: Muscle.lats,
    secondary: [Muscle.forearms, Muscle.traps],
  ),

  // --- Legs ----------------------------------------------------------------
  SeedExercise(
    name: 'Squat',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.quads,
    secondary: [Muscle.glutes, Muscle.hamstrings, Muscle.lowerBack, Muscle.abs],
  ),
  SeedExercise(
    name: 'Romanian Deadlift',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.hamstrings,
    secondary: [Muscle.glutes, Muscle.lowerBack, Muscle.forearms],
  ),
  SeedExercise(
    name: 'Leg Press',
    equipment: 'Machine',
    metricType: 'weightReps',
    primary: Muscle.quads,
    secondary: [Muscle.glutes, Muscle.hamstrings],
  ),
  SeedExercise(
    name: 'Lunges',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.quads,
    secondary: [Muscle.glutes, Muscle.hamstrings],
  ),
  SeedExercise(
    name: 'Leg Curl',
    equipment: 'Machine',
    metricType: 'weightReps',
    primary: Muscle.hamstrings,
    secondary: [Muscle.calves],
  ),
  SeedExercise(
    name: 'Leg Extension',
    equipment: 'Machine',
    metricType: 'weightReps',
    primary: Muscle.quads,
    secondary: [],
  ),
  SeedExercise(
    name: 'Calf Raise',
    equipment: 'Machine',
    metricType: 'weightReps',
    primary: Muscle.calves,
    secondary: [],
  ),

  // --- Shoulders -----------------------------------------------------------
  SeedExercise(
    name: 'Shoulder Press',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.frontDelts,
    secondary: [Muscle.sideDelts, Muscle.triceps],
  ),
  SeedExercise(
    name: 'Overhead Press',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.frontDelts,
    secondary: [Muscle.sideDelts, Muscle.triceps, Muscle.abs],
  ),
  SeedExercise(
    name: 'Lateral Raise',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.sideDelts,
    secondary: [Muscle.traps],
  ),
  SeedExercise(
    name: 'Front Raise',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.frontDelts,
    secondary: [Muscle.sideDelts],
  ),
  SeedExercise(
    name: 'Face Pull',
    equipment: 'Cable',
    metricType: 'weightReps',
    primary: Muscle.rearDelts,
    secondary: [Muscle.traps],
  ),
  SeedExercise(
    name: 'Shrugs',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.traps,
    secondary: [Muscle.forearms],
  ),

  // --- Arms ----------------------------------------------------------------
  SeedExercise(
    name: 'Barbell Curl',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.biceps,
    secondary: [Muscle.forearms],
  ),
  SeedExercise(
    name: 'Dumbbell Curl',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.biceps,
    secondary: [Muscle.forearms],
  ),
  SeedExercise(
    name: 'Hammer Curl',
    equipment: 'Dumbbell',
    metricType: 'weightReps',
    primary: Muscle.biceps,
    secondary: [Muscle.forearms],
  ),
  SeedExercise(
    name: 'Tricep Pushdown',
    equipment: 'Cable',
    metricType: 'weightReps',
    primary: Muscle.triceps,
    secondary: [],
  ),
  SeedExercise(
    name: 'Skull Crushers',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.triceps,
    secondary: [],
  ),
  SeedExercise(
    name: 'Close Grip Bench',
    equipment: 'Barbell',
    metricType: 'weightReps',
    primary: Muscle.triceps,
    secondary: [Muscle.chest, Muscle.frontDelts],
  ),

  // --- Core ----------------------------------------------------------------
  SeedExercise(
    name: 'Plank',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    primary: Muscle.abs,
    secondary: [Muscle.obliques, Muscle.lowerBack],
  ),
  SeedExercise(
    name: 'Crunches',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.abs,
    secondary: [],
  ),
  SeedExercise(
    name: 'Russian Twist',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.obliques,
    secondary: [Muscle.abs],
  ),
  SeedExercise(
    name: 'Leg Raise',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.abs,
    secondary: [Muscle.obliques],
  ),
  SeedExercise(
    name: 'Ab Wheel',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    primary: Muscle.abs,
    secondary: [Muscle.lats, Muscle.lowerBack],
  ),
  SeedExercise(
    name: 'Cable Crunch',
    equipment: 'Cable',
    metricType: 'weightReps',
    primary: Muscle.abs,
    secondary: [Muscle.obliques],
  ),

  // --- Cardio --------------------------------------------------------------
  // Filed by modality, not by muscle: `equipmentType` cannot tell these apart
  // (it calls Leg Press, Cycling and Rowing Machine all "Machine"), and the
  // muscles they work are real but are not how anyone looks for them.
  SeedExercise(
    name: 'Running',
    equipment: 'Body Weight',
    metricType: 'distanceTime',
    category: ExerciseCategory.cardio,
    modality: CardioModality.run,
    primary: Muscle.quads,
    secondary: [Muscle.hamstrings, Muscle.glutes, Muscle.calves],
  ),
  SeedExercise(
    name: 'Treadmill Run',
    equipment: 'Machine',
    metricType: 'distanceTime',
    category: ExerciseCategory.cardio,
    modality: CardioModality.run,
    since: 10,
    primary: Muscle.quads,
    secondary: [Muscle.hamstrings, Muscle.glutes, Muscle.calves],
  ),
  SeedExercise(
    name: 'Incline Walk',
    equipment: 'Machine',
    metricType: 'distanceTime',
    category: ExerciseCategory.cardio,
    modality: CardioModality.run,
    since: 10,
    primary: Muscle.glutes,
    secondary: [Muscle.quads, Muscle.hamstrings, Muscle.calves],
  ),
  SeedExercise(
    name: 'Cycling',
    equipment: 'Machine',
    metricType: 'distanceTime',
    category: ExerciseCategory.cardio,
    modality: CardioModality.cycle,
    primary: Muscle.quads,
    secondary: [Muscle.glutes, Muscle.hamstrings, Muscle.calves],
  ),
  SeedExercise(
    name: 'Outdoor Cycling',
    equipment: 'Other',
    metricType: 'distanceTime',
    category: ExerciseCategory.cardio,
    modality: CardioModality.cycle,
    since: 10,
    primary: Muscle.quads,
    secondary: [Muscle.glutes, Muscle.hamstrings, Muscle.calves],
  ),
  SeedExercise(
    name: 'Assault Bike',
    equipment: 'Machine',
    metricType: 'distanceTime',
    category: ExerciseCategory.cardio,
    modality: CardioModality.cycle,
    since: 10,
    primary: Muscle.quads,
    secondary: [Muscle.glutes, Muscle.frontDelts, Muscle.lats],
  ),
  // Rowing is roughly 60% legs by power, so Quads is the biomechanically
  // honest primary. Lats wins because the primary drives the tile colour and
  // the subtitle, and "Lats - Machine" in blue distinguishes this from
  // Cycling at a glance where "Quads - Machine" in green would not.
  SeedExercise(
    name: 'Rowing Machine',
    equipment: 'Machine',
    metricType: 'distanceTime',
    category: ExerciseCategory.cardio,
    modality: CardioModality.row,
    primary: Muscle.lats,
    secondary: [Muscle.quads, Muscle.glutes, Muscle.biceps, Muscle.lowerBack],
  ),
  SeedExercise(
    name: 'Ski Erg',
    equipment: 'Machine',
    metricType: 'distanceTime',
    category: ExerciseCategory.cardio,
    modality: CardioModality.row,
    since: 10,
    primary: Muscle.lats,
    secondary: [Muscle.triceps, Muscle.abs, Muscle.frontDelts],
  ),
  SeedExercise(
    name: 'Elliptical',
    equipment: 'Machine',
    metricType: 'distanceTime',
    category: ExerciseCategory.cardio,
    modality: CardioModality.other,
    since: 10,
    primary: Muscle.quads,
    secondary: [Muscle.glutes, Muscle.hamstrings, Muscle.calves],
  ),
  SeedExercise(
    name: 'Stair Climber',
    equipment: 'Machine',
    metricType: 'distanceTime',
    category: ExerciseCategory.cardio,
    modality: CardioModality.other,
    since: 10,
    primary: Muscle.glutes,
    secondary: [Muscle.quads, Muscle.calves, Muscle.hamstrings],
  ),
  SeedExercise(
    name: 'Swimming',
    equipment: 'Other',
    metricType: 'distanceTime',
    category: ExerciseCategory.cardio,
    modality: CardioModality.other,
    since: 10,
    primary: Muscle.lats,
    secondary: [Muscle.frontDelts, Muscle.triceps, Muscle.quads, Muscle.abs],
  ),
  SeedExercise(
    name: 'Jump Rope',
    equipment: 'Other',
    metricType: 'timeOnly',
    category: ExerciseCategory.cardio,
    modality: CardioModality.other,
    since: 10,
    primary: Muscle.calves,
    secondary: [Muscle.quads, Muscle.sideDelts, Muscle.forearms],
  ),
  SeedExercise(
    name: 'Sled Push',
    equipment: 'Other',
    metricType: 'distanceTime',
    category: ExerciseCategory.cardio,
    modality: CardioModality.other,
    since: 10,
    primary: Muscle.quads,
    secondary: [Muscle.glutes, Muscle.calves, Muscle.abs],
  ),

  // --- Mobility ------------------------------------------------------------
  // Sectioned by muscle group like Strength, because that is how a stretch is
  // looked for: your hamstrings are tight, so you tap Legs. Two vocabulary
  // limits worth naming — there is no thoracic-erector muscle, so Thoracic
  // Rotation borrows Lats, and there is no IT band.
  SeedExercise(
    name: 'Hamstring Stretch',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.hamstrings,
    secondary: [Muscle.calves, Muscle.lowerBack],
  ),
  SeedExercise(
    name: 'Seated Forward Fold',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.lowerBack,
    secondary: [Muscle.hamstrings, Muscle.calves],
  ),
  SeedExercise(
    name: 'Couch Stretch',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.quads,
    secondary: [Muscle.glutes, Muscle.abs],
  ),
  SeedExercise(
    name: 'Pigeon Pose',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.glutes,
    secondary: [Muscle.lowerBack],
  ),
  SeedExercise(
    name: 'Calf Stretch',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.calves,
    secondary: [Muscle.hamstrings],
  ),
  SeedExercise(
    name: 'Downward Dog',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.hamstrings,
    secondary: [Muscle.calves, Muscle.lats, Muscle.frontDelts],
  ),
  SeedExercise(
    name: 'Childs Pose',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.lats,
    secondary: [Muscle.lowerBack, Muscle.glutes],
  ),
  SeedExercise(
    name: 'Cobra Stretch',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.abs,
    secondary: [Muscle.chest, Muscle.frontDelts],
  ),
  SeedExercise(
    name: 'Doorway Chest Stretch',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.chest,
    secondary: [Muscle.frontDelts],
  ),
  SeedExercise(
    name: 'Overhead Triceps Stretch',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.triceps,
    secondary: [Muscle.lats],
  ),
  SeedExercise(
    name: 'Wrist Flexor Stretch',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.forearms,
  ),
  SeedExercise(
    name: 'Neck and Trap Stretch',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.traps,
    secondary: [Muscle.rearDelts],
  ),
  SeedExercise(
    name: 'Cat-Cow',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.lowerBack,
    secondary: [Muscle.abs],
  ),
  SeedExercise(
    name: 'Thoracic Rotation',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.lats,
    secondary: [Muscle.obliques, Muscle.lowerBack],
  ),
  SeedExercise(
    name: 'Shoulder Dislocates',
    equipment: 'Resistance Band',
    metricType: 'bodyweightReps',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.frontDelts,
    secondary: [Muscle.sideDelts, Muscle.rearDelts, Muscle.traps],
  ),
  SeedExercise(
    name: '90/90 Hip Rotation',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.glutes,
    secondary: [Muscle.obliques],
  ),
  SeedExercise(
    name: 'Worlds Greatest Stretch',
    equipment: 'Body Weight',
    metricType: 'bodyweightReps',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.quads,
    secondary: [Muscle.hamstrings, Muscle.glutes, Muscle.obliques],
  ),
  SeedExercise(
    name: 'Foam Roll Quads',
    equipment: 'Other',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.quads,
  ),
  SeedExercise(
    name: 'Foam Roll Glutes',
    equipment: 'Other',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.glutes,
  ),
  SeedExercise(
    name: 'Foam Roll Upper Back',
    equipment: 'Other',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    primary: Muscle.traps,
    secondary: [Muscle.lats],
  ),
  // A flow works everything and nothing in particular. No primary is the
  // honest answer, and the schema has always allowed it — the index is
  // "at most one primary", not "exactly one".
  SeedExercise(
    name: 'Sun Salutation',
    equipment: 'Body Weight',
    metricType: 'timeOnly',
    category: ExerciseCategory.mobility,
    since: 10,
    secondary: [Muscle.hamstrings, Muscle.lats, Muscle.frontDelts, Muscle.abs],
  ),
];
