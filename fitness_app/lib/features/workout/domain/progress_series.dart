/// What a chart plots for one exercise, and how to read its axis.
///
/// Volume — weight × reps — is meaningful for exactly one of the four metric
/// types. For the other three it is identically zero: a bodyweight Pull Up
/// records `weight = 0`, a Plank and a run both record `reps = 0`. That
/// rendered as a flat line labelled in kilograms rather than as an empty
/// chart, because zero is a number and an `isEmpty` guard can never fire on a
/// list of zeroes.
///
/// The fix is to choose the series from the metric type rather than assuming
/// volume, which is why this lives in `domain/` as pure functions: the project
/// has no widget tests, so a chart is only testable if its maths is separable
/// from its rendering.
library;

import 'dart:math' as math;

/// A single plotted point — one per session.
class SeriesPoint {
  const SeriesPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// One logged set, reduced to the fields a chart needs.
///
/// Deliberately not `WorkoutSet`: keeping this a plain record means the
/// aggregation below can be tested without a database.
typedef SetSample = ({
  DateTime date,
  double weight,
  int reps,
  int? durationSeconds,
  double? distanceMetres,
});

/// The series an exercise's progress is measured by.
enum ProgressMetric {
  volume('Volume Over Time', 'VOLUME (kg)'),
  reps('Reps Over Time', 'TOTAL REPS'),
  duration('Time Under Tension', 'DURATION'),
  distance('Distance Over Time', 'DISTANCE'),

  /// Metres per second. Speed rather than time so that, like every other
  /// series here, up means better — and so there is no ceiling to overflow.
  speed('Pace Over Time', 'PACE (per km)');

  const ProgressMetric(this.heading, this.axisLabel);

  /// Section heading on the exercise detail screen.
  final String heading;

