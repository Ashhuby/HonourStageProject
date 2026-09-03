import '../../../../core/database/local_database.dart';
import 'body_part.dart';

/// Filters [all] down to the exercises matching a search box and chip state.
///
/// Pure and synchronous — the library is 41 seeded rows plus a handful of
/// custom ones, so filtering in Dart over the existing `watchExercises` stream
/// is cheaper than a second database query, and keeps this unit-testable.
///
/// When [query] is set, results are ordered so that names *starting* with the
/// query come before names merely containing it: typing "ben" puts
/// "Bench Press" above "Barbell Bent Over Row".
List<Exercise> filterExercises(
  List<Exercise> all, {
  String query = '',
  BodyPart? bodyPart,
  Set<int> excludeIds = const {},
}) {
  final needle = query.trim().toLowerCase();

  final matches = <Exercise>[];
  for (final exercise in all) {
    if (excludeIds.contains(exercise.id)) continue;
    if (bodyPart != null && BodyPart.fromLabel(exercise.bodyPart) != bodyPart) {
      continue;
    }
    if (needle.isNotEmpty && !exercise.name.toLowerCase().contains(needle)) {
      continue;
    }
    matches.add(exercise);
  }

  if (needle.isEmpty) return matches;

  matches.sort((a, b) {
    final aRank = a.name.toLowerCase().startsWith(needle) ? 0 : 1;
    final bRank = b.name.toLowerCase().startsWith(needle) ? 0 : 1;
    if (aRank != bRank) return aRank.compareTo(bRank);
    return a.name.compareTo(b.name);
  });
  return matches;
}

/// A run of exercises sharing one body part, ready to render under a heading.
class ExerciseSection {
  final String title;
  final BodyPart? bodyPart;
  final List<Exercise> exercises;

  const ExerciseSection({
    required this.title,
    required this.bodyPart,
    required this.exercises,
  });
}

/// Groups [exercises] into sections in [BodyPart] declaration order,
/// alphabetically within each, with unrecognised body parts collected last.
List<ExerciseSection> groupExercisesByBodyPart(List<Exercise> exercises) {
  final buckets = <BodyPart, List<Exercise>>{};
  final other = <Exercise>[];

  for (final exercise in exercises) {
    final part = BodyPart.fromLabel(exercise.bodyPart);
    if (part == null) {
      other.add(exercise);
    } else {
      buckets.putIfAbsent(part, () => []).add(exercise);
    }
  }

  final sections = <ExerciseSection>[];
  for (final part in BodyPart.values) {
    final bucket = buckets[part];
    if (bucket == null || bucket.isEmpty) continue;
    bucket.sort((a, b) => a.name.compareTo(b.name));
    sections.add(
      ExerciseSection(title: part.label, bodyPart: part, exercises: bucket),
    );
  }
  if (other.isNotEmpty) {
    other.sort((a, b) => a.name.compareTo(b.name));
    sections.add(
      ExerciseSection(title: 'Other', bodyPart: null, exercises: other),
    );
  }
  return sections;
}

/// Counts exercises per body part, for the body map's "has exercises" shading.
Map<BodyPart, int> countByBodyPart(List<Exercise> exercises) {
  final counts = <BodyPart, int>{};
  for (final exercise in exercises) {
    final part = BodyPart.fromLabel(exercise.bodyPart);
    if (part != null) counts[part] = (counts[part] ?? 0) + 1;
  }
  return counts;
}
