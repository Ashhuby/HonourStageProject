import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/features/workout/domain/distance_bucket.dart';

/// Tests the standard distances a cardio record is filed under.
///
/// Keyed on the raw distance, 5000 m then 5200 m found no existing record and
/// inserted unconditionally, so every logged run was a "personal best" and the
/// record table grew without bound.
void main() {
  group('distanceBucketFor', () {
    test('an exact standard distance maps to itself', () {
      for (final bucket in kDistanceBuckets) {
        expect(distanceBucketFor(bucket), bucket, reason: '$bucket');
      }
    });

    test('rounds down to the distance actually completed', () {
      // The run that started all this: 5200 m is a 5 km, not a new record
      // distance of its own.
      expect(distanceBucketFor(5200), 5000);
      expect(distanceBucketFor(1000.4), 1000);
      expect(distanceBucketFor(42200), 42195);
    });

    test('never rounds up — 4.9 km is not a 5 km', () {
      expect(distanceBucketFor(4999), 3000);
      expect(distanceBucketFor(399), 200);
    });

    test('below the smallest standard distance there is no record', () {
      expect(distanceBucketFor(99), isNull);
      expect(distanceBucketFor(0), isNull);
    });

    test(
      'a distance typed as exactly the bucket is not lost to float error',
      () {
        expect(distanceBucketFor(5000.0), 5000);
        expect(distanceBucketFor(1609.34), 1609.34);
      },
    );
  });

  group('kDistanceBuckets', () {
    test('is sorted, unique and strictly increasing', () {
      final sorted = [...kDistanceBuckets]..sort();
      expect(kDistanceBuckets, sorted);
      expect(kDistanceBuckets.toSet(), hasLength(kDistanceBuckets.length));
    });

    test('bands stay narrow above the sprint distances', () {
      // Bounds the unfairness of rounding down: within one band a longer,
      // slower effort does not displace a shorter, faster one, so the bands
      // must not be wide. The 100-200-400 steps are 2x, which is tolerable
      // only because those are track distances and get logged exactly.
      for (var i = 1; i < kDistanceBuckets.length; i++) {
        final previous = kDistanceBuckets[i - 1];
        final ratio = kDistanceBuckets[i] / previous;
        expect(
          ratio,
          lessThanOrEqualTo(previous < 400 ? 2.0 : 1.7),
          reason: '$previous -> ${kDistanceBuckets[i]}',
        );
      }
    });
  });

  group('formatDistanceBucket', () {
    test('names the distances that have names', () {
      expect(formatDistanceBucket(42195), 'MARATHON');
      expect(formatDistanceBucket(21097.5), 'HALF');
      expect(formatDistanceBucket(1609.34), '1 MILE');
    });

    test('reads round kilometres as K', () {
      expect(formatDistanceBucket(5000), '5K');
      expect(formatDistanceBucket(10000), '10K');
    });

    test('reads short distances in metres', () {
      expect(formatDistanceBucket(400), '400M');
      expect(formatDistanceBucket(1500), '1500M');
    });

    test('every bucket renders to something non-empty', () {
      for (final bucket in kDistanceBuckets) {
        expect(formatDistanceBucket(bucket), isNotEmpty, reason: '$bucket');
      }
    });
  });
}
