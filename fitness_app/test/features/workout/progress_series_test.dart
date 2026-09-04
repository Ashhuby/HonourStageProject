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
      final samples = [sample(day1, reps: 12), sample(day2, reps: 15)];
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

  // ---------------------------------------------------------------------------
  // Reading a series
  // ---------------------------------------------------------------------------

  group('summariseSeries', () {
    SeriesPoint at(int day, double value) =>
        SeriesPoint(date: DateTime(2026, 3, day), value: value);

    test('an empty series has nothing to say', () {
      expect(summariseSeries(const []), isNull);
    });

    test('a single session is still a best', () {
      // One record summarises fine, and reporting it beats an empty panel
      // beside a chart with a dot on it.
      final summary = summariseSeries([at(1, 60)])!;

      expect(summary.sessions, 1);
      expect(summary.best.value, 60);
      expect(summary.first.value, 60);
      expect(summary.latest.value, 60);
      expect(summary.bestIndex, 0);
      expect(summary.changeFraction, 0);
    });

    test('the best is the highest, not the most recent', () {
      final summary = summariseSeries([at(1, 60), at(3, 90), at(5, 70)])!;

      expect(summary.best.value, 90);
      expect(summary.best.date, DateTime(2026, 3, 3));
      expect(summary.bestIndex, 1);
      expect(summary.latest.value, 70);
    });

    test('the first best wins a tie, so the peak stays where it was set', () {
      final summary = summariseSeries([at(1, 90), at(3, 90)])!;
      expect(summary.bestIndex, 0);
    });

    test('the trend runs from the first effort to the latest', () {
      final summary = summariseSeries([at(1, 50), at(3, 80), at(5, 60)])!;

      // Not first-to-best: a chart that only ever reported the peak would
      // read as improvement while the user was going backwards.
      expect(summary.changeFraction, closeTo(0.2, 0.0001));
    });

    test('going backwards reads as negative', () {
      final summary = summariseSeries([at(1, 100), at(3, 75)])!;
      expect(summary.changeFraction, closeTo(-0.25, 0.0001));
    });

    test('a first effort of zero has no multiple, rather than infinity', () {
      final summary = summariseSeries([at(1, 0), at(3, 40)])!;
      expect(summary.changeFraction, 0);
    });
  });

  group('chartRangeFor', () {
    SeriesPoint at(int day, double value) =>
        SeriesPoint(date: DateTime(2026, 3, day), value: value);

    test('an empty series still has a drawable range', () {
      final range = chartRangeFor(const []);
      expect(range.max, greaterThan(range.min));
    });

    test('a flat series is given a window rather than a single line', () {
      // minY == maxY draws the series along an edge, or not at all. A single
      // record is the common case, and it is the one worth seeing.
      final flat = chartRangeFor([at(1, 80), at(3, 80)]);
      expect(flat.max, greaterThan(flat.min));
      expect(flat.min, lessThan(80));
      expect(flat.max, greaterThan(80));

      final single = chartRangeFor([at(1, 80)]);
      expect(single.max, greaterThan(single.min));
    });

    test('a varying series is padded either side of its span', () {
      final range = chartRangeFor([at(1, 60), at(3, 100)]);

      expect(range.min, lessThan(60));
      expect(range.max, greaterThan(100));
    });

    test('never runs below zero, because no metric here can', () {
      // Volume, reps, duration, distance and speed are all non-negative, and
      // an axis starting below zero wastes half the plot.
      final range = chartRangeFor([at(1, 2), at(3, 4)]);
      expect(range.min, greaterThanOrEqualTo(0));
    });
  });

  group('formatSeriesValue', () {
    test('speed is stored as m/s but read as pace', () {
      // Ordering is by speed so that up means faster; the label is the unit a
      // runner actually reads. 3.33 m/s is 5:00/km.
      expect(formatSeriesValue(1000 / 300, ProgressMetric.speed), '5:00/km');
    });

    test('a long effort has no ceiling', () {
      // The previous code plotted 10000 - seconds, so anything past 2h46m
      // went negative and was clipped off the axis.
      const marathonPace = 42195 / (4 * 3600); // 4 hours
      expect(formatSeriesValue(marathonPace, ProgressMetric.speed), '5:41/km');
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