  /// Left-axis caption.
  final String axisLabel;
}

/// The series the detail screen plots for an exercise of this metric type.
///
/// Distance rather than pace, because distance is cardio's analogue of volume:
/// "how much did I do", which is the question the detail chart answers.
ProgressMetric detailMetricFor(String metricType) => switch (metricType) {
  'bodyweightReps' => ProgressMetric.reps,
  'timeOnly' => ProgressMetric.duration,
  'distanceTime' => ProgressMetric.distance,
  _ => ProgressMetric.volume,
};

/// The series the progress screen's personal-best chart plots.
///
/// Pace rather than distance, because that chart answers "am I improving",
/// and a longer run is not a better one.
ProgressMetric recordMetricFor(String metricType) => switch (metricType) {
  'bodyweightReps' => ProgressMetric.reps,
  'timeOnly' => ProgressMetric.duration,
  'distanceTime' => ProgressMetric.speed,
  _ => ProgressMetric.volume,
};

/// Totals [samples] per session — how much work was done each time.
///
/// Returns an **empty list** rather than a list of zeroes when the metric does
/// not apply to the data, so the caller's `isEmpty` guard is meaningful. That
/// is the whole bug: three of the four metric types produced zeroes here and
/// were drawn as a flat line in kilograms.
List<SeriesPoint> sessionTotals(
  Iterable<SetSample> samples,
  ProgressMetric metric,
) {
  return _collect(samples, metric, best: false);
}

/// The best single effort per session — what a record chart plots.
List<SeriesPoint> sessionBests(
  Iterable<SetSample> samples,
  ProgressMetric metric,
) {
  return _collect(samples, metric, best: true);
}

List<SeriesPoint> _collect(
  Iterable<SetSample> samples,
  ProgressMetric metric, {
  required bool best,
}) {
  // Keyed by calendar day, so several sessions in a day read as one point.
  final byDay = <String, ({DateTime date, double a, double b})>{};

  for (final sample in samples) {
    final day =
        '${sample.date.year}-'
        '${sample.date.month.toString().padLeft(2, '0')}-'
        '${sample.date.day.toString().padLeft(2, '0')}';

    // `a` is the plotted quantity; `b` carries the divisor for speed, which
    // is the one metric that cannot be reduced set by set.
    final double a;
    var b = 0.0;
    switch (metric) {
      case ProgressMetric.volume:
        a = sample.weight * sample.reps;
      case ProgressMetric.reps:
        a = sample.reps.toDouble();
      case ProgressMetric.duration:
        a = (sample.durationSeconds ?? 0).toDouble();
      case ProgressMetric.distance:
        a = sample.distanceMetres ?? 0;
      case ProgressMetric.speed:
        // Sum distance and time across the session, then divide once. Taking
        // the fastest individual set instead would let one 400 m interval
        // stand in for an hour's running.
        a = sample.distanceMetres ?? 0;
        b = (sample.durationSeconds ?? 0).toDouble();
    }

    final existing = byDay[day];
    if (existing == null) {
      byDay[day] = (date: sample.date, a: a, b: b);
    } else if (best && metric != ProgressMetric.speed) {
      byDay[day] = (
        date: existing.date,
        a: math.max(existing.a, a),
        b: existing.b,
      );
    } else {
      byDay[day] = (date: existing.date, a: existing.a + a, b: existing.b + b);
    }
  }

  final points = <SeriesPoint>[];
  for (final entry in byDay.values) {
    final value = metric == ProgressMetric.speed
        ? (entry.b > 0 ? entry.a / entry.b : 0.0)
        : entry.a;
    points.add(SeriesPoint(date: entry.date, value: value));
  }
  points.sort((a, b) => a.date.compareTo(b.date));

  // Every point zero means the metric says nothing about this exercise.
  if (points.every((p) => p.value <= 0)) return const [];
  return points;
}

/// What a record series says at a glance.
///
/// The chart alone answers "has it moved" but not "where am I now" or "is
/// this my best" — questions that need a number, not a shape. Kept here as
/// pure data so the reading is testable and the widget only lays it out.
typedef SeriesSummary = ({
  SeriesPoint first,
  SeriesPoint latest,
  SeriesPoint best,

  /// Where [best] sits in the series, so the chart can single that point out.
  int bestIndex,

  /// How many sessions are plotted.
  int sessions,

  /// The latest effort against the first, as a fraction: 0.18 is eighteen per
  /// cent better. Positive always means improvement — every [ProgressMetric]
  /// is oriented so that up is better, which is why cardio is measured in
  /// speed rather than in time.
  ///
  /// Zero when the first effort was zero, since there is no meaningful
  /// multiple of nothing.
  double changeFraction,
});

/// Reads [points] as a summary, or null when there is nothing to summarise.
///
/// A single point is summarised rather than rejected: one record is still a
/// best, and reporting it beats an empty panel next to a chart with a dot on
/// it.
SeriesSummary? summariseSeries(List<SeriesPoint> points) {
  if (points.isEmpty) return null;

  var bestIndex = 0;
  for (var i = 1; i < points.length; i++) {
    if (points[i].value > points[bestIndex].value) bestIndex = i;
  }

  final first = points.first;
  final latest = points.last;

  return (
    first: first,
    latest: latest,
    best: points[bestIndex],
    bestIndex: bestIndex,
    sessions: points.length,
    changeFraction: first.value <= 0
        ? 0
        : (latest.value - first.value) / first.value,
  );
}

/// The vertical span a series should be drawn across.
///
/// A flat series — every session the same, or a single record — has no span of
/// its own, and handing a chart `minY == maxY` draws a line along an edge or
/// nothing at all. Falls back to a window around the value instead.
({double min, double max}) chartRangeFor(List<SeriesPoint> points) {
  if (points.isEmpty) return (min: 0, max: 1);

  var low = points.first.value;
  var high = points.first.value;
  for (final point in points) {
    if (point.value < low) low = point.value;
    if (point.value > high) high = point.value;
  }

  final span = high - low;
  final padding = span > 0 ? span * 0.15 : math.max(1, high.abs() * 0.1);

  return (min: math.max(0, low - padding), max: high + padding);
}

/// Renders a plotted value for an axis label or tooltip.
///
/// Speed is stored as metres per second so the chart's ordering is honest —
/// higher is faster — but shown as pace, which is the unit the number is read
/// in. The ordering and the rendering are allowed to differ; the previous
/// code instead inverted the *value* around a constant, which capped at
/// 2h46m and went negative beyond it.
String formatSeriesValue(double value, ProgressMetric metric) {
  switch (metric) {
    case ProgressMetric.duration:
      return _clock(value.round());
    case ProgressMetric.distance:
      return value >= 1000
          ? '${(value / 1000).toStringAsFixed(1)}km'
          : '${value.round()}m';
    case ProgressMetric.speed:
      if (value <= 0) return '—';
      return '${_clock((1000 / value).round())}/km';
    case ProgressMetric.volume:
      return '${value.round()}kg';
    case ProgressMetric.reps:
      return '${value.round()}';
  }
}

String _clock(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return minutes > 0
      ? '$minutes:${remainder.toString().padLeft(2, '0')}'
      : '${remainder}s';
}
