import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/features/workout/domain/progress_series.dart';

/// Tests the series a progress chart plots.
///
/// The bug these pin is not cardio-specific. `volume = weight × reps` is
/// identically zero for three of the four metric types — a bodyweight Pull Up
/// records `weight = 0`, a Plank and a run both record `reps = 0` — and a list
/// of zeroes is not empty, so the `isEmpty` guard never fired and the chart
/// drew a flat line labelled in kilograms.
void main() {
  SetSample sample(
    DateTime date, {
    double weight = 0,
    int reps = 0,
    int? durationSeconds,
    double? distanceMetres,
  }) => (
    date: date,
    weight: weight,
    reps: reps,
    durationSeconds: durationSeconds,
    distanceMetres: distanceMetres,
  );

  final day1 = DateTime(2026, 6, 1, 9);
  final day2 = DateTime(2026, 6, 3, 9);

  // ---------------------------------------------------------------------------
  // Choosing the series
  // ---------------------------------------------------------------------------

  group('metric selection', () {
    test('the detail chart asks "how much", the record chart "how good"', () {
      // Distance for the detail chart — cardio's analogue of volume — but
      // pace for the record chart, because a longer run is not a better one.
      expect(detailMetricFor('distanceTime'), ProgressMetric.distance);
      expect(recordMetricFor('distanceTime'), ProgressMetric.speed);
    });

    test('the other three types agree between the two charts', () {
      for (final type in ['weightReps', 'bodyweightReps', 'timeOnly']) {
        expect(detailMetricFor(type), recordMetricFor(type), reason: type);
      }
    });

    test('an unrecognised metric type falls back to volume', () {
      // Matches MetricType.fromString's coercion — a row from a newer client
      // renders as a lift rather than crashing.
      expect(detailMetricFor('somethingNew'), ProgressMetric.volume);
    });
  });

  // ---------------------------------------------------------------------------
  // The zero-series bug
  // ---------------------------------------------------------------------------

  group('a metric that does not apply yields no points', () {
    test('volume over bodyweight sets is empty, not a row of zeroes', () {
      final samples = [
        sample(day1, reps: 12),
        sample(day2, reps: 15),
      ];
      // This is the regression: weight is 0, so every product is 0.
      expect(sessionTotals(samples, ProgressMetric.volume), isEmpty);
      // ...but the right metric for those sets does have something to say.
      expect(sessionTotals(samples, ProgressMetric.reps), hasLength(2));
    });

    test('volume over a plank is empty', () {
      final samples = [sample(day1, durationSeconds: 90)];
      expect(sessionTotals(samples, ProgressMetric.volume), isEmpty);
      expect(sessionTotals(samples, ProgressMetric.duration), hasLength(1));
    });

    test('volume over a run is empty', () {
      final samples = [
        sample(day1, durationSeconds: 1500, distanceMetres: 5000),
      ];
      expect(sessionTotals(samples, ProgressMetric.volume), isEmpty);
      expect(sessionTotals(samples, ProgressMetric.distance), hasLength(1));
    });

    test('no sets at all yields no points', () {
      expect(sessionTotals(const [], ProgressMetric.volume), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Aggregation
  // ---------------------------------------------------------------------------

  group('sessionTotals', () {
    test('sums volume across the sets of one day', () {
      final points = sessionTotals([
        sample(day1, weight: 80, reps: 5),
        sample(day1, weight: 80, reps: 5),
        sample(day2, weight: 85, reps: 5),
      ], ProgressMetric.volume);

      expect(points.map((p) => p.value), [800, 425]);
    });

    test('several sessions on one day collapse into one point', () {
      final points = sessionTotals([
        sample(DateTime(2026, 6, 1, 8), weight: 50, reps: 10),
        sample(DateTime(2026, 6, 1, 19), weight: 50, reps: 10),
      ], ProgressMetric.volume);

      expect(points, hasLength(1));
      expect(points.single.value, 1000);
    });

    test('points come back in date order', () {
      final points = sessionTotals([
        sample(day2, reps: 5),
        sample(day1, reps: 5),
      ], ProgressMetric.reps);

      expect(points.first.date, day1);
      expect(points.last.date, day2);
    });
  });

  group('sessionBests', () {
    test('takes the best single set, not the sum', () {
      final points = sessionBests([
        sample(day1, weight: 80, reps: 5),
        sample(day1, weight: 100, reps: 1),
      ], ProgressMetric.volume);

      expect(points.single.value, 400, reason: '80x5 beats 100x1 on volume');
    });

    test('speed still aggregates the whole session rather than one set', () {
      // The old code took the fastest individual set, so a single 400 m
      // interval could stand in for an hour of running.
      final points = sessionBests([
        sample(day1, durationSeconds: 80, distanceMetres: 400),
        sample(day1, durationSeconds: 3600, distanceMetres: 10000),
      ], ProgressMetric.speed);

      // (400 + 10000) / (80 + 3600) = 2.826 m/s, not the interval's 5.0
      expect(points.single.value, closeTo(2.826, 0.001));
    });

    test('a session with time but no distance yields no speed', () {
      final points = sessionBests([
        sample(day1, durationSeconds: 600),
      ], ProgressMetric.speed);
      expect(points, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  group('formatSeriesValue', () {
    test('speed is stored as m/s but read as pace', () {
      // Ordering is by speed so that up means faster; the label is the unit a
      // runner actually reads. 3.33 m/s is 5:00/km.
      expect(formatSeriesValue(1000 / 300, ProgressMetric.speed), '5:00/km');
    });

    test('a long effort has no ceiling', () {
      // The previous code plotted 10000 - seconds, so anything past 2h46m
      // went negative and was clipped off the axis.
      final marathonPace = 42195 / (4 * 3600); // 4 hours
      expect(
        formatSeriesValue(marathonPace, ProgressMetric.speed),
        '5:41/km',
      );
      expect(marathonPace, greaterThan(0));
    });

    test('zero speed renders as a dash rather than dividing by zero', () {
      expect(formatSeriesValue(0, ProgressMetric.speed), '—');
    });

    test('distance switches to kilometres above 1000 m', () {
      expect(formatSeriesValue(400, ProgressMetric.distance), '400m');
      expect(formatSeriesValue(5000, ProgressMetric.distance), '5.0km');
    });

    test('duration reads as a clock', () {
      expect(formatSeriesValue(90, ProgressMetric.duration), '1:30');
      expect(formatSeriesValue(45, ProgressMetric.duration), '45s');
    });

    test('volume and reps read plainly', () {
      expect(formatSeriesValue(1250, ProgressMetric.volume), '1250kg');
      expect(formatSeriesValue(12, ProgressMetric.reps), '12');
    });
  });
}
