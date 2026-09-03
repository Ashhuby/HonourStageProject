import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// How an exercise is filed at the top level.
///
/// This is a base fact about the exercise, not a derivation, which is what
/// justifies storing it: `metricType` cannot tell a Plank from a hamstring
/// stretch — both are `timeOnly` — the primary muscle cannot tell Running from
/// a Squat, and `equipmentType` files Leg Press, Cycling and Rowing Machine
/// all as `Machine`.
///
/// Contrast `Exercises.bodyPart`, which *is* derived (from the primary
/// muscle's group) and is kept only because the remote schema declares it
/// NOT NULL and older clients read nothing else.
enum ExerciseCategory {
  strength('Strength', OneRepColors.strength),
  cardio('Cardio', OneRepColors.cardio),
  mobility('Mobility', OneRepColors.mobility);

  const ExerciseCategory(this.label, this.color);

  final String label;
  final Color color;

  /// Whether this category's second level is a [CardioModality] rather than
  /// the primary muscle's group.
  ///
  /// The single branch the whole two-level browse turns on, so it lives here
  /// rather than being re-derived in every widget that needs it.
  bool get isSectionedByModality => this == ExerciseCategory.cardio;

  /// The muscles of Strength and Mobility are what those categories are
  /// browsed by, so both show the body diagram; Cardio shows modalities.
  bool get showsBodyMap => !isSectionedByModality;

  /// Parses a stored `exercises.category` value.
  ///
  /// Null rather than a throw for a value written by a newer client — the
  /// column carries no CHECK constraint precisely so that a fourth category
  /// cannot break an older install.
  static ExerciseCategory? byNameOrNull(String? name) {
    if (name == null) return null;
    for (final category in values) {
      if (category.name == name) return category;
    }
    return null;
  }

  /// Tolerant of casing and padding, for a label arriving from the wire.
  static ExerciseCategory? fromLabel(String label) {
    final needle = label.trim().toLowerCase();
    for (final category in values) {
      if (category.label.toLowerCase() == needle) return category;
    }
    return null;
  }
}

/// The within-category section for Cardio — the analogue of a muscle group,
/// and the axis `equipmentType` cannot express.
///
/// Cardio is the one category whose second level is not derivable: Strength
/// and Mobility both section by the primary muscle's group, which is already
/// stored in `exercise_muscles`.
enum CardioModality {
  run('Run', ExerciseCategory.cardio),
  cycle('Cycle', ExerciseCategory.cardio),
  row('Row', ExerciseCategory.cardio),
  other('Other', ExerciseCategory.cardio);

  const CardioModality(this.label, this.category);

  final String label;
  final ExerciseCategory category;

  Color get color => category.color;

  /// As [ExerciseCategory.byNameOrNull] — null, never a throw.
  static CardioModality? byNameOrNull(String? name) {
    if (name == null) return null;
    for (final modality in values) {
      if (modality.name == name) return modality;
    }
    return null;
  }

  static CardioModality? fromLabel(String label) {
    final needle = label.trim().toLowerCase();
    for (final modality in values) {
      if (modality.label.toLowerCase() == needle) return modality;
    }
    return null;
  }
}
