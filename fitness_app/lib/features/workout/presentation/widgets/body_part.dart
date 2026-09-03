import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// The muscle groups an exercise can belong to.
///
/// `Exercises.bodyPart` is a free `TEXT` column with no database constraint, so
/// this enum is the single source of truth for the eight values the app seeds
/// and offers in the add-exercise form. Declaration order is display order.
///
/// Parsing is deliberately tolerant — [fromLabel] returns null rather than
/// throwing, so a row carrying an unrecognised string still renders (under an
/// "Other" heading) instead of vanishing from the library.
enum BodyPart {
  chest('Chest', OneRepColors.chest),
  back('Back', OneRepColors.back),
  legs('Legs', OneRepColors.legs),
  shoulders('Shoulders', OneRepColors.shoulders),
  biceps('Biceps', OneRepColors.biceps),
  triceps('Triceps', OneRepColors.triceps),
  core('Core', OneRepColors.core),
  wholeBody('Whole Body', OneRepColors.wholeBody);

  const BodyPart(this.label, this.color);

  /// The string stored in the database and shown in the UI.
  final String label;

  /// Section, chip and body-map tint for this group.
  final Color color;

  /// Parses a database string back to a [BodyPart], or null if unrecognised.
  static BodyPart? fromLabel(String label) {
    final needle = label.trim().toLowerCase();
    for (final part in values) {
      if (part.label.toLowerCase() == needle) return part;
    }
    return null;
  }

  /// Tint for an arbitrary body-part string, falling back for unknown values.
  static Color colorFor(String label) =>
      fromLabel(label)?.color ?? OneRepColors.textSecondary;
}
