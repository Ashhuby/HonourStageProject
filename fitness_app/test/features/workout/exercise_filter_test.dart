import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/database/local_database.dart';
import 'package:fitness_app/features/workout/presentation/widgets/body_part.dart';
import 'package:fitness_app/features/workout/presentation/widgets/exercise_filter.dart';

/// Tests for the pure search, grouping and counting helpers behind the
/// exercise picker sheet and the library's body map.
///
/// These carry no database or widget dependency by design: the picker filters
/// the already-streamed list in Dart rather than issuing a second query, so
/// the whole of that behaviour is testable as plain functions.
void main() {
  Exercise exercise(
    int id,
    String name,
    String bodyPart, {
    String equipment = 'Barbell',
  }) {
    return Exercise(
      id: id,
      name: name,
      bodyPart: bodyPart,
      equipmentType: equipment,
      isCustom: false,
      metricType: 'weightReps',
    );
  }

  final library = [
    exercise(1, 'Bench Press', 'Chest'),
    exercise(2, 'Incline Bench Press', 'Chest'),
    exercise(3, 'Barbell Bent Over Row', 'Back'),
    exercise(4, 'Squat', 'Legs'),
    exercise(5, 'Plank', 'Core', equipment: 'Body Weight'),
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

    test('a body part filter keeps only that group', () {
      final matches = filterExercises(library, bodyPart: BodyPart.chest);
      expect(matches.map((e) => e.id), [1, 2]);
    });

    test('query and body part filter compose', () {
      final matches = filterExercises(
        library,
        query: 'press',
        bodyPart: BodyPart.chest,
      );
      expect(matches.map((e) => e.id), containsAll([1, 2]));
      expect(matches, hasLength(2));
    });

    test('excluded ids are dropped', () {
      final matches = filterExercises(library, excludeIds: {1, 4});
      expect(matches.map((e) => e.id), [2, 3, 5]);
    });

    test('no match yields an empty list rather than everything', () {
      expect(filterExercises(library, query: 'zercher'), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // BodyPart
  // ---------------------------------------------------------------------------

  group('BodyPart', () {
    test('every label round-trips', () {
      for (final part in BodyPart.values) {
        expect(BodyPart.fromLabel(part.label), part);
      }
    });

    test('parsing tolerates casing and padding', () {
      expect(BodyPart.fromLabel('  whole body '), BodyPart.wholeBody);
      expect(BodyPart.fromLabel('CHEST'), BodyPart.chest);
    });

    test('an unrecognised value returns null rather than throwing', () {
      // bodyPart is free TEXT with no database constraint, so a row can carry
      // anything — it must degrade to the "Other" section, not blow up.
      expect(BodyPart.fromLabel('Forearms'), isNull);
    });

    test('colorFor falls back for an unrecognised value', () {
      expect(BodyPart.colorFor('Chest'), BodyPart.chest.color);
      expect(BodyPart.colorFor('Forearms'), isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Grouping and counting
  // ---------------------------------------------------------------------------

  group('groupExercisesByBodyPart', () {
    test('sections follow enum declaration order, not insertion order', () {
      final sections = groupExercisesByBodyPart(library);
      expect(sections.map((s) => s.title), ['Chest', 'Back', 'Legs', 'Core']);
    });

    test('exercises are alphabetical within a section', () {
      final sections = groupExercisesByBodyPart([
        exercise(9, 'Zercher Squat', 'Legs'),
        exercise(4, 'Squat', 'Legs'),
      ]);
      expect(sections.single.exercises.map((e) => e.name), [
        'Squat',
        'Zercher Squat',
      ]);
    });

    test('unrecognised body parts collect into a trailing Other section', () {
      final sections = groupExercisesByBodyPart([
        ...library,
        exercise(6, 'Wrist Curl', 'Forearms'),
      ]);
      expect(sections.last.title, 'Other');
      expect(sections.last.bodyPart, isNull);
      expect(sections.last.exercises.single.name, 'Wrist Curl');
    });

    test('empty input yields no sections', () {
      expect(groupExercisesByBodyPart([]), isEmpty);
    });
  });

  group('countByBodyPart', () {
    test('counts each recognised group', () {
      final counts = countByBodyPart(library);
      expect(counts[BodyPart.chest], 2);
      expect(counts[BodyPart.back], 1);
      expect(counts[BodyPart.legs], 1);
      expect(counts[BodyPart.core], 1);
    });

    test('a group with no exercises is absent, so the map reads as zero', () {
      // The body map dims a region on a zero count, so absence and zero must
      // behave the same way.
      final counts = countByBodyPart(library);
      expect(counts[BodyPart.triceps], isNull);
      expect(counts[BodyPart.triceps] ?? 0, 0);
    });

    test('unrecognised body parts are not counted', () {
      final counts = countByBodyPart([exercise(6, 'Wrist Curl', 'Forearms')]);
      expect(counts, isEmpty);
    });
  });
}
