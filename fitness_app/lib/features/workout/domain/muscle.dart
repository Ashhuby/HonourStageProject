import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// The two-level muscle taxonomy: seven groups, sixteen muscles.
///
/// This lives in `domain/` rather than beside the widgets because the database
/// seed, the schema migration and the sync service all reference it — it is no
/// longer a presentation concern.
///
/// Two levels exist for a concrete reason. The body diagram is tapped with a
/// thumb mid-workout, so it offers only the seven [MuscleGroup]s as targets;
/// forearms and calves are reachable through the chip row beneath it, never as
/// a fingertip-sized sliver of a drawing.
enum MuscleGroup {
  chest('Chest', OneRepColors.chest),
  back('Back', OneRepColors.back),
  shoulders('Shoulders', OneRepColors.shoulders),
  arms('Arms', OneRepColors.biceps),
  core('Core', OneRepColors.core),
  legs('Legs', OneRepColors.legs),
  fullBody('Full Body', OneRepColors.wholeBody);

  const MuscleGroup(this.label, this.color);

  /// The string stored in `Exercises.bodyPart` and shown in the UI.
  final String label;

  /// Section, chip and body-map tint for this group.
  final Color color;

  /// The muscles filed under this group, in [Muscle] declaration order.
  List<Muscle> get muscles =>
      Muscle.values.where((m) => m.group == this).toList(growable: false);

  /// Parses the denormalised `Exercises.bodyPart` label back to a group.
  ///
  /// Tolerant of casing and padding, and returns null rather than throwing:
  /// the column is free `TEXT` with no constraint, so a row written by another
  /// app version must still render — under "Other" — instead of crashing.
  static MuscleGroup? fromLabel(String label) {
    final needle = label.trim().toLowerCase();
    for (final group in values) {
      if (group.label.toLowerCase() == needle) return group;
    }
    return null;
  }
}

/// A single muscle an exercise can train.
///
/// [name] (the enum identifier, e.g. `frontDelts`) is what
/// `exercise_muscles.muscle` stores — a code identifier, stable under UI copy
/// changes, unlike [label].
enum Muscle {
  chest('Chest', MuscleGroup.chest),
  lats('Lats', MuscleGroup.back),
  traps('Traps', MuscleGroup.back),
  lowerBack('Lower Back', MuscleGroup.back),
  frontDelts('Front Delts', MuscleGroup.shoulders),
  sideDelts('Side Delts', MuscleGroup.shoulders),
  rearDelts('Rear Delts', MuscleGroup.shoulders),
  biceps('Biceps', MuscleGroup.arms),
  triceps('Triceps', MuscleGroup.arms),
  forearms('Forearms', MuscleGroup.arms),
  abs('Abs', MuscleGroup.core),
  obliques('Obliques', MuscleGroup.core),
  quads('Quads', MuscleGroup.legs),
  hamstrings('Hamstrings', MuscleGroup.legs),
  glutes('Glutes', MuscleGroup.legs),
  calves('Calves', MuscleGroup.legs),

  /// Cardio and other whole-body work. The sole member of its own group —
  /// a deliberate wrinkle that keeps an exercise's primary muscle total and
  /// non-nullable, rather than special-casing "no muscle" through every query.
  fullBody('Full Body', MuscleGroup.fullBody);

  const Muscle(this.label, this.group);

  /// Display name.
  final String label;

  /// The group this muscle belongs to. Not stored anywhere — group is
  /// functionally dependent on muscle, so persisting it would be a transitive
  /// dependency and a second place for the two to disagree.
  final MuscleGroup group;

  /// Muscles are tinted by their group, so a filtered list stays visually
  /// anchored to the region tapped on the diagram.
  Color get color => group.color;

  /// Parses a stored `exercise_muscles.muscle` value.
  ///
  /// Null rather than a throw for an unknown name, so a row written by a newer
  /// app version — or synced from one — cannot crash an older client.
  static Muscle? byNameOrNull(String? name) {
    if (name == null) return null;
    for (final muscle in values) {
      if (muscle.name == name) return muscle;
    }
    return null;
  }
}

/// Maps a pre-v9 `bodyPart` string to the muscle it most nearly names.
///
/// Used by the v9 backfill for custom exercises, and by sync downloads of rows
/// written by an app version that predates the taxonomy. Keys are lowercased.
///
/// Spelled out rather than derived from `group.muscles.first` so that
/// reordering [Muscle] cannot silently rewrite a shipped migration.
const Map<String, Muscle> _legacyBodyParts = {
  // The eight labels the pre-v9 dropdown offered.
  'chest': Muscle.chest,
  'back': Muscle.lats,
  'legs': Muscle.quads,
  'shoulders': Muscle.frontDelts,
  'biceps': Muscle.biceps,
  'triceps': Muscle.triceps,
  'core': Muscle.abs,
  'whole body': Muscle.fullBody,
};

/// Resolves a legacy `bodyPart` string to a primary [Muscle].
///
/// Falls back to [Muscle.fullBody] so every exercise ends up with exactly one
/// primary, however odd the string it carried.
Muscle muscleForLegacyBodyPart(String bodyPart) {
  final needle = bodyPart.trim().toLowerCase();

  // An exact legacy label wins.
  final legacy = _legacyBodyParts[needle];
  if (legacy != null) return legacy;

  // Then a muscle label — covers rows already written in the new vocabulary,
  // and the values the old dropdown never offered but a synced row could hold.
  for (final muscle in Muscle.values) {
    if (muscle.label.toLowerCase() == needle) return muscle;
  }

  // Then a group label, resolving to that group's first muscle.
  final group = MuscleGroup.fromLabel(bodyPart);
  if (group != null) return group.muscles.first;

  return Muscle.fullBody;
}
