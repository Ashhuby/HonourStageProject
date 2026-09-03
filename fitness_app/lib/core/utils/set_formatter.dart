/// Shared formatting for logged sets, personal bests and routine targets.
///
/// The sets list, the "last time" reference chips, the personal best readout
/// and the routine target bar all render the same shapes, so the logic lives
/// here rather than being duplicated per screen.
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

/// A session's date, as `3 Sep 2026  18:45`.
///
/// Shared because the history row and the detail sheet each had their own
/// copy, and they disagreed — one showed the time and the other did not.
String formatSessionDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} ${date.year}  $hour:$minute';
}

/// A session's length, as `2h 15m` or `45m`.
String formatSessionDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
}

/// Progress against a routine's plan for one exercise.
///
/// The target clause follows the exercise's [metricType], because a rep target
/// is meaningless for a run and a distance target is meaningless for a squat.
/// A null distance or duration means the routine says nothing beyond the set
/// count, which is what every routine written before targets existed says.
String formatTargetProgress({
  required int logged,
  required int targetSets,
  required int targetReps,
  required String metricType,
  double? targetDistanceMetres,
  int? targetDurationSeconds,
}) {
  if (logged >= targetSets) {
    return 'TARGET MET \u00b7 $logged OF $targetSets SETS';
  }

  final target = switch (metricType) {
    'distanceTime' =>
      targetDistanceMetres == null
          ? ''
          : ' \u00b7 TARGET ${formatDistance(targetDistanceMetres)}',
    'timeOnly' =>
      targetDurationSeconds == null
          ? ''
          : ' \u00b7 TARGET ${formatDuration(targetDurationSeconds)}',
    _ => ' \u00b7 TARGET $targetReps REPS',
  };
  return 'SET ${logged + 1} OF $targetSets$target';
}

/// The routine's plan for one exercise, as a compact right-aligned label.
///
/// `3 x 10` for a lift, `3 x 5.0km` for a run, `3 x 45s` for a hold — and just
/// `3 sets` when the routine names no target for a non-rep exercise.
String formatTargetSummary({
  required int targetSets,
  required int targetReps,
  required String metricType,
  double? targetDistanceMetres,
  int? targetDurationSeconds,
}) {
  final per = switch (metricType) {
    'distanceTime' =>
      targetDistanceMetres == null
          ? null
          : formatDistance(targetDistanceMetres),
    'timeOnly' =>
      targetDurationSeconds == null
          ? null
          : formatDuration(targetDurationSeconds),
    _ => '$targetReps',
  };
  if (per == null) return '$targetSets sets';
  return '$targetSets \u00d7 $per';
}
