import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/data/exercise_catalogue.dart';
import 'package:fitness_app/features/workout/domain/activity.dart';
import 'package:fitness_app/features/workout/domain/muscle.dart';
import 'package:fitness_app/features/workout/presentation/widgets/exercise_filter.dart';

/// Tests for the pure search, grouping and counting helpers behind the
/// exercise picker and the body map.
///
/// These carry no database or widget dependency by design: the picker filters
/// the already-streamed catalogue in Dart rather than issuing a second query,
/// so the whole of that behaviour is testable as plain functions.
void main() {
  ExerciseWithMuscles ex(
    int id,
    String name,
    Muscle primary, {
    List<Muscle> secondary = const [],
    String equipment = 'Barbell',
    ExerciseCategory category = ExerciseCategory.strength,
    CardioModality? modality,
  }) {
    return ExerciseWithMuscles(
      exercise: Exercise(
        id: id,
        name: name,
        bodyPart: primary.group.label,
        equipmentType: equipment,
        isCustom: false,
        metricType: 'weightReps',
        category: category.name,
        modality: modality?.name,
      ),
      primary: primary,
      secondary: secondary,
    );
  }

  final benchPress = ex(
    1,
    'Bench Press',
    Muscle.chest,
    secondary: [Muscle.triceps, Muscle.frontDelts],
  );
  final inclineBench = ex(2, 'Incline Bench Press', Muscle.chest);
  final bentOverRow = ex(
    3,
    'Barbell Bent Over Row',
    Muscle.lats,
    secondary: [Muscle.biceps],
  );
  final squat = ex(4, 'Squat', Muscle.quads, secondary: [Muscle.glutes]);
  final plank = ex(
    5,
    'Plank',
    Muscle.abs,
    secondary: [Muscle.obliques],
    equipment: 'Body Weight',
  );
  final pushdown = ex(6, 'Tricep Pushdown', Muscle.triceps, equipment: 'Cable');

  final running = ex(
    7,
    'Running',
    Muscle.quads,
    secondary: [Muscle.calves],
    equipment: 'Body Weight',
    category: ExerciseCategory.cardio,
    modality: CardioModality.run,
  );
  final rower = ex(
    8,
    'Rowing Machine',
    Muscle.lats,
    equipment: 'Machine',
    category: ExerciseCategory.cardio,
    modality: CardioModality.row,
  );
  final hamstringStretch = ex(
    9,
    'Hamstring Stretch',
    Muscle.hamstrings,
    equipment: 'Body Weight',
    category: ExerciseCategory.mobility,
  );

  final library = [
    benchPress,
    inclineBench,
    bentOverRow,
    squat,
    plank,
    pushdown,
    running,
    rower,
    hamstringStretch,
  ];

  // ---------------------------------------------------------------------------
  // filterExercises
  // ---------------------------------------------------------------------------

  group('filterExercises', () {
    test('an empty query returns everything, untouched', () {
      expect(filterExercises(library), hasLength(library.length));
    });

    test('matches names case-insensitively on a substring', () {
      final matches = filterExercises(library, query: 'BENCH');
      expect(matches.map((e) => e.id), containsAll([1, 2]));
      expect(matches.any((e) => e.id == 4), isFalse);
    });

    test(
      'ranks names starting with the query above ones merely containing it',
      () {
        // "Bench Press" starts with "ben"; the other two only contain it, so
        // they fall in behind, ordered alphabetically among themselves.
        final matches = filterExercises(library, query: 'ben');
        expect(matches.first.name, 'Bench Press');
        expect(matches.map((e) => e.name).skip(1), [
          'Barbell Bent Over Row',
          'Incline Bench Press',
        ]);
      },
    );

    test('surrounding whitespace in the query is ignored', () {
      expect(filterExercises(library, query: '  squat  '), hasLength(1));
    });

    test('excluded ids are dropped', () {
      final matches = filterExercises(library, excludeIds: {1, 4});
      expect(matches.map((e) => e.id), isNot(contains(1)));
      expect(matches.map((e) => e.id), isNot(contains(4)));
      expect(matches, hasLength(library.length - 2));
    });

    test('no match yields an empty list rather than everything', () {
      expect(filterExercises(library, query: 'zercher'), isEmpty);
    });
  });

  group('filterExercises, by muscle', () {
    test('a primary match ranks above a secondary one', () {
      // Tricep Pushdown is a triceps exercise; Bench Press merely uses them.
      final matches = filterExercises(library, muscle: Muscle.triceps);
      expect(matches.map((e) => e.name), ['Tricep Pushdown', 'Bench Press']);
    });

    test('a group filter matches through a secondary muscle', () {
      // Barbell Row's only arm involvement is biceps, as a secondary.
      final matches = filterExercises(library, group: MuscleGroup.arms);
      expect(matches.map((e) => e.name), contains('Barbell Bent Over Row'));
    });

    test('a muscle filter narrows a group filter rather than replacing it', () {
      final byGroup = filterExercises(library, group: MuscleGroup.arms);
      final byMuscle = filterExercises(
        library,
        group: MuscleGroup.arms,
        muscle: Muscle.triceps,
      );
      expect(byGroup.length, greaterThan(byMuscle.length));
      expect(byMuscle.map((e) => e.name), ['Tricep Pushdown', 'Bench Press']);
    });

    test('includeSecondary: false keeps only primary matches', () {
      final matches = filterExercises(
        library,
        muscle: Muscle.triceps,
        includeSecondary: false,
      );
      expect(matches.map((e) => e.name), ['Tricep Pushdown']);
    });

    test('query and muscle compose, ranking within each band', () {
      // Both match "press" and both hit chest, but only Bench Press has it as
      // a primary... so does Incline. Prefix ranking then decides.
      final matches = filterExercises(
        library,
        query: 'press',
        group: MuscleGroup.chest,
      );
      expect(matches.map((e) => e.name), [
        'Bench Press',
        'Incline Bench Press',
      ]);
    });

    test('a muscle nothing trains yields an empty list', () {
      expect(filterExercises(library, muscle: Muscle.rearDelts), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Taxonomy
  // ---------------------------------------------------------------------------

  group('Muscle and MuscleGroup', () {
    test('every muscle name round-trips', () {
      for (final muscle in Muscle.values) {
        expect(Muscle.byNameOrNull(muscle.name), muscle);
      }
    });

    test('an unknown muscle name returns null rather than throwing', () {
      // A row written by a newer app version must not crash an older one.
      expect(Muscle.byNameOrNull('serratus'), isNull);
      expect(Muscle.byNameOrNull(null), isNull);
    });

    test('every group label round-trips, tolerating casing and padding', () {
      for (final group in MuscleGroup.values) {
        expect(MuscleGroup.fromLabel(group.label), group);
      }
      expect(MuscleGroup.fromLabel('  legs '), MuscleGroup.legs);
      expect(MuscleGroup.fromLabel('CHEST'), MuscleGroup.chest);
      expect(MuscleGroup.fromLabel('Forearms'), isNull);
    });

    test('every group owns at least one muscle', () {
      for (final group in MuscleGroup.values) {
        expect(group.muscles, isNotEmpty, reason: group.label);
      }
    });

    test('every muscle is reachable from its group', () {
      for (final muscle in Muscle.values) {
        expect(muscle.group.muscles, contains(muscle));
      }
    });

    test('the legacy labels all map to a muscle', () {
      const legacy = {
        'Chest': Muscle.chest,
        'Back': Muscle.lats,
        'Legs': Muscle.quads,
        'Shoulders': Muscle.frontDelts,
        'Biceps': Muscle.biceps,
        'Triceps': Muscle.triceps,
        'Core': Muscle.abs,
      };
      legacy.forEach((label, muscle) {
        expect(muscleForBodyPartOrNull(label), muscle, reason: label);
      });
    });

    test('a label naming no muscle returns null rather than guessing', () {
      // 'Whole Body' is the interesting one: it was a real stored value, and
      // it names no muscle. Such a row is left unassigned — visible and
      // correctable — rather than being given a fabricated anatomical claim.
      expect(muscleForBodyPartOrNull('Whole Body'), isNull);
      expect(muscleForBodyPartOrNull('Nonsense'), isNull);
      expect(muscleForBodyPartOrNull(''), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Grouping
  // ---------------------------------------------------------------------------

  group('groupExercises, unfiltered', () {
    test('sections follow group declaration order', () {
      final sections = groupExercises(library);
      expect(sections.map((s) => s.title), [
        'Chest',
        'Back',
        'Arms',
        'Core',
        'Legs',
      ]);
    });

    test('exercises are alphabetical within a section', () {
      final sections = groupExercises([
        ex(9, 'Zercher Squat', Muscle.quads),
        squat,
      ]);
      expect(sections.single.exercises.map((e) => e.name), [
        'Squat',
        'Zercher Squat',
      ]);
    });

    test('an exercise is filed by its primary only', () {
      // Bench Press hits triceps and front delts too, but appears under Chest
      // and nowhere else.
      final sections = groupExercises([benchPress]);
      expect(sections.single.title, 'Chest');
      expect(sections, hasLength(1));
    });

    test('a row with no primary lands under Unassigned, last', () {
      const orphan = ExerciseWithMuscles(
        exercise: Exercise(
          id: 99,
          name: 'Mystery Lift',
          bodyPart: 'Whatever',
          equipmentType: 'Other',
          isCustom: true,
          metricType: 'weightReps',
          category: 'strength',
        ),
        primary: null,
        secondary: [],
      );
      final sections = groupExercises([...library, orphan]);
      expect(sections.last.title, 'Unassigned');
      expect(sections.last.exercises.single.name, 'Mystery Lift');
    });

    test('empty input yields no sections', () {
      expect(groupExercises([]), isEmpty);
    });
  });

  group('groupExercises, filtered', () {
    test('splits into primary matches then "Also works"', () {
      final matches = filterExercises(library, muscle: Muscle.triceps);
      final sections = groupExercises(matches, muscle: Muscle.triceps);

      expect(sections.map((s) => s.title), ['Triceps', 'Also works Triceps']);
      expect(sections.first.exercises.map((e) => e.name), ['Tricep Pushdown']);
      expect(sections.last.exercises.map((e) => e.name), ['Bench Press']);
    });

    test('an empty half is omitted rather than rendered blank', () {
      final matches = filterExercises(library, muscle: Muscle.obliques);
      final sections = groupExercises(matches, muscle: Muscle.obliques);
      // Plank hits obliques only as a secondary, so there is no primary half.
      expect(sections.map((s) => s.title), ['Also works Obliques']);
    });

    test('a secondary match is not misfiled under its own primary', () {
      // Tapping Arms must not show Bench Press under a "Chest" heading.
      final matches = filterExercises(library, group: MuscleGroup.arms);
      final sections = groupExercises(matches, group: MuscleGroup.arms);
      expect(sections.map((s) => s.title), isNot(contains('Chest')));
    });
  });

  test('no exercise ever appears in two sections', () {
    // Not cosmetic: ExerciseLibraryScreen flattens sections into one sliver
    // and keys each Dismissible on exercise.id, so a repeat throws at runtime.
    void check(List<ExerciseSection> sections, String label) {
      final ids = sections.expand((s) => s.exercises).map((e) => e.id).toList();
      expect(
        ids.toSet(),
        hasLength(ids.length),
        reason: 'duplicate row while filtering by $label',
      );
    }

    check(groupExercises(filterExercises(library)), 'nothing');
    for (final group in MuscleGroup.values) {
      check(
        groupExercises(filterExercises(library, group: group), group: group),
        group.label,
      );
    }
    for (final muscle in Muscle.values) {
      check(
        groupExercises(
          filterExercises(library, muscle: muscle),
          muscle: muscle,
        ),
        muscle.label,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // Counting
  // ---------------------------------------------------------------------------

  group('countByMuscleGroup', () {
    test('primary counts partition the library', () {
      final counts = countByMuscleGroup(library);
      final total = counts.values.fold(0, (sum, c) => sum + c.primary);
      expect(total, library.length);
    });

    test('total counts every role, so it is at least the primary count', () {
      final counts = countByMuscleGroup(library);
      for (final entry in counts.entries) {
        expect(
          entry.value.total,
          greaterThanOrEqualTo(entry.value.primary),
          reason: entry.key.label,
        );
      }
    });

    test('a group counts an exercise once however many muscles it hits', () {
      // Bench Press hits triceps AND front delts; front delts are Shoulders,
      // triceps are Arms, so Arms sees it once, not twice.
      final counts = countByMuscleGroup([benchPress]);
      expect(counts[MuscleGroup.arms]?.total, 1);
      expect(counts[MuscleGroup.chest]?.primary, 1);
    });

    test('a group with no exercises is absent, so it reads as zero', () {
      final counts = countByMuscleGroup(library);
      // Nothing in the fixture trains legs as a secondary either, so Legs is
      // present with a primary count; Chest has no secondary use at all.
      expect(counts[MuscleGroup.core]?.primary, 1);
      expect(counts[MuscleGroup.shoulders]?.primary, 0);
    });
  });

  group('countByMuscle', () {
    test('separates primary from secondary use', () {
      final counts = countByMuscle(library);
      expect(counts[Muscle.triceps]?.primary, 1); // Tricep Pushdown
      expect(counts[Muscle.triceps]?.total, 2); // + Bench Press
    });

    test('a muscle nothing trains is absent', () {
      expect(countByMuscle(library)[Muscle.rearDelts], isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  group('categories', () {
    test('a category filter is a strict subset', () {
      final all = filterExercises(library);
      for (final category in ExerciseCategory.values) {
        final subset = filterExercises(library, category: category);
        expect(subset.length, lessThan(all.length), reason: category.label);
        expect(
          subset.every((e) => e.category == category),
          isTrue,
          reason: category.label,
        );
      }
    });

    test('the categories partition the library', () {
      var total = 0;
      for (final category in ExerciseCategory.values) {
        total += filterExercises(library, category: category).length;
      }
      expect(total, library.length);
    });

    test('cardio sections by modality, not by muscle', () {
      // Running's primary is Quads. Under Strength that would file it in Legs;
      // under Cardio it belongs under Run, because that is how it is looked
      // for.
      final matches = filterExercises(
        library,
        category: ExerciseCategory.cardio,
      );
      final sections = groupExercises(
        matches,
        category: ExerciseCategory.cardio,
      );
      expect(sections.map((s) => s.title), ['Run', 'Row']);
    });

    test('mobility keeps sectioning by muscle group', () {
      // A stretch is looked up by the muscle it targets, so it keeps the
      // diagram and the anatomical sections.
      final matches = filterExercises(
        library,
        category: ExerciseCategory.mobility,
      );
      final sections = groupExercises(
        matches,
        category: ExerciseCategory.mobility,
      );
      expect(sections.single.title, 'Legs');
    });

    test('an unrecognised stored category files as strength', () {
      // Total where the parser is partial: a value from a newer client must
      // land somewhere rather than vanish from the library.
      const odd = ExerciseWithMuscles(
        exercise: Exercise(
          id: 50,
          name: 'Something New',
          bodyPart: 'Chest',
          equipmentType: 'Barbell',
          isCustom: false,
          metricType: 'weightReps',
          category: 'breathwork',
        ),
        primary: Muscle.chest,
        secondary: [],
      );
      expect(odd.category, ExerciseCategory.strength);
      expect(odd.modality, isNull);
    });

    test('a cardio row with no stored modality still has a section', () {
      const odd = ExerciseWithMuscles(
        exercise: Exercise(
          id: 51,
          name: 'Mystery Cardio',
          bodyPart: 'Legs',
          equipmentType: 'Other',
          isCustom: true,
          metricType: 'distanceTime',
          category: 'cardio',
        ),
        primary: Muscle.quads,
        secondary: [],
      );
      // Otherwise it would fall out of every section and grouping would stop
      // being a partition.
      expect(odd.modality, CardioModality.other);
    });

    test('countByModality counts each cardio exercise once', () {
      final counts = countByModality(
        filterExercises(library, category: ExerciseCategory.cardio),
      );
      expect(counts[CardioModality.run], 1);
      expect(counts[CardioModality.row], 1);
      expect(counts[CardioModality.cycle], isNull);
    });
  });
}
