// test/features/workout/strength_standards_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/features/workout/data/strength_standards_data.dart';

/// Tests for the strength percentile calculation function.
/// Pure Dart — no DB, no Flutter, no Riverpod.
/// Each test is a specific input/output assertion against the
/// real lookup table data sourced from Strengthlevel.com.
void main() {
  group('hasStrengthStandards', () {
    test('returns true for supported exercises', () {
      expect(hasStrengthStandards('Bench Press'), isTrue);
      expect(hasStrengthStandards('Squat'), isTrue);
      expect(hasStrengthStandards('Deadlift'), isTrue);
      expect(hasStrengthStandards('Shoulder Press'), isTrue);
      expect(hasStrengthStandards('Overhead Press'), isTrue);
      expect(hasStrengthStandards('Bent Over Row'), isTrue);
    });

    test('case-insensitive matching', () {
      expect(hasStrengthStandards('bench press'), isTrue);
      expect(hasStrengthStandards('BENCH PRESS'), isTrue);
      expect(hasStrengthStandards('Bench Press'), isTrue);
    });

    test('returns false for unsupported exercises', () {
      expect(hasStrengthStandards('Cable Fly'), isFalse);
      expect(hasStrengthStandards('Bicep Curl'), isFalse);
      expect(hasStrengthStandards(''), isFalse);
    });
  });

  group('calculatePercentile — null / invalid inputs', () {
    test('returns null for unknown exercise', () {
      final result = calculatePercentile(
        exerciseName: 'Cable Fly',
        sex: Sex.male,
        bodyweightKg: 80,
        liftKg: 60,
      );
      expect(result, isNull);
    });

    test('returns null for zero bodyweight', () {
      final result = calculatePercentile(
        exerciseName: 'Bench Press',
        sex: Sex.male,
        bodyweightKg: 0,
        liftKg: 100,
      );
      expect(result, isNull);
    });

    test('returns null for zero lift', () {
      final result = calculatePercentile(
        exerciseName: 'Bench Press',
        sex: Sex.male,
        bodyweightKg: 80,
        liftKg: 0,
      );
      expect(result, isNull);
    });

    test('returns null for negative lift', () {
      final result = calculatePercentile(
        exerciseName: 'Bench Press',
        sex: Sex.male,
        bodyweightKg: 80,
        liftKg: -10,
      );
      expect(result, isNull);
    });
  });

  group('calculatePercentile — male bench press band boundaries', () {
    // Male, 80kg bodyweight bench press thresholds from Strengthlevel.com:
    // Beginner: 53, Novice: 74, Intermediate: 98, Advanced: 127, Elite: 157

    test('lift below beginner threshold returns 5th percentile', () {
      final result = calculatePercentile(
        exerciseName: 'Bench Press',
        sex: Sex.male,
        bodyweightKg: 80,
        liftKg: 40, // well below beginner (53)
      );
      expect(result, isNotNull);
      expect(result!.percentile, equals(5));
      expect(result.label, equals('Beginner'));
    });

    test('lift at beginner threshold returns beginner band', () {
      final result = calculatePercentile(
        exerciseName: 'Bench Press',
        sex: Sex.male,
        bodyweightKg: 80,
        liftKg: 53, // exactly at beginner
      );
      expect(result!.label, equals('Beginner'));
      expect(result.percentile, inInclusiveRange(5, 20));
    });

    test('lift at novice threshold returns novice band', () {
      final result = calculatePercentile(
        exerciseName: 'Bench Press',
        sex: Sex.male,
        bodyweightKg: 80,
        liftKg: 74, // exactly at novice
      );
      expect(result!.label, equals('Novice'));
      expect(result.percentile, inInclusiveRange(20, 50));
    });

    test('lift at intermediate threshold returns intermediate band', () {
      final result = calculatePercentile(
        exerciseName: 'Bench Press',
        sex: Sex.male,
        bodyweightKg: 80,
        liftKg: 98, // exactly at intermediate
      );
      expect(result!.label, equals('Intermediate'));
      expect(result.percentile, inInclusiveRange(50, 80));
    });

    test('lift at advanced threshold returns advanced band', () {
      final result = calculatePercentile(
        exerciseName: 'Bench Press',
        sex: Sex.male,
        bodyweightKg: 80,
        liftKg: 127, // exactly at advanced
      );
      expect(result!.label, equals('Advanced'));
      expect(result.percentile, inInclusiveRange(80, 95));
    });

    test('lift at elite threshold returns elite band at 95th percentile', () {
      final result = calculatePercentile(
        exerciseName: 'Bench Press',
        sex: Sex.male,
        bodyweightKg: 80,
        liftKg: 157, // exactly at elite
      );
      expect(result!.label, equals('Elite'));
      expect(result.percentile, equals(95));
    });

    test('lift above elite threshold still returns elite (capped at 95)', () {
      final result = calculatePercentile(
        exerciseName: 'Bench Press',
        sex: Sex.male,
        bodyweightKg: 80,
        liftKg: 250, // superhuman
      );
      expect(result!.label, equals('Elite'));
      expect(result.percentile, equals(95));
    });
  });

  group('calculatePercentile — female squat', () {
    // Female, 60kg bodyweight squat thresholds:
    // Beginner: 29, Novice: 47, Intermediate: 70, Advanced: 97, Elite: 128

    test('beginner female squatter', () {
      final result = calculatePercentile(
        exerciseName: 'Squat',
        sex: Sex.female,
        bodyweightKg: 60,
        liftKg: 35,
      );
      expect(result!.label, equals('Beginner'));
    });

    test('intermediate female squatter', () {
      final result = calculatePercentile(
        exerciseName: 'Squat',
        sex: Sex.female,
        bodyweightKg: 60,
        liftKg: 70,
      );
      expect(result!.label, equals('Intermediate'));
      expect(result.percentile, equals(50));
    });
  });

  group('calculatePercentile — bodyweight clamping', () {
    test(
      'bodyweight below minimum bracket clamps to lowest bracket (male 50kg)',
      () {
        // Male bench press lowest bracket is 50kg.
        // A 40kg user should clamp to the 50kg bracket.
        final result40 = calculatePercentile(
          exerciseName: 'Bench Press',
          sex: Sex.male,
          bodyweightKg: 40, // below minimum
          liftKg: 57, // intermediate threshold at 50kg bracket
        );
        final result50 = calculatePercentile(
          exerciseName: 'Bench Press',
          sex: Sex.male,
          bodyweightKg: 50, // exactly at minimum
          liftKg: 57,
        );
        // Both should produce the same result — same bracket used
        expect(result40!.label, equals(result50!.label));
        expect(result40.percentile, equals(result50.percentile));
      },
    );

    test('bodyweight above maximum bracket clamps to highest bracket', () {
      // Male bench press highest bracket is 140kg.
      final result150 = calculatePercentile(
        exerciseName: 'Bench Press',
        sex: Sex.male,
        bodyweightKg: 150, // above maximum
        liftKg: 163, // intermediate at 140kg bracket
      );
      final result140 = calculatePercentile(
        exerciseName: 'Bench Press',
        sex: Sex.male,
        bodyweightKg: 140,
        liftKg: 163,
      );
      expect(result150!.label, equals(result140!.label));
    });
  });

  group('calculatePercentile — sex differentiation', () {
    test(
      'same lift at same bodyweight produces different percentiles for M/F',
      () {
        // Male and female standards are different — same lift should
        // produce different percentile results.
        final male = calculatePercentile(
          exerciseName: 'Bench Press',
          sex: Sex.male,
          bodyweightKg: 70,
          liftKg: 80,
        );
        final female = calculatePercentile(
          exerciseName: 'Bench Press',
          sex: Sex.female,
          bodyweightKg: 70,
          liftKg: 80,
        );
        expect(male, isNotNull);
        expect(female, isNotNull);
        // 80kg bench for a 70kg male is around intermediate.
        // 80kg bench for a 70kg female is elite-level.
        // They must differ.
        expect(male!.percentile, isNot(equals(female!.percentile)));
      },
    );
  });

  group('calculatePercentile — interpolation', () {
    test(
      'lift halfway between novice and intermediate gives ~35th percentile',
      () {
        // Male, 80kg: novice=74, intermediate=98. Halfway = 86.
        // Linear interpolation: 20 + 0.5 * (50-20) = 35.
        final result = calculatePercentile(
          exerciseName: 'Bench Press',
          sex: Sex.male,
          bodyweightKg: 80,
          liftKg: 86,
        );
        expect(result!.percentile, inInclusiveRange(33, 37));
      },
    );

    test(
      'lift just above threshold gets higher percentile than at threshold',
      () {
        final atThreshold = calculatePercentile(
          exerciseName: 'Bench Press',
          sex: Sex.male,
          bodyweightKg: 80,
          liftKg: 74, // novice threshold
        );
        final justAbove = calculatePercentile(
          exerciseName: 'Bench Press',
          sex: Sex.male,
          bodyweightKg: 80,
          liftKg: 80, // above novice
        );
        expect(justAbove!.percentile, greaterThan(atThreshold!.percentile));
      },
    );
  });

  group('calculatePercentile — alias exercises', () {
    test('Overhead Press resolves to same standards as Shoulder Press', () {
      final ohp = calculatePercentile(
        exerciseName: 'Overhead Press',
        sex: Sex.male,
        bodyweightKg: 80,
        liftKg: 64,
      );
      final sp = calculatePercentile(
        exerciseName: 'Shoulder Press',
        sex: Sex.male,
        bodyweightKg: 80,
        liftKg: 64,
      );
      expect(ohp!.percentile, equals(sp!.percentile));
      expect(ohp.label, equals(sp.label));
    });
  });
}
