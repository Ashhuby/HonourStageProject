/// Shared formatting for logged sets and personal bests.
///
/// The sets list, the "last time" reference chips and the personal best
/// readout all render the same shapes, so the logic lives here rather than
/// being duplicated per screen.
library;

import '../database/local_database.dart';

/// Formats a number without a trailing `.0` — `80.0` becomes `80`,
/// `82.5` stays `82.5`.
String formatNumber(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

/// Formats a duration in seconds as `1m 05s`, or `45s` when under a minute.
String formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return minutes > 0
      ? '${minutes}m ${remainder.toString().padLeft(2, '0')}s'
      : '${remainder}s';
}

/// Formats a distance in metres as `1.5km` at or above a kilometre,
/// `400m` below it.
String formatDistance(double metres) => metres >= 1000
    ? '${(metres / 1000).toStringAsFixed(1)}km'
    : '${metres.toStringAsFixed(0)}m';

/// Formats set values into a single human-readable summary.
///
/// The shape is inferred from which fields are populated, matching how
/// each metric type records a set:
///   - a duration with a distance -> `400m in 1m 20s`  (distanceTime)
///   - a duration alone           -> `1m 20s`          (timeOnly)
///   - reps with no weight        -> `12 reps`         (bodyweightReps)
///   - weight and reps            -> `80kg × 8 reps`   (weightReps)
String formatSetSummary({
  double weight = 0.0,
  int reps = 0,
  int? durationSeconds,
  double? distanceMetres,
}) {
  if (durationSeconds != null) {
    final time = formatDuration(durationSeconds);
    if (distanceMetres != null && distanceMetres > 0) {
      return '${formatDistance(distanceMetres)} in $time';
    }
    return time;
  }
  if (weight == 0.0) return '$reps reps';
  return '${formatNumber(weight)}kg × $reps reps';
}

/// Formats a logged set for display.
String formatWorkoutSet(WorkoutSet set) => formatSetSummary(
  weight: set.weight,
  reps: set.reps,
  durationSeconds: set.durationSeconds,
  distanceMetres: set.distanceMetres,
);

/// Formats a personal best for display.
String formatPersonalBest(PersonalBest pb) => formatSetSummary(
  weight: pb.weight,
  reps: pb.reps,
  durationSeconds: pb.durationSeconds,
  distanceMetres: pb.distanceMetres,
);
