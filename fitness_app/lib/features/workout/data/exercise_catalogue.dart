import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Color, immutable;
import '../../../core/database/local_database.dart';
import '../../../core/theme/app_colors.dart';
import 'strength_standards_data.dart';
import '../domain/activity.dart';
import '../domain/muscle.dart';

/// An exercise together with the muscles it trains.
///
/// The view model the library, picker and body map read. Composed in Dart from
/// a join rather than stored, so `exercise_muscles` stays the single source of
/// truth and no denormalised copy can drift from it.
@immutable
class ExerciseWithMuscles {
  const ExerciseWithMuscles({
    required this.exercise,
    required this.primary,
    required this.secondary,
  });

  final Exercise exercise;

  /// Null only for a row carrying no muscle data — a download from an older
  /// client between arrival and its next write. Such a row renders under
  /// "Unassigned" rather than disappearing.
  final Muscle? primary;

  /// Never contains [primary]; ordered by [Muscle] declaration order.
  final List<Muscle> secondary;

  int get id => exercise.id;
  String get name => exercise.name;
  MuscleGroup? get primaryGroup => primary?.group;

  /// The category this exercise is filed under.
  ///
  /// Total where [ExerciseCategory.byNameOrNull] is partial: every exercise is
  /// *some* category, and a value written by a newer client must file
  /// somewhere rather than vanish. Strength is the default because it is what
  /// every pre-v10 row was.
  ExerciseCategory get category =>
      ExerciseCategory.byNameOrNull(exercise.category) ??
      ExerciseCategory.strength;

  /// The modality, for cardio only.
  ///
  /// [CardioModality.other] rather than null for an unrecognised value: a
  /// cardio exercise always has a section to sit in, which is what keeps
  /// grouping a partition.
  CardioModality? get modality => category.isSectionedByModality
      ? (CardioModality.byNameOrNull(exercise.modality) ?? CardioModality.other)
      : null;

  /// Tint for the tile stripe, the dot and the section heading.
  Color get color => primary?.color ?? OneRepColors.textSecondary;

  /// The subtitle's muscle half — the primary *muscle*, which says more than
  /// the group it sits in ("Lats • Barbell" beats "Back • Barbell").
  /// Falls back to the stored label so an unclassified row still reads.
  String get muscleLabel => primary?.label ?? exercise.bodyPart;

  /// Whether a strength percentile means anything for this exercise.
  ///
  /// Three conditions, where there used to be one. The name has to appear in
  /// the standards table, but that alone let a custom `timeOnly` exercise
  /// called "Squat" through — and `getBestLiftForExercise` has no metric
  /// filter, so it would have been handed a record with `weight == 0`. The
  /// standards are 1RM tables in kilograms; they only speak about a strength
  /// exercise measured by load.
  bool get hasStrengthPercentile =>
      category == ExerciseCategory.strength &&
      exercise.metricType == 'weightReps' &&
      hasStrengthStandards(exercise.name);

  /// How this exercise matches a filter, or null if it does not.
  ///
  /// [muscle] wins over [group]: the chip row narrows a body-map selection
  /// rather than replacing it.
  MuscleMatch? matchFor({MuscleGroup? group, Muscle? muscle}) {
    if (muscle != null) {
      if (primary == muscle) return MuscleMatch.primary;
      if (secondary.contains(muscle)) return MuscleMatch.secondary;
      return null;
    }
    if (group != null) {
      if (primary?.group == group) return MuscleMatch.primary;
      if (secondary.any((m) => m.group == group)) return MuscleMatch.secondary;
      return null;
    }
    // No filter — everything matches, and ranks equally.
    return MuscleMatch.primary;
  }
}

/// Whether an exercise trains a muscle as its main target or as support.
enum MuscleMatch { primary, secondary }

/// Folds `exercises LEFT JOIN exercise_muscles` rows into one entry per
/// exercise.
///
/// Pure, and so unit-testable without a database. Row order is preserved, so
/// the query's `ORDER BY name` survives the fold.
///
/// Defensive in two places the schema already guards but a hand-written
/// migration or a sync download could still violate: a secondary equal to the
/// primary is dropped, and a second primary loses to the first.
List<ExerciseWithMuscles> foldCatalogueRows(
  Iterable<TypedResult> rows, {
  required $ExercisesTable exercises,
  required $ExerciseMusclesTable muscles,
}) {
  final byId =
      <int, ({Exercise exercise, Muscle? primary, List<Muscle> rest})>{};

  for (final row in rows) {
    final exercise = row.readTable(exercises);
    final entry = byId.putIfAbsent(
      exercise.id,
      () => (exercise: exercise, primary: null, rest: <Muscle>[]),
    );

    // Null for every column when the left join found no muscle rows.
    final link = row.readTableOrNull(muscles);
    if (link == null) continue;

    final muscle = Muscle.byNameOrNull(link.muscle);
    if (muscle == null) continue; // written by a newer vocabulary

    if (link.isPrimary) {
      if (entry.primary == null) {
        byId[exercise.id] = (
          exercise: entry.exercise,
          primary: muscle,
          rest: entry.rest,
        );
      }
    } else {
      entry.rest.add(muscle);
    }
  }

  final catalogue = <ExerciseWithMuscles>[];
  for (final entry in byId.values) {
    final secondary = entry.rest.where((m) => m != entry.primary).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    catalogue.add(
      ExerciseWithMuscles(
        exercise: entry.exercise,
        primary: entry.primary,
        secondary: secondary,
      ),
    );
  }
  return catalogue;
}
